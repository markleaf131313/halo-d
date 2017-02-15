
module Game.World.World;

import std.bitmanip : bitfields;


import Game.World.Private.Misc;

import Game.World.Effects;
import Game.World.Objects;
import Game.World.WorldBound;
import Game.World.WorldElement;
import Game.World.WorldLine;
import Game.World.FirstPerson; // TODO move FirstPerson out of World

import Game.Cache;
import Game.Core;
import Game.Tags;


struct World
{

enum maxBipedPhysicsIterations = 16;

// TODO make @nogc nothrow
void updateLogicEffects(float deltaTime)
{
    foreach(ref effect ; effects)
    {
        effect.updateEvents(deltaTime);
    }
}

// TODO make @nogc nothrow
void updateLogicParticles(float deltaTime)
{
    foreach(ref particle ; particles)
    {
        particle.updateLogic(deltaTime);
    }
}


@nogc nothrow:


enum CollisionType
{
    none = indexNone,
    water,
    structure,
    object,
}

enum ObjectSearchType
{
    collideable,
    noncollideable,
    all,
}

struct Location
{
    int leaf    = indexNone;
    int cluster = indexNone;
}

struct SurfaceResult
{
@nogc nothrow:

    int index;
    int planeIndex;
    int materialIndex;

    typeof(Tag.Surface.flags) flags;
    typeof(Tag.Surface.breakableSurface) breakableSurface;

    this(int surfaceIndex, Tag.Surface* surface)
    {
        index            = surfaceIndex;
        planeIndex       = surface.plane;
        materialIndex    = surface.material;
        flags            = surface.flags;
        breakableSurface = surface.breakableSurface;
    }
}

struct RenderSurfaceResult
{
@nogc nothrow:

    int lightmapIndex = indexNone;
    int materialIndex = indexNone;
    int surfaceIndex  = indexNone;
    Vec2 coord;

    bool getSurfaceVertices(TagScenarioStructureBsp* sbsp, ref TagBspVertex*[3] result) const
    {
        return sbsp.getSurfaceVertices(lightmapIndex, materialIndex, surfaceIndex, result);
    }

    bool getLightmapVertices(TagScenarioStructureBsp* sbsp, ref TagBspLightmapVertex*[3] result) const
    {
        return sbsp.getLightmapVertices(lightmapIndex, materialIndex, surfaceIndex, result);
    }
}

struct LineResult
{
    struct Model
    {
        GObject* object;
        int regionIndex;
        int nodeIndex;
        int bspIndex;
    }

    CollisionType         collisionType;
    Location              location;
    float                 percent;
    Vec3                  point;
    Plane3                plane;
    TagEnums.MaterialType materialType;
    SurfaceResult         surface;
    Model                 model;
}

struct ObjectLineResult
{
    float percent;

    SurfaceResult surface;
    Plane3        surfacePlane;

    TagEnums.MaterialType materialType;

    int regionIndex;
    int nodeIndex;
    int bspIndex;
}

struct SurfaceOptions
{
    mixin(bitfields!(
        bool, "frontFacing",     1,
        bool, "backFacing",      1,
        bool, "ignoreInvisible", 1,
        bool, "ignoreTwoSided",  1,
        bool, "ignoreBreakable", 1,
        uint, "", 3,
    ));
}

struct LineOptions
{
    SurfaceOptions surface;
    mixin(bitfields!(
        bool, "objects",                 1,
        bool, "structure",               1,
        bool, "water",                   1,
        bool, "tryToKeepValidLocation",  1,
        bool, "skipPassthroughBipeds",   1,
        bool, "useVehiclePhysics",       1,
        uint, "", 2,
    ));

    GObjectTypeMask objectTypes;
}

struct PointPhysicsOptions
{
    Vec3 position;
    Vec3 velocity;
    Location location;
    float radius;
}

struct PointPhysicsResult
{
    mixin(bitfields!(
        bool, "hitStructureOrObject", 1,
        bool, "hitWater",             1,
        bool, "inAir",                1,
        bool, "inWater",              1,
        ubyte, "",                    4,
    ));

    Vec3 position;
    Vec3 velocity;
    Location location;
    Plane3 plane;
}

struct MassPointResult
{
    TagScenarioStructureBsp* sbsp;
    SurfaceResult surface;
    float distance;
    Plane3 plane;
}

struct EffectMarker
{
    const(char)[] name;
    Vec3 position;
    Vec3 direction;
}

void initialize()
{
    effects  .allocate(512,  multichar!"ef");
    particles.allocate(2048, multichar!"pl");

}

@property ref auto objects()
{
    return objectList;
}

void setCurrentSbsp()
{
    // todo temporary fix, remove this
    TagScenario* scenario = Cache.inst.scenario();
    currentSbsp = Cache.get!TagScenarioStructureBsp(scenario.structureBsps[0].structureBsp);
}

TagScenarioStructureBsp* getCurrentSbsp()
{
    return currentSbsp;
}

int getTickCounter()
{
    return tickCounter;
}

void dealAreaDamage(ref GObject.DamageOptions options)
{
    const tagDamageEffect = Cache.get!TagDamageEffect(options.tagIndex);

    Sphere sphere = {options.center, tagDamageEffect.radius.upper};

    GObject*[64] objects = void;
    int count = calculateNearbyObjects(ObjectSearchType.all, GObjectTypeMask(),
        options.location, sphere, objects.ptr, objects.length);

    foreach(ref object ; objects[0 .. count])
    {
        object.dealAreaDamage(options);
    }

    // TODO damage aoe breakable surfaces
}

GObject* createObject(ref GObject.Creation data)
{
    auto tagObject = Cache.get!TagObject(data.tagIndex);
    auto overseer  = OverseerGObjectPtr.make(GObject.byTypeInit(tagObject.objectType));
    auto iter      = objectList.insertFront(overseer);

    GObject* object = iter.value.ptr;

    if(object)
    {
        object.selfPtr = iter.value.makeSheep();

        object.type = tagObject.objectType; // required to be set to make the PreInitialize call below
                                            // TODO(REFACTOR) would be better to pass this as a parameter instead
                                            //                a lot of work for something only used once though

        if(object.byTypePreInitialize(&data))
        {
            object.headerFlags.newlyCreated = true;
            object.headerFlags.automaticDeactivation = true;

            object.world = &this;

            object.tagIndex = data.tagIndex;
            object.setVisible(tagObject.model.isValid());

            object.computeId.setPrevious(masterComputeId);

            object.position = data.position;
            object.velocity = data.velocity;

            object.rotation.forward   = data.forward;
            object.rotation.up        = data.up;
            object.rotationalVelocity = data.rotationalVelocity;

            object.regionPermutation = data.regionPermutation;
            object.playerIndex       = data.playerIndex;
            object.associatedTeam    = data.team;

            object.shaderPermutation       = tagObject.forcedShaderPermuationIndex;
            object.flags.doesNotCastShadow = tagObject.flags.doesNotCastShadow;
            object.flags.hasCollisionModel = tagObject.collisionModel.isValid();

            if(object.byTypeInitialize())
            {
                object.initializeRegions();
                object.initializeVitality();
                object.updateMatrices();
                object.connectToWorld();
                object.byTypeUpdateMatrices();
                object.byTypeUpdateImportFunctions();
                object.updateExportFunctions();
                object.createAttachments();

                return object;
            }
        }
    }

    objectList.removeFront();

    return null;
}

void createEffectAttachedToObject(DatumIndex tagEffectIndex, GObject* object, int a, int b, int c)
{

    // TODO(IMPLEMENT) allocation for "required for gameplay" effects, free unrequired if no room

    const tagEffect = Cache.get!TagEffect(tagEffectIndex);
    DatumIndex index = effects.add();

    if(index == DatumIndex.none)
    {
        return;
    }

    Effect* effect = &effects[index];

    effect.world = &this;
    effect.selfIndex = index;

    effect.tagIndex = tagEffectIndex;
    effect.object = object.selfPtr;

    effect.flags._bit1_x02 = true; // TODO, rename, causes effect to persist once completed, object destroys?

    effect.setEventIndex(0);

    effect.primaryScaleIndex   = a;
    effect.secondaryScaleIndex = b;
    effect.changeColorIndex    = c;

    if(effect.changeColorIndex == indexNone)
    {
        effect.color = ColorRgb(1, 1, 1); // TODO make enum variable "white"
    }

    // effect.localPlayerIndex = // TODO(IMPLEMENT) get first person from object

    effect.createLocations(&object.findMarkerTransform);

    // TODO(IMPLEMENT, FIRSTPERSON) create first person nodes

    effect.updateEvents(0.0f);
}

void createEffectFromItem(DatumIndex tagEffectIndex, GObject* object, float scaleA, float scaleB)
{
    const tagEffect = Cache.get!TagEffect(tagEffectIndex);
    DatumIndex index = effects.add();

    if(index == DatumIndex.none)
    {
        return;
    }

    Effect* effect = &effects[index];

    effect.world = &this;
    effect.selfIndex = index;

    effect.tagIndex = tagEffectIndex;
    effect.object = object.selfPtr;

    effect.scaleA = scaleA;
    effect.scaleB = scaleB;

    effect.color = ColorRgb(1, 1, 1); // TODO rename to white, also pass in as argument

    effect.setEventIndex(0);

    // effect.localPlayerIndex = // TODO(IMPLEMENT) get first person from object
    // TODO(IMPLEMENT) nonviolent flag

    effect.createLocations(&object.findMarkerTransform);

    // TODO(IMPLEMENT) first person node locations

    // TODO(IMPLEMENT) set local player index, passed as argument

    effect.updateEvents(0.0f);
}

void createEffectFromMarkers(
    DatumIndex           tagEffectIndex,
    const EffectMarker[] markers,
    Vec3                 velocity,
    float                scaleA,
    float                scaleB)
{
    const tagEffect = Cache.get!TagEffect(tagEffectIndex);
    DatumIndex index = effects.add();

    if(index == DatumIndex.none)
    {
        return;
    }

    Effect* effect = &effects[index];

    effect.world = &this;
    effect.selfIndex = index;

    effect.location = findLocation(markers[0].position);

    effect.tagIndex = tagEffectIndex;
    effect.velocity = velocity;
    effect.scaleA   = scaleA;
    effect.scaleB   = scaleB;

    effect.color = ColorRgb(1, 1, 1);

    effect.createLocations((const(char)[] name, int max, GObject.MarkerTransform* transforms) @nogc nothrow
    {
        assert(markers.length > 0 && max > 0);

        static Transform createTransform(Vec3 position, Vec3 forward)
        {
            Transform result = void;

            Vec3 up = anyPerpendicularTo(forward);
            normalize(up);

            result.scale    = 1.0f;
            result.mat3     = Mat3.fromPerpUnitVectors(forward, up);
            result.position = position;

            return result;
        }

        int count = 0;

        if(name.length > 0)
        {
            foreach(ref marker ; markers)
            {
                if(count >= max)
                {
                    break;
                }

                if(iequals(marker.name, name))
                {
                    GObject.MarkerTransform* transform = transforms + count;

                    transform.node  = indexNone;
                    transform.local = createTransform(marker.position, marker.direction);

                    count += 1;
                }
            }
        }

        if(count == 0)
        {
            GObject.MarkerTransform*  transform = transforms;
            const World.EffectMarker* marker    = &markers[0];

            transform.node  = indexNone;
            transform.local = createTransform(marker.position, marker.direction);

            count += 1;
        }

        return count;
    });

    effect.updateEvents(0.0f);

}

void createParticle(ref Particle.Creation data)
{
    if(data.tagIndex == DatumIndex.none)
    {
        return;
    }

    Vec3 position;

    if(data.object is null)
    {
        position = data.offset;
    }
    else if(data.isNodeFirstPerson)
    {
        position = FirstPerson.inst(data.localPlayerIndex).transforms[data.nodeIndex] * data.offset;
    }
    else
    {
        position = data.object.transforms[data.nodeIndex] * data.offset;
    }

    Location location = findLocation(position);

    if(location.leaf == indexNone)
    {
        return;
    }

    // TODO(IMPLEMENT) check if cluster is active, dont create if isn't

    DatumIndex particleIndex = particles.add();

    if(particleIndex == DatumIndex.none)
    {
        return;
    }

    const tagParticle = Cache.get!TagParticle(data.tagIndex);
    Particle* particle = &particles[particleIndex];

    particle.world     = &this;
    particle.selfIndex = particleIndex;

    if(tagParticle.flags.canAnimateBackwards)       particle.flags.animateBackwards   = randomValue() & 1;
    if(tagParticle.flags.randomHorizontalMirroring) particle.flags.mirrorHorizontally = randomValue() & 1;
    if(tagParticle.flags.randomVerticalMirroring)   particle.flags.mirrorVertically   = randomValue() & 1;

    particle.flags.isThirdPerson     = data.isThirdPersonOnly;
    particle.flags.isFirstPerson     = data.isFirstPersonOnly;
    particle.flags.isNodeFirstPerson = data.isNodeFirstPerson;

    particle.tagIndex = data.tagIndex;
    particle.localPlayerIndex = data.localPlayerIndex;

    particle.life     = 0.0f;
    particle.lifespan = randomValue(tagParticle.lifespan);

    particle.animationTime = 0.0f;

    if(tagParticle.animationRate.upper == 0.0f) particle.animationRate = float.max;
    else                                        particle.animationRate = randomValue(tagParticle.animationRate);

    particle.location = location;

    particle.position  = data.offset;
    particle.direction = data.direction;
    particle.velocity  = data.velocity;
    particle.angle     = data.angle;

    particle.angularVelocity = data.angularVelocity;

    particle.radius = data.radius;
    particle.tint   = data.tint;

    if(!tagParticle.flags.selfIlluminated || tagParticle.flags.tintFromDiffuseTexture)
    {
        // TODO(IMPLEMENT) grab color from sbsp

        if(!tagParticle.flags.selfIlluminated)
        {
            // TODO(IMPLEMENT) color of particle
        }

        if(tagParticle.flags.tintFromDiffuseTexture)
        {
            // TODO(IMPLEMENT) color of particle
        }
    }

    if(particle.advanceSequence())
    {
        const tagBitmap = Cache.get!TagBitmap(tagParticle.bitmap);

        if(tagParticle.flags.animationStartsOnRandomFrame)
        {
            particle.spriteIndex = randomValueFromZero(tagBitmap.sequences[particle.sequenceIndex].sprites.size);

            if(particle.flags.animateBackwards) particle.spriteIndex += 1;
            else                                particle.spriteIndex -= 1;
        }
        else if(particle.flags.animateBackwards)
        {
            particle.spriteIndex = tagBitmap.sequences[particle.sequenceIndex].sprites.size;
        }
        else
        {
            particle.spriteIndex = -1;
        }
    }

}

auto addObjectToCollideableCluster(int clusterIndex, GObject* object)
{
    auto list = &collideableClusterObjectLists[clusterIndex];
    return list.insert(object);
}

auto addObjectToNoncollideableCluster(int clusterIndex, GObject* object)
{
    auto list = &noncollideableClusterObjectLists[clusterIndex];
    return list.insertFront(object);
}

void removeObjectFromCollideableCluster(int clusterIndex, typeof(GObject.ClusterNode.iterator) range)
{
    collideableClusterObjectLists[clusterIndex].remove(range);
}

void removeObjectFromNoncollideableCluster(int clusterIndex, typeof(GObject.ClusterNode.iterator) range)
{
    noncollideableClusterObjectLists[clusterIndex].remove(range);
}

int calculateNearbyObjects(
    ObjectSearchType  search,
    GObjectTypeMask   mask,
    Location          location,
    ref const(Sphere) sphere,
    GObject**         iterator,
    int               max)
{
    if(location.cluster == indexNone)
    {
        return 0;
    }

    int count;
    int[TagConstants.StructureBsp.maxClusters] clusters = void;

    if(sphere.radius > 0.0f)
    {
        count = calculateOccupiedClusters(location.cluster, sphere, clusters.ptr, clusters.length);
    }
    else
    {
        count       = 1;
        clusters[0] = location.cluster;
    }

    if(!mask.anySet())
    {
        mask.setAll();
    }

    masterComputeId.advance();
    int total = 0;

    foreach(int clusterIndex ; clusters[0 .. count])
    {
        if(max == 0)
        {
            return 0;
        }

        if(search == ObjectSearchType.collideable || search == ObjectSearchType.all)
        {
            foreach(object ; collideableClusterObjectLists[clusterIndex])
            {
                if(object.computeId.assignEqual(masterComputeId)) continue;
                if(!mask.isSet(object.type))                      continue;
                if(!sphere.intersects(object.bound))              continue;

                *iterator = object;

                iterator += 1;
                total    += 1;
                max      -= 1;

                if(max == 0)
                {
                    return total;
                }
            }
        }

        if(search == ObjectSearchType.noncollideable || search == ObjectSearchType.all)
        {
            foreach(object ; noncollideableClusterObjectLists[clusterIndex])
            {
                if(object.computeId.assignEqual(masterComputeId)) continue;
                if(!mask.isSet(object.type))                      continue;
                if(!sphere.intersects(object.bound))              continue;

                *iterator = object;

                iterator += 1;
                total    += 1;
                max      -= 1;

                if(max == 0)
                {
                    return total;
                }
            }
        }
    }

    return total;
}

int calculateOccupiedClusters(int clusterIndex, ref const(Sphere) sphere, int* iterator, int max)
{
    if(clusterIndex == indexNone)
    {
        return 0;
    }

    masterComputeId.advance();

    return calculateClusterRecurse(clusterIndex, sphere, iterator, max);
}

Location findLocation(ref const(Vec3) position)
{
    return currentSbsp.findLocation(position);
}

int findLeaf(ref const(Vec3) position)
{
    return currentSbsp.collisionBsp.findLeaf(position);
}

bool collideLine(GObject* object, Vec3 position, Vec3 segment, LineOptions options, ref LineResult result)
{
    if(!options.structure && !options.objects && !options.water)
    {
        result.collisionType = CollisionType.none;
        result.percent  = 1.0f;
        result.point    = position + segment;
        result.location = findLocation(result.point);

        return false;
    }

    if(!options.surface.backFacing && !options.surface.frontFacing)
    {
        options.surface.frontFacing = true;
        options.surface.backFacing  = true;
    }

    WorldLine line = WorldLine(options.surface, true, position, segment, currentSbsp.collisionBsp, 1.0f);
    bool collision = false;

    LineResult bestResult = void; // TODO refactor out this

    bestResult.collisionType = CollisionType.none;
    bestResult.percent = 1.0f;
    bestResult.point   = position + segment;

    if(line && options.structure)
    {
        collision = true;

        bestResult.collisionType = CollisionType.structure;
        bestResult.percent = line.percent;
        bestResult.point   = position + line.percent * segment;
        bestResult.surface = line.surface;
        bestResult.plane   = currentSbsp.collisionBsp.planes[line.surface.planeIndex & int.max].plane;

        bestResult.location = Location.init;

        if(line.surface.materialIndex == indexNone)
        {
            bestResult.materialType = TagEnums.MaterialType.invalid;
        }
        else
        {
            bestResult.materialType = currentSbsp.collisionMaterials[line.surface.materialIndex].materialType;
        }
    }

    if(!line.leaves.isEmpty)
    {
        int leaf = line.leaves[$ - 1];

        if(leaf != indexNone)
        {
            bestResult.location.leaf = leaf;
            bestResult.location.cluster = currentSbsp.leaves[leaf].cluster;
        }
    }

    if(options.water)
    {
        // todo implement this, requires above location though
    }

    if(options.objects)
    {
        if(!options.objectTypes.anySet())
        {
            options.objectTypes.setAll();
        }

        masterComputeId.advance();

        foreach(int id ; line.leaves)
        {
            int clusterId = currentSbsp.leaves[id].cluster;

            if(clusterComputeIds[clusterId].assignEqual(masterComputeId))
            {
                continue;
            }

            foreach(GObject* o ; collideableClusterObjectLists[clusterId])
            {
                if(o.computeId.assignEqual(masterComputeId))
                {
                    continue;
                }

                if(calculateObjectLineCollisionRecurse(object, position, segment, o, options, bestResult))
                {
                    collision = true;
                }
            }
        }
    }

    if(collision && options.tryToKeepValidLocation)
    {
        if(result.location.leaf != indexNone && findLeaf(result.point) != result.location.leaf)
        {
            assert(0); // TODO
        }
    }

    if(collision)
    {
        result = bestResult;
    }
    else
    {
        result = LineResult();

        result.collisionType = CollisionType.none;
        result.percent       = 1.0f;
        result.point         = position + segment;
        result.location      = bestResult.location;
    }

    return collision;
}

bool collideRenderLine(Vec3 position, Vec3 segment, ref RenderSurfaceResult result)
{
    LineResult  lineResult = void;
    LineOptions options;

    options.surface.frontFacing = true;
    options.structure           = true;

    if(collideLine(null, position, segment, options, lineResult))
    {
        int leaf  = lineResult.location.leaf;
        int plane = lineResult.surface.planeIndex & int.max;

        if(calculateRenderSurface(currentSbsp, position + segment * lineResult.percent, leaf, plane, result))
        {
            if(currentSbsp.lightmaps[result.lightmapIndex].bitmap != indexNone)
            {
                return true;
            }
        }
    }

    // todo loop to avoid transparent double sided surfaces ?

    return false;
}

void collidePointPhysics(
    const TagPointPhysics* tagPointPhysics,
    Vec3                   position,
    Vec3                   velocity,
    float                  radius,
    float                  deltaTime,
    ref PointPhysicsResult result)
{
    if(deltaTime == 0.0f)
    {
        return;
    }

    float radius2 = radius * radius;
    float radius3 = radius * radius2;

    // TODO(IMPLEMENT, WIND) weather/wind stuff here
    //                       result.inWater / result.inAir as well

    result.inAir = true; // TODO(REFACTOR, WORKAROUND) temporary workaround, remove and replace

    if(!tagPointPhysics.flags.noGravity)
    {
        float gravityScale = tagPointPhysics.gravityScaleInAir; // TODO(IMPLEMENT, WATER) add "gravityScaleInWater"

        velocity.z += gravityScale * (gameGravity * sqr(gameFramesPerSecond)) * deltaTime;
    }

    // TODO(IMPLEMENT) velocity it scaled here by wind

    LineOptions lineOptions;

    lineOptions.surface.frontFacing = true;
    lineOptions.structure = tagPointPhysics.flags.collidesWithStructures;
    lineOptions.water     = tagPointPhysics.flags.collidesWithWaterSurface;

    if(tagPointPhysics.flags.flamethrowerParticleCollision)
    {
        lineOptions.objects = true;
        lineOptions.objectTypes.set(TagEnums.ObjectType.scenery, TagEnums.ObjectType.vehicle);
    }

    Location location;

    for(int i = 0; i < 3 && deltaTime > 0.0f; ++i)
    {
        LineResult line = void;

        if(!collideLine(null, position, deltaTime * velocity, lineOptions, line))
        {
            if(line.location.leaf != indexNone)
            {
                location = line.location;
            }

            position = line.point;

            break;
        }

        if(line.collisionType == CollisionType.water)
        {
            result.hitWater = true;
        }
        else if(line.collisionType == CollisionType.structure || line.collisionType == CollisionType.object)
        {
            result.hitStructureOrObject = true;
        }

        result.plane = line.plane;

        Vec3 deducted = dot(line.plane.normal, velocity) * line.plane.normal;
        velocity = (velocity - deducted) * (1.0f - tagPointPhysics.surfaceFriction) - deducted * tagPointPhysics.elasticity;

        if(line.location.leaf != indexNone)
        {
            location = line.location;
        }

        position = line.point + line.plane.normal * max(0.005f, radius);

    }

    result.location = location;
    result.position = position;
    result.velocity = velocity;

}

bool collideMassPoint(GObject* object, Vec3 position, float radius, GObjectTypeMask mask, ref MassPointResult result)
{
    Element element;
    VerticalCapsule capsule;

    capsule.bottomCenter = position;
    capsule.radius       = radius;
    capsule.height       = 0.0f;

    calculateCapsuleElement(object, position, radius, mask, capsule, element);

    bool hit;
    MassPointResult best = void;

    foreach(ref sphere ; element.spheres)
    {
        // TODO(medium, collision) generic vertices/spheres collision
    }

    foreach(ref cylinder ; element.cylinders)
    {
        Vec3  v = position - cylinder.position;
        float d = dot(v, cylinder.segment);

        if(d < 0.0f)
        {
            continue; // behind cylinder
        }

        float segmentLengthSqr = lengthSqr(cylinder.segment);

        if(d > segmentLengthSqr)
        {
            continue; // ahead of cylinder
        }

        if(sqr(radius) * segmentLengthSqr <= lengthSqr(v) * segmentLengthSqr - sqr(d))
        {
            continue; // too far away
        }

        Vec3 normal = void;

        if(segmentLengthSqr > 0.0f)
        {
            normal = v - (d / segmentLengthSqr) * cylinder.segment;
        }
        else
        {
            normal = v;
        }

        float distance = normalize(normal);

        if(distance == 0.0f)
        {
            normal = Vec3(0, 0, 1);
        }

        Plane3 plane = { normal, dot(normal, cylinder.position) + cylinder.radius };
        distance = radius - distance;

        if(!hit || distance > best.distance)
        {
            hit = true;

            best.distance = distance;
            best.plane    = plane;
            best.surface  = cylinder.surface;
        }

    }

    foreach(ref extruded ; element.extrusions)
    {
        Plane3* plane = &extruded.plane;
        float distance = plane.distanceToPoint(position);

        if(distance < 0.0f)   continue;
        if(distance > radius) continue;

        Vec3 intersect = position + -distance * plane.normal;
        distance = radius - distance;

        if(extruded.pointInSurface(intersect))
        {
            if(!hit || distance > best.distance)
            {
                hit = true;

                best.distance = distance;
                best.plane    = *plane;

                best.plane.d += radius;

                best.surface = extruded.surface;
            }
        }
    }

    result      = best;
    result.sbsp = currentSbsp;

    return hit;
}

bool collidePlayer(
    GObject*                            object,
    ref Vec3                            position,
    float                               radius,
    float                               height,
    ref Vec3                            velocity,
    ref Vec3[maxBipedPhysicsIterations] collisions,
    ref int                             responses)
{
    Element element;
    VerticalCapsule capsule =
    {
        bottomCenter: position + Vec3(0, 0, radius),
        height:       height - radius * 2.0f,
        radius:       radius
    };


    {
        float halfHeight = capsule.height * 0.5f;

        Vec3  center = capsule.bottomCenter + Vec3(0, 0, halfHeight) + velocity * 0.5f;
        float r      = radius               + halfHeight             + length(velocity) * 0.5f;

        GObjectTypeMask mask;
        mask.setAll();

        calculateCapsuleElement(object, center, r, mask, capsule, element);
    }

    responses = 0;

    Vec3 center = position + Vec3(0, 0, radius);
    Vec3 outVelocity       = velocity;
    Vec3 remainingVelocity = velocity;

    Plane3[maxBipedPhysicsIterations] planes;

    foreach(i ; 0 .. maxBipedPhysicsIterations)
    {
        if(abs(velocity.x) < 0.0001f && abs(velocity.y) < 0.0001f && abs(velocity.z) < 0.0001f)
        {
            break;
        }

        float t = 1.0f;
        bool hasCollision = false;
        Plane3 curPlane;

        foreach(ref sphere ; element.spheres)
        {
            // TODO(medium, collision) implement vertex-sphere collision here
        }

        foreach(ref cylinder ; element.cylinders)
        {
            Vec3  v0 = cylinder.position;
            Vec3  d  = cylinder.segment;
            float r  = cylinder.radius;

            float dd = lengthSqr(d);
            float vv = lengthSqr(velocity);
            float vd = dot(velocity, d);

            float e = dd * vv - (vd * vd);

            if(e < 0.0f)
            {
                continue;
            }

            Vec3  posV0  = center - v0;
            float dPosV0 = dot(d, posV0);

            float g = dot(velocity, posV0) * dd;
            float f = dPosV0 * vd - g;

            float ss = f * f - ((lengthSqr(posV0) - sqr(r)) * dd - sqr(dPosV0)) * e;

            if(ss < 0.0f)
            {
                continue;
            }

            ss = sqrt(ss);

            float m = (f - ss) * (1.0f / e);
            float n = (f + ss) * (1.0f / e);

            if(m > 1.0f) continue;
            if(n < 0.0f) continue;

            if(m < 0.0f) m = 0.0f;
            if(n > 1.0f) n = 1.0f;

            if(vd <= 0.0f)
            {
                if(dPosV0 < 0.0f) continue;
                if(dPosV0 > dd)   continue;
            }
            else
            {
                float h = -dPosV0 / vd;
                float j = (dd - dPosV0) / vd;

                float ju;

                if(vd < 0.0f)
                {
                    if(j > m) m = j;

                    if(h < 1.0f) ju = h;
                    else         ju = 1.0f;
                }
                else
                {
                    if(h > m) m = h;

                    if(j < 1.0f) ju = j;
                    else         ju = 1.0f;
                }

                if(m > ju) continue;
            }

            Vec3 hit    = posV0 + velocity * m;
            Vec3 normal = hit + d * -(dot(hit, d) / dd);

            if(normalize(normal) == 0.0f) normal = Vec3(1, 0, 0);
            if(dot(normal, velocity) >= -0.0001f) continue;

            if(m < t)
            {
                t = m;
                curPlane.normal = normal;
                curPlane.d      = dot(center, normal);
                hasCollision    = true;
            }
        }

        foreach(ref extruded ; element.extrusions)
        {
            Plane3* plane = &extruded.plane;

            // todo do we need depth here?
            float depth = extruded.depth; // todo rename radius

            float d = plane.distanceToPoint(center);
            float v = dot(plane.normal, velocity);

            float percent = 0.0f;
            float end     = 1.0f;

            if(v < 0.0f)
            {
                float p = -(d / v);
                float g = -((d - depth) / v);

                if(g > 0.0f) percent = g;
                if(p < 1.0f) end = p;

                if(end < percent) continue;
            }
            else if(d < 0.0f || d > depth)
            {
                continue;
            }

            float p = -((d - depth) / v);

            if(v >= -0.0001f) continue;
            if(p < 0.0f) p = 0.0f;

            if(p <= t)
            {
                Vec3 x = center + p * velocity;
                float distance = plane.distanceToPoint(x);

                x -= distance * plane.normal;

                Vec2 intersect = extruded.proj.project(x);

                if(extruded.pointInSurface(intersect))
                {
                    t = p;
                    curPlane.normal = plane.normal;
                    curPlane.d      = plane.d + depth;
                    hasCollision    = true;
                }
            }
        }

        center += velocity * t;

        if(!hasCollision)
        {
            break;
        }

        responses += 1;

        Vec3 originalCenter = center;

        center += -curPlane.distanceToPoint(center) * curPlane.normal;

        collisions[i] = curPlane.normal;
        planes[i] = curPlane;

        remainingVelocity *= 1.0f - t;
        velocity = remainingVelocity - dot(remainingVelocity, curPlane.normal) * curPlane.normal;

        outVelocity -= dot(outVelocity, curPlane.normal) * curPlane.normal;

        static bool magic(ref const(Plane3) a, ref const(Plane3) b, ref Vec3 outCross, ref Vec3 result)
        {
            outCross = cross(a.normal, b.normal);
            float lenSqr = lengthSqr(outCross);

            if(lenSqr < 0.0001f)
            {
                return false;
            }

            result = (cross(b.normal, outCross) * a.d + cross(outCross, a.normal) * b.d) / lenSqr;

            return true;
        }

        if(i > 0)
        {
            int lastIndex = i - 1;

            if(dot(collisions[lastIndex], velocity) < 0.0001f)
            {
                Vec3 perpendicular, b;

                if(magic(planes[lastIndex], planes[i], perpendicular, b))
                {
                    velocity = perpendicular * dot(remainingVelocity, perpendicular) / lengthSqr(perpendicular);

                    // subroutine //

                    float v = dot(perpendicular, originalCenter - b) / lengthSqr(perpendicular);
                    center = perpendicular * v + b;

                    // end //

                    if(i > 1)
                    {
                        // todo implement more iterations
                    }

                    continue;
                }
            }
            else
            {
                // todo implement this case
            }

            if(i > 1)
            {
                // todo implement this case
            }
        }
    }

    velocity = outVelocity;
    position = center - Vec3(0, 0, radius);

    return false;
}

bool isClusterActive(int clusterIndex)
{
    return true; // todo implement a bit array for activation
                 // there are two separate bit array for cluster activation, one serves a different purpose?
}

private:

alias Bound   = WorldBound;
alias Element = WorldElement;
alias Line    = WorldLine;

int tickCounter; // TODO(IMPLEMENT)
TagScenarioStructureBsp* currentSbsp;

MasterComputeIdentifier masterComputeId;
SlaveComputeIdentifier[TagConstants.StructureBsp.maxClusters] clusterComputeIds;

DList!OverseerGObjectPtr objectList;
DList!(GObject*)[TagConstants.StructureBsp.maxClusters] collideableClusterObjectLists;
DList!(GObject*)[TagConstants.StructureBsp.maxClusters] noncollideableClusterObjectLists;

public DatumArray!Effect   effects;
public DatumArray!Particle particles;

static
bool calculateObjectLineCollisionRecurse(
    GObject*       ignoreObject,
    Vec3           position,
    Vec3           segment,
    GObject*       object,
    LineOptions    options,
    ref LineResult result)
{
    bool collision = false;

    for(GObject* o = object; o !is null; o = o.nextSiblingObject)
    {
        if(o == ignoreObject)                  continue;
        if(!options.objectTypes.isSet(o.type)) continue;
        if(!o.bound.intersectsLine(position, segment)) continue;

        if(options.useVehiclePhysics && o.type == TagEnums.ObjectType.vehicle)
        {
            assert(0, "implement vehicle-physics-line collision");
        }
        else
        {
            ObjectLineResult objectResult = void;

            if(o.collideObjectLine(position, segment, options.surface, objectResult)
                && objectResult.percent < result.percent)
            {
                result.collisionType = CollisionType.object;
                result.percent       = objectResult.percent;
                result.materialType  = objectResult.materialType;
                result.surface       = objectResult.surface;

                result.model.object      = o;
                result.model.bspIndex    = objectResult.bspIndex;
                result.model.nodeIndex   = objectResult.nodeIndex;
                result.model.regionIndex = objectResult.regionIndex;

                result.plane = o.transforms[objectResult.nodeIndex] * objectResult.surfacePlane;

                if(objectResult.surface.planeIndex < 0)
                {
                    result.plane = -result.plane;
                }

                collision = true;
            }
        }

        if(o.firstChildObject)
        {
            if(calculateObjectLineCollisionRecurse(ignoreObject, position, segment, o.firstChildObject, options, result))
            {
                collision = true;
            }
        }
    }

    return collision;
}

void calculateCapsuleElement(
    GObject*                   object,
    Vec3                       position,
    float                      radius,
    GObjectTypeMask            mask,
    ref const(VerticalCapsule) capsule,
    ref Element                element)
{
    Sphere sphere = { position, radius + 0.0625f };
    Bound bound = Bound(currentSbsp.collisionBsp, sphere);

    Tag.Bsp* bsp = currentSbsp.collisionBsp;

    element.addTransformElements(bsp, bound.result, capsule, null);

    masterComputeId.advance();

    foreach(i, leaf ; bound.result.leaves)
    {
        int clusterIndex = currentSbsp.leaves[leaf].cluster;

        if(clusterComputeIds[clusterIndex].assignEqual(masterComputeId))
        {
            continue;
        }

        foreach(ref o ; collideableClusterObjectLists[clusterIndex])
        {
            if(o.computeId.assignEqual(masterComputeId)) continue;
            if(o == object)                              continue;

            auto tagObject = Cache.get!TagObject(o.tagIndex);

            if(!tagObject.collisionModel)   continue;
            if(!mask.isSet(o.type))         continue;
            if(!sphere.intersects(o.bound)) continue;

            auto tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);

            foreach(j, ref node ; tagCollision.nodes)
            {
                if(node.region == indexNone) continue;
                if(node.bsps.size == 0)      continue;

                int bspIndex = clamp(o.regionPermutationIndices[node.region], 0, node.bsps.size - 1);

                Tag.Bsp* nodeBsp = node.bsps.ptr + bspIndex;
                Vec3 p = inverse(o.transforms[j]) * sphere.center; // todo scaling ?

                Sphere nodeSphere = { p, sphere.radius }; // todo scaling radius ?
                Bound nodeBound = Bound(nodeBsp, nodeSphere);

                element.addTransformElements(nodeBsp, nodeBound.result, capsule, &o.transforms[j]);
            }
        }
    }
}

int calculateClusterRecurse(int id, ref const(Sphere) sphere, int* iterator, int max)
{
    auto cluster = &currentSbsp.clusters[id];

    if(clusterComputeIds[id].assignEqual(masterComputeId)) return 0;
    if(max == 0)                                           return 0;

    int total = 0;

    *iterator = id;

    iterator += 1;
    total    += 1;
    max      -= 1;

    foreach(ref p ; cluster.portals)
    {
        auto portal = &currentSbsp.clusterPortals[p.portal];
        auto plane  = &currentSbsp.collisionBsp.planes[portal.planeIndex].plane;

        float distance = plane.distanceToPoint(sphere.center);

        // todo fix implementation
        // we need to test with portal indicies when the sphere is intersecting the plane
        // todo move to a separate function, see CalcNearByObjectRecurse()

        if(distance >= -sphere.radius && distance <= sphere.radius)
        {
            int index = portal.frontCluster == id ? portal.backCluster : portal.frontCluster;
            int count = calculateClusterRecurse(index, sphere, iterator, max);

            iterator += count;
            total    += count;
            max      -= count;

            if(max == 0)
            {
                return total;
            }
        }
    }

    return total;
}


static
bool calculateRenderSurface(
    TagScenarioStructureBsp* sbsp,
    Vec3                     point,
    int                      leafIndex,
    int                      planeIndex,
    ref RenderSurfaceResult  result)
{
    auto leaf = &sbsp.leaves[leafIndex & int.max];
    Vec2 coord;

    foreach(i ; leaf.surfaceReferences .. leaf.surfaceReferences + leaf.surfaceReferenceCount)
    {
        auto leafSurface = &sbsp.leafSurfaces[i];

        if(leafSurface.node == indexNone)                                      continue;
        if(sbsp.collisionBsp.bsp3dNodes[leafSurface.node].plane != planeIndex) continue;

        int lightmapIndex;
        int materialIndex;

        sbsp.findLightmapMaterialFromSurface(leafSurface.surface, lightmapIndex, materialIndex);

        TagBspVertex*[3] vert;

        if(!sbsp.getSurfaceVertices(lightmapIndex, materialIndex, leafSurface.surface, vert))
        {
            continue;
        }

        if(calculateCoordInTriangle(point, vert[0].position, vert[1].position, vert[2].position, coord))
        {
            result.lightmapIndex = lightmapIndex;
            result.materialIndex = materialIndex;
            result.surfaceIndex  = leafSurface.surface;
            result.coord         = coord;

            return true;
        }
    }

    return false;
}
}

// End of World struct //////////////////////////////////////////////////////////////////////////////////////////////////////


// TODO(REFACTOR) move these two ptr structures into a separate module
struct OverseerGObjectPtr
{
@nogc nothrow:

    import core.stdc.string : memcpy;

    @disable this(this);

    private Control* control;

    static OverseerGObjectPtr make(const(void)[] init)
    {
        OverseerGObjectPtr result;

        if(init)
        {
            // todo merge control and object into one malloc?
            result.control        = mallocCast!Control(Control.sizeof);
            result.control.object = mallocCast!GObject(init.length);
            result.control.count  = 1;

            memcpy(result.control.object, init.ptr, init.length);
        }

        return result;
    }

    ~this()
    {
        if(control)
        {
            control.destroyObject();
            control.count -= 1;

            if(control.count == 0)
            {
                free(control);
            }
        }
    }

    @property GObject* ptr()
    {
        return control ? control.object : null;
    }

    SheepGObjectPtr makeSheep()
    {
        return control.makeSheep();
    }

    private struct Control
    {
    @nogc nothrow:

        @disable this(this);

        int      count = 1;
        GObject* object;

        SheepGObjectPtr makeSheep()
        {
            return SheepGObjectPtr(this);
        }

        void destroyObject()
        {
            if(object)
            {
                object.byTypeDestruct();
                free(object);
                object = null;
            }
        }
    }

}

// TODO remove this and use a DatumArray instead for objects?
struct SheepGObjectPtr
{
@nogc nothrow:

    this(this)
    {
        if(control)
        {
            control.count += 1;
        }
    }

    ~this()
    {
        if(control)
        {
            control.count -= 1;

            if(control.count == 0)
            {
                control.destroyObject();
                free(control);
            }
        }
    }

    bool opCast(T : bool)() const
    {
        return control !is null;
    }

    @property inout(GObject)* ptr() inout
    {
        assert(control);
        return control.object;
    }

private:

    OverseerGObjectPtr.Control* control;

    this(ref OverseerGObjectPtr.Control c)
    {
        control = &c;
        c.count += 1;
    }
}