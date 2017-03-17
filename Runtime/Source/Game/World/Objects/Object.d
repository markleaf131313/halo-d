
module Game.World.Objects.Object;

import std.bitmanip : bitfields;
import std.conv     : to;
import std.meta     : allSatisfy, anySatisfy, Filter;
import std.traits   : Parameters, ReturnType, hasMember;
import std.typecons : Tuple;

import ImGui;

import Game.World.Objects;
import Game.World.World : World, SheepGObjectPtr;

import Game.Cache;
import Game.Core;
import Game.Tags;


struct GObjectTypeMask
{
@nogc nothrow:

    private enum isObjectType(T) = is(T == TagEnums.ObjectType);

    this(Args...)(Args args) if(allSatisfy!(isObjectType, Args))
    {
        set(args);
    }

    pragma(inline, true)
    void set(Args...)(Args args) if(allSatisfy!(isObjectType, Args))
    {
        foreach(i ; args)
        {
            bits = bits | (1u << uint(i));
        }
    }

    pragma(inline, true)
    void setAll()
    {
        bits = ~0;
    }

    pragma(inline, true)
    bool isSet(TagEnums.ObjectType type) const
    {
        return (bits >>> uint(type)) & 1;
    }

    pragma(inline, true)
    bool anySet() const
    {
        return bits != 0;
    }

    pragma(inline, true)
    bool anySet(Args...)(Args args) const if(args.length && allSatisfy!(isObjectType, Args))
    {
        uint anyBits = 0;
        foreach(i ; args)
        {
            anyBits = anyBits | (1u << uint(i));
        }

        return (bits & anyBits) != 0;
    }

    private uint bits;
}

// TODO(REFACTOR) use GameObject or Entity instead of GObject
struct GObject
{
@nogc nothrow:

@disable this(this);

struct Creation
{
    struct Flags
    {
        mixin(bitfields!(
            bool, "playerControlled", 1,
            uint, "", 7
        ));
    }

    Flags flags;
    DatumIndex tagIndex;

    int regionPermutation = indexNone;
    int playerIndex       = indexNone;

    TagEnums.Team team;

    Vec3 position           = 0.0f;
    Vec3 velocity           = 0.0f;
    Vec3 rotationalVelocity = 0.0f;

    Vec3 forward = Vec3(1, 0, 0);
    Vec3 up      = Vec3(0, 0, 1);
}

struct Rotation
{
@nogc nothrow:

    Vec3 forward;
    Vec3 up;

    // TODO rename "left"
    Vec3 side()   const { return cross(up, forward); }
    Mat3 toMat3() const { return Mat3.fromPerpUnitVectors(forward, up); }
}

struct ClusterNode
{
    int cluster;
    DList!(GObject*).Iterator iterator;
}

struct Damage
{
@nogc nothrow:

    struct Flags
    {
        mixin(bitfields!(
            bool, "healthDamaged",         1,
            bool, "shieldDamaged",         1,
            bool, "healthDepleted",        1,
            bool, "shieldDepleted",        1,
            bool, "overShieldCharging",    1,
            bool, "kill",                  1,
            bool, "killSilent",            1,
            bool, "meleeAttackInhibited",  1,
            bool, "weaponAttackInhibited", 1,
            bool, "walkingInhibited",      1,
            bool, "weaponDropForced",      1,
            bool, "cannotTakeDamage",      1,
            bool, "shieldRecharging",      1,
            bool, "killedNoStatistics",    1,
            ubyte, "",                     2,
        ));
    }

    Flags flags;

    float health;
    float healthMaximum;
    float healthDamageCurrent;
    float healthDamageRecent;
    int   healthDamageUpdateTick;

    float shield;
    float shieldMaximum;
    float shieldDamageCurrent;
    float shieldDamageRecent;
    int   shieldDamageUpdateTick;

    int stunTicks;

    private
    void update(string name)()
    {
        mixin("alias current = " ~ name ~ "DamageCurrent;");
        mixin("alias recent  = " ~ name ~ "DamageRecent;");
        mixin("alias tick    = " ~ name ~ "DamageUpdateTick;");

        enum float percentPerTick = 0.5f * gameFramesPerSecond; // 2 seconds to go from 1 to 0
        enum int   recentDelay    = 2    * gameFramesPerSecond; // 2 second delay

        if(tick >= 0)
        {
            tick += 1;

            current -= percentPerTick;

            if(tick > recentDelay)
            {
                recent -= percentPerTick;
            }

            current = max(current, 0.0f);
            recent  = max(recent,  0.0f);

            if(current == 0.0f && recent == 0.0f)
            {
                tick = indexNone;
            }
        }
    }

    void updateRecentDamage()
    {
        update!"health"();
        update!"shield"();
    }

}

struct DamageOptions
{
    struct Flags
    {
        mixin(bitfields!(
            bool, "areaOfEffect", 1,
            bool, "silent",       1,
            ubyte, "",            6,
        ));
    }

    DatumIndex tagIndex; // damage effect tag

    Flags flags;

    DatumIndex    instigatorPlayerIndex;
    GObject*      instigatorObject;
    TagEnums.Team instigatorTeam;

    World.Location location;

    Vec3 center;
    Vec3 position;
    Vec3 direction;

    float scale      = 1.0f;
    float multiplier = 1.0f;

    TagEnums.MaterialType material;
}

struct AnimationController
{
@nogc nothrow:

    enum State
    {
        invalid,
        end,
        loop,
        play,
        next,
        key,
    }

    alias hasAnimation this;

    int animationIndex = indexNone;
    int frame;


    @property bool hasAnimation() const
    {
        return animationIndex != indexNone;
    }

    void reset()
    {
        animationIndex = indexNone;
        frame          = 0;
    }

    State increment(const TagModelAnimations* anim)
    {
        if(!hasAnimation) return State.invalid;

        const block = &anim.animations[animationIndex];

        frame += 1;

        if(frame < block.frameCount)
        {
            if(frame + 1 == block.frameCount)
            {
                return State.end;
            }

            if(frame == block.keyFrameIndex || frame == block.secondKeyFrameIndex)
            {
                return State.key;
            }

            return State.play;
        }
        else if(block.loopFrameIndex == 0)
        {
            // todo randomize next animation

            frame = 0; // default cause we just replay this animation

            return State.next;
        }
        else
        {
            frame = block.loopFrameIndex;
            return State.loop;
        }
    }
}

struct MarkerTransform
{
    int node;
    Transform local;
    Transform world;
}

struct Attachment
{
    enum Type
    {
        none = indexNone,
        light,
        loopingSound,
        effect,
        contrail,
        particle,
    }

    Type       type;
    DatumIndex index;
}

struct Lighting
{
    struct DistantLight
    {
        ColorRgb color;
        Vec3     direction;
    }

    ColorRgb ambientColor;

    int             distantLightCount;
    DistantLight[2] distantLight;

    int pointLightCount;
    // todo point light, use defered rending instead ?

    ColorArgb reflectionTint;
    Vec3      shadowVector;
    ColorRgb  shadowColor;

}

struct CachedLighting
{
    Lighting current;
    Lighting desired;
}

struct HeaderFlags
{
    mixin(bitfields!(
        bool, "active",                1,
        bool, "newlyCreated",          1,
        bool, "requestedDeletion",     1,
        bool, "automaticDeactivation", 1,
        bool, "connectedToParent",     1, // todo not sure if this is a valid name, not used when disconnecting
                                          // from parrent (used whend connecting)
        bool, "visible",               1,
        uint, "", 2
    ));
}

struct Flags
{
    mixin(bitfields!(
        bool, "hidden",                     1,
        bool, "inWater",                    1,
        bool, "atRest",                     1,
        bool, "connectedToMap",             1,
        bool, "outsideMap",                 1,
        bool, "doesNotCastShadow",          1,
        bool, "hasCollisionModel",          1,
        bool, "deactivationCausesDeletion", 1,
        bool, "prohibitActivation",         1,
        bool, "limp",                       1,
        uint, "",                           6,
    ));
}


World* world;

SheepGObjectPtr selfPtr;

HeaderFlags headerFlags;
Flags flags;

DatumIndex tagIndex;
TagEnums.ObjectType type;

SlaveComputeIdentifier computeId;

int parentNodeIndex;

GObject* parent;
GObject* firstChildObject;
GObject* nextSiblingObject;

World.Location location; // TODO(IMPLEMENT), might be set when connecting to map?

Sphere bound;
Vec3 position;
Rotation rotation;
Vec3 velocity           = 0.0f;
Vec3 rotationalVelocity = 0.0f;

float scale = 0.0f;

int playerIndex;
TagEnums.Team associatedTeam;

CachedLighting cachedLighting;

int shaderPermutation;
int regionPermutation;
int[TagConstants.Model.maxRegions] regionPermutationIndices;
ubyte[TagConstants.Model.maxRegions] regionVitalities;

AnimationController baseAnimation;

int interpolateIndex;
int interpolateCount;

Orientation[TagConstants.Animation.maxNodes] nodeOrientations;
Orientation[TagConstants.Animation.maxNodes] nodeInterpolateOrientations;
Transform  [TagConstants.Animation.maxNodes] transforms;

float[TagConstants.Object.maxFunctions] importFunctionValues;
float[TagConstants.Object.maxFunctions] exportFunctionValues;
bool [TagConstants.Object.maxFunctions] exportFunctionValidities;

Attachment[TagConstants.Object.maxAttachments] attachments;

int occupiedClustersCount;
ClusterNode[TagConstants.Object.maxClusterPresence] occupiedClusters; // todo implement static_vector

Damage damage;

bool byTypePreInitialize(Creation* creation) const
{
    return makeCallByType!"implPreInitialize"(this, creation);
}

bool byTypeInitialize()
{
    return makeCallByType!"implInitialize"(this);
}

bool byTypeUpdateLogic()
{
    return makeCallByType!"implUpdateLogic"(this);
}

bool byTypeProcessOrientations(Orientation* orientations)
{
    return makeCallByType!"implProcessOrientations"(this, orientations);
}

bool byTypeUpdateMatrices()
{
    return makeCallByType!"implUpdateMatrices"(this);
}

bool byTypeUpdateImportFunctions()
{
    return makeCallByType!"implUpdateImportFunctions"(this);
}

void byTypeDestruct()
{
    makeCallByType!("__xdtor", ByType.doDerived)(this);
}

bool byTypeDebugUi()
{
    return makeCallByType!"implDebugUi"(this);
}

static auto byTypeInit(TagEnums.ObjectType type)
{
    import std.ascii : toUpper;

    template strInit(T...)
    {
        static if(T.length == 0)
        {
            enum strInit = "";
        }
        else static if(T[0] == "invalid")
        {
            enum strInit = strInit!(T[1 .. $]);
        }
        else static if(mixin("is(" ~ toUpper(T[0][0]) ~ T[0][1..$] ~ " O)"))
        {
            enum strInit = "typeid(" ~ O.stringof ~ "), "
                ~ strInit!(T[1 .. $]);
        }
        else
        {
            pragma(msg, __FILE__ ~ ": Missing type " ~ T[0]);
            enum strInit = "null, " ~ strInit!(T[1 .. $]);
        }
    }

    static TypeInfo[TagEnums.ObjectType.max + 1] sizes
        = mixin("[ " ~ strInit!(__traits(allMembers, TagEnums.ObjectType)) ~ " ]");

    if(auto typeInfo = sizes[type])
    {
        return typeInfo.initializer();
    }

    return null;
}

inout(Unit)* isUnit() inout
{
    if(GObjectTypeMask(TagEnums.ObjectType.biped, TagEnums.ObjectType.vehicle).isSet(type))
    {
        return cast(inout(Unit)*)&this;
    }

    return null;
}

inout(Biped)* isBiped() inout
{
    if(type == TagEnums.ObjectType.biped)
    {
        return cast(inout(Biped)*)&this;
    }

    return null;
}

void createAttachments()
{
    const tagObject = Cache.get!TagObject(tagIndex);

    foreach(int i, ref tagAttachment ; tagObject.attachments)
    {
        if(!tagAttachment.type)
        {
            continue;
        }

        Attachment.Type type;

        switch(tagAttachment.type.id)
        {
        case TagId.light:        type = Attachment.Type.light;        break;
        case TagId.soundLooping: type = Attachment.Type.loopingSound; break;
        case TagId.effect:       type = Attachment.Type.effect;       break;
        case TagId.contrail:     type = Attachment.Type.contrail;     break;
        case TagId.particle:     type = Attachment.Type.particle;     break;
        default:
        }

        DatumIndex index;

        switch(type)
        {
        case Attachment.Type.light:
            break;
        case Attachment.Type.loopingSound:

            break;
        case Attachment.Type.effect:
            break;
        case Attachment.Type.contrail:
            break;
        case Attachment.Type.particle:
            break;
        default:
        }

        attachments[i] = Attachment(type, index);
    }

}

void updateLogic()
{
    const tagObject = Cache.get!TagObject(tagIndex);

    if(interpolateCount)
    {
        interpolateIndex += 1;

        if(interpolateIndex >= interpolateCount)
        {
            interpolateCount = 0;
        }
    }

    byTypeUpdateLogic();

    if(tagObject.collisionModel)
    {
        updateVitality();
    }

    updateExportFunctions();

    // todo limping flag, dont update matrices

    updateMatrices();

    if(firstChildObject)
    {
        firstChildObject.updateLogic();
    }

    if(parent && nextSiblingObject)
    {
        nextSiblingObject.updateLogic();
    }

    byTypeUpdateMatrices();
}

void requestDeletion(bool deleteSiblings = false)
{
    if(firstChildObject)
    {
        firstChildObject.requestDeletion(true);
    }

    if(deleteSiblings && nextSiblingObject)
    {
        nextSiblingObject.requestDeletion(true);
    }

    headerFlags.requestedDeletion = true;

    // todo hide lights if not flags.hidden

    headerFlags.visible = false;

    // todo remove from scenario name list
}

void removeChild(GObject* child)
{
    for(GObject** i = &firstChildObject; *i; i = &(*i).nextSiblingObject)
    {
        if(*i == child)
        {
            *i = (*i).nextSiblingObject;
            return;
        }
    }
}

void activate()
{
    if(!headerFlags.active && !flags.prohibitActivation && parent is null)
    {
        headerFlags.active = true;
    }
}

void setVisible(bool visible)
{
    // todo hide/show light Objects

    if(Cache.get!TagObject(tagIndex).model)
    {
        flags.hidden = !visible;
    }
    else
    {
        if(visible)
        {
            flags.hidden = true;
        }
    }
}

void setRotationVertical(Vec2 direction)
{
    if(parent is null)
    {
        rotation.forward = Vec3(direction, 0.0f);
        rotation.up      = Vec3(0, 0, 1);
    }
}

Vec3 getWorldPosition() const
{
    if(parent)
    {
        return parent.transforms[parentNodeIndex].mat4x3 * position;
    }
    else
    {
        return position;
    }
}

Rotation getWorldRotation() const
{
    if(parent)
    {
        return Rotation(
            parent.transforms[parentNodeIndex].mat3 * rotation.forward,
            parent.transforms[parentNodeIndex].mat3 * rotation.up);
    }
    else
    {
        return rotation;
    }
}

void updateMatrices()
{
    auto tagObject    = Cache.get!TagObject(tagIndex);
    auto tagModel     = Cache.get!TagGbxmodel(tagObject.model);
    auto tagAnimation = Cache.get!TagModelAnimations(tagObject.animationGraph);

    enum mask = GObjectTypeMask(
        TagEnums.ObjectType.biped,
        TagEnums.ObjectType.vehicle,
        TagEnums.ObjectType.weapon,
        TagEnums.ObjectType.equipment,
        TagEnums.ObjectType.garbage);

    bool typeHasAnimation = mask.isSet(type);

    Orientation[TagConstants.Animation.maxNodes] defaultOrientations = void;
    Orientation* orientations = typeHasAnimation ? nodeOrientations.ptr : defaultOrientations.ptr;

    if(tagModel)
    {
        Transform* parentMatrix = parent ? &parent.transforms[parentNodeIndex] : null;
        bool animationIsWorldRelative = false;

        if(tagAnimation && baseAnimation)
        {
            // todo flag 0x80, randomize animation frame?

            auto animationData = &tagAnimation.animations[baseAnimation.animationIndex];
            animationIsWorldRelative = animationData.flags.worldRelative;

            if(!animationData.decodeBase(baseAnimation.frame, orientations))
            {
                tagModel.copyDefaultOrientation(orientations);
            }
        }
        else
        {
            tagModel.copyDefaultOrientation(orientations);
        }

        if(tagAnimation)
        {
            foreach(ref object ; tagAnimation.objects)
            {
                // todo implement object function animation modifying
            }
        }

        if(scale != 0.0f)
        {
            orientations[0].position *= scale;
            orientations[0].scale    *= scale;
        }

        if(tagAnimation)
        {
            byTypeProcessOrientations(orientations);
        }

        if(interpolateCount)
        {
            float alpha = float(interpolateIndex) / interpolateCount;

            for(int i = 0; i < tagModel.nodes.size; ++i)
            {
                orientations[i] = mix(nodeInterpolateOrientations[i], orientations[i], alpha);
            }
        }

        int[TagConstants.Animation.maxNodes] indices = void;
        int count = 1;

        indices[0] = 0;

        for(int i = 0; i < count; ++i)
        {
            int nodeIndex = indices[i];
            auto node = &tagModel.nodes[nodeIndex];

            Transform nodeTransform = orientations[nodeIndex];

            if(nodeIndex == 0)
            {
                if(animationIsWorldRelative)
                {
                    transforms[nodeIndex] = nodeTransform;
                }
                else
                {
                    Transform objectTransform = Transform(rotation.toMat3(), position);

                    if(auto tagPhysics = Cache.get!TagPhysics(tagObject.physics))
                    {
                        objectTransform.position = objectTransform * -tagPhysics.centerOfMass;
                    }

                    objectTransform.position = objectTransform * tagObject.originOffset;

                    if(parentMatrix)
                    {
                        // todo check parent flags - not automatically places?
                        transforms[nodeIndex] = (*parentMatrix) * objectTransform * nodeTransform;
                    }
                    else
                    {
                        transforms[nodeIndex] = objectTransform * nodeTransform;
                    }
                }
            }
            else
            {
                transforms[nodeIndex] = transforms[node.parentNodeIndex] * nodeTransform;
            }

            if(node.nextSiblingNodeIndex != indexNone)
            {
                indices[count++] = node.nextSiblingNodeIndex;
            }

            if(node.firstChildNodeIndex != indexNone)
            {
                indices[count++] = node.firstChildNodeIndex;
            }
        }
    }
    else
    {
        transforms[0] = Transform(rotation.toMat3(), position);
    }

    bound.center = transforms[0] * tagObject.boundingOffset;
    bound.radius = tagObject.boundingRadius;

    if(scale != 0.0f)
    {
        bound.radius *= scale;
    }
}

void updateHierarchyMatrices()
{
    updateMatrices();

    for(auto child = firstChildObject; child; child = child.nextSiblingObject)
    {
        child.updateHierarchyMatrices();
    }
}

void connectToWorld(const(World.Location)* loc = null)
{
    if(parent)
    {
        nextSiblingObject = parent.firstChildObject;
        parent.firstChildObject = &this;

        headerFlags.connectedToParent = true;
    }
    else
    {
        World.Location tempLocation = void;

        if(loc is null)
        {
            loc = &tempLocation;

            tempLocation = world.findLocation(bound.center);

            if(tempLocation.cluster == indexNone)
            {
                tempLocation = world.findLocation(position);
            }
        }

        headerFlags.connectedToParent = false;

        if(loc.cluster == indexNone)
        {
            flags.outsideMap = true;

            // todo implement, should it even be added to noncliideable ?
            // world.addObjectToNoncollideableCluster();
        }
        else
        {
            flags.outsideMap = false;
            location = *loc;

            int[TagConstants.Object.maxClusterPresence] clusters = void;
            int num = world.calculateOccupiedClusters(loc.cluster, bound, clusters.ptr, clusters.length);

            foreach(i ; 0 .. num)
            {
                occupiedClusters[occupiedClustersCount]
                    = ClusterNode(clusters[i], world.addObjectToCollideableCluster(clusters[i], &this));

                occupiedClustersCount += 1;
            }
        }

        if(headerFlags.automaticDeactivation)
        {
            if(location.cluster != indexNone && world.isClusterActive(location.cluster))
            {
                activate();
            }
            else if(flags.deactivationCausesDeletion)
            {
                // todo nodify of object deletion;
            }
        }
    }

    flags.connectedToMap = true;
}

void disconnectFromWorld()
{
    if(parent)
    {
        parent.removeChild(&this);
    }
    else
    {
        if(flags.outsideMap)
        {
            foreach(ref node ; occupiedClusters[0 .. occupiedClustersCount])
            {
                world.removeObjectFromNoncollideableCluster(node.cluster, node.iterator);
            }
        }
        else
        {
            foreach(ref node ; occupiedClusters[0 .. occupiedClustersCount])
            {
                world.removeObjectFromCollideableCluster(node.cluster, node.iterator);
            }
        }

        occupiedClustersCount = 0;

        if(headerFlags.automaticDeactivation)
        {
            headerFlags.active = false;
        }
    }

    flags.connectedToMap = false;
}

void placeInWorldRelativeToParent()
{
    disconnectFromWorld();

    Transform transform = parent.transforms[parentNodeIndex] * Transform(rotation.toMat3(), position);

    position         = transform.position;
    rotation.forward = transform.forward;
    rotation.up      = transform.up;

    velocity           = parent.velocity;
    rotationalVelocity = parent.rotationalVelocity;

    parent = null;
    parentNodeIndex = indexNone;

    connectToWorld();
    activate();
}

void move(ref Vec3 position, ref Vec3 forward, ref Vec3 up)
{
    disconnectFromWorld();

    this.position         = position;
    this.rotation.forward = forward;
    this.rotation.up      = up;

    updateMatrices();
    connectToWorld();
}

void interpolateCurrent(int frames)
{
    auto tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);

    if(frames > (interpolateCount - interpolateIndex))
    {
        // todo verify this implementaiton

        interpolateIndex = 0;
        interpolateCount = frames;

        for(int i = 0; i < tagModel.nodes.size; ++i)
        {
            nodeInterpolateOrientations[i] = nodeOrientations[i];
        }
    }
}

void attachTo(const(char)[] gripName, GObject* other, const(char)[] handName)
{
    disconnectFromWorld();

    MarkerTransform handMarker = void;
    other.findMarkerTransform(handName, handMarker);

    int node = 0;

    if(gripName.length == 0)
    {
        node = handMarker.node;

        rotation.forward = handMarker.local.forward;
        rotation.up      = handMarker.local.up;
        position         = handMarker.local.position;
    }
    else
    {
        MarkerTransform gripMarker;

        // todo grip MarkerTransform
        position = Vec3(0);
    }

    parent = other;
    parentNodeIndex = node;

    headerFlags.active = false;

    connectToWorld();
}

int getParentHierarchy(GObject** values, int max)
{
    int i = 0;
    for(GObject* next = &this; i < max && next; next = next.parent, ++values, ++i)
    {
        *values = next;
    }

    return i;
}

GObject* getAbsoluteParent()
{
    auto top = &this;

    while(top.parent)
    {
        top = top.parent;
    }

    return top;
}

GObject* getFirstVisibleObject()
{
    GObject* result = &this;

    while(result.parent && result.flags.hidden)
    {
        result = result.parent;
    }

    return result;
}

int findMarker(const(char)[] name)
{
    auto tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);

    foreach(int i, ref marker ; tagModel.markers)
    {
        if(iequals(marker.name, name))
        {
            return i;
        }
    }

    return indexNone;
}

int findMarkerTransform(const(char)[] name, Tuple!(int, Transform)[] output)
{
    int index = findMarker(name);

    if(index == indexNone)
    {
        return 0;
    }

    const tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);
    const marker   = &tagModel.markers[index];
    int   count    = 0;

    // todo return an identity matrix and root node matrix if no matirces found and we want 1 marker..

    foreach(ref instance ; marker.instances)
    {
        if(count >= output.length)
        {
            break;
        }

        if(regionPermutationIndices[instance.regionIndex] == instance.permutationIndex)
        {
            auto result = &output[count];

            (*result)[0] = instance.nodeIndex;
            (*result)[1] = Transform(conjugate(instance.rotation), instance.translation);

            count += 1;
        }
    }

    return count;
}

int findMarkerTransform(const(char)[] name, int size, MarkerTransform* output)
{
    int index = findMarker(name);

    if(index == indexNone)
    {
        return 0;
    }

    const tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);
    const marker   = &tagModel.markers[index];
    int   count    = 0;

    // todo return an identity matrix and root node matrix if no matirces found and we want 1 marker..

    foreach(ref instance ; marker.instances)
    {
        if(count >= size)
        {
            break;
        }

        if(regionPermutationIndices[instance.regionIndex] == instance.permutationIndex)
        {
            auto result = &output[count];

            result.node  = instance.nodeIndex;
            result.local = Transform(conjugate(instance.rotation), instance.translation);
            result.world = transforms[instance.nodeIndex] * result.local;

            count += 1;
        }
    }

    return count;
}

bool findMarkerTransform(const(char)[] name, ref MarkerTransform transform)
{
    if(findMarkerTransform(name, 1, &transform) == 0)
    {
        transform.node  = 0;
        transform.local = Transform();
        transform.world = transforms[0];

        if(name is null || name.length != 0)
        {
            return false;
        }
    }

    return true;
}

bool setRegionsPermutations(int desiredPermutation)
{
    auto tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);

    bool result = true;

    foreach(i, ref region ; tagModel.regions)
    {
        int[TagConstants.Model.maxFindablePermutations] permutations = void;
        int count = region.findRandomizablePermutations(desiredPermutation, permutations);

        if(count == 0)
        {
            if(desiredPermutation != indexNone)
            {
                count = region.findRandomizablePermutations(0, permutations);
            }

            if(count == 0)
            {
                regionPermutationIndices[i] = 0;
                result = false;

                continue;
            }
        }

        if(count == 1)
        {
            regionPermutationIndices[i] = permutations[0];
        }
        else
        {
            // todo randomize
            regionPermutationIndices[i] = permutations[1];
        }
    }

    return result;
}

int getPermutationIdFromRegions()
{
    auto tagModel = Cache.get!TagGbxmodel(Cache.get!TagObject(tagIndex).model);

    int id = 0;

    foreach(i, ref region ; tagModel.regions)
    {
        id = region.permutations[regionPermutationIndices[i]].identifier;
    }

    return id; // todo is this correct ?
}

void initializeRegions()
{
    auto tagObject = Cache.get!TagObject(tagIndex);

    if(tagObject.model)
    {
        auto tagModel = Cache.get!TagGbxmodel(tagObject.model);

        if(regionPermutation <= 0 || !setRegionsPermutations(regionPermutation))
        {
            setRegionsPermutations(indexNone);

            regionPermutation = getPermutationIdFromRegions();

            if(regionPermutation != 0)
            {
                // region permutation may not be uniform due to randomization
                // so we need to set indices again here

                setRegionsPermutations(regionPermutation);
            }
        }
    }
}

void initializeVitality()
{
    auto tagObject = Cache.get!TagObject(tagIndex);

    float shieldMaximum = 0.0f;
    float healthMaximum = 0.0f;

    if(tagObject.collisionModel)
    {
        auto tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);

        shieldMaximum = tagCollision.maximumShieldVitality;
        healthMaximum = tagCollision.maximumBodyVitality;
    }

    damage.shieldMaximum = shieldMaximum;
    damage.healthMaximum = healthMaximum;

    damage.shield = shieldMaximum == 0.0f ? 0.0f : 1.0f;
    damage.health = healthMaximum == 0.0f ? 0.0f : 1.0f;
}

void updateVitality()
{
    const tagObject    = Cache.get!TagObject(tagIndex);
    const tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);
    const tagGlobals   = Cache.inst.globals();

    if(damage.flags.kill | damage.flags.killSilent)
    {
        if(!damage.flags.healthDepleted && tagGlobals.fallingDamage.fallingDamage)
        {
            DamageOptions options;
            options.tagIndex     = tagGlobals.fallingDamage.fallingDamage.index;
            options.flags.silent = damage.flags.killSilent;

            dealDamage(options, indexNone, indexNone, indexNone);
        }

        damage.flags.kill       = false;
        damage.flags.killSilent = false;
    }

    damage.flags.shieldRecharging = false;

    if(damage.shieldMaximum > 0.0f && !damage.flags.healthDepleted)
    {
        if(damage.flags.overShieldCharging)
        {
            damage.shield += TagConstants.Object.overShieldChargePerSecond / float(gameFramesPerSecond);

            if(damage.shield < TagConstants.Object.overShieldPercent)
            {
                damage.flags.shieldRecharging = true;
            }
            else
            {
                damage.shield = TagConstants.Object.overShieldPercent;
                damage.flags.shieldDepleted = false;
            }
        }
        else if(damage.shield < 1.0f)
        {
            if(damage.stunTicks > 0)
            {
                damage.stunTicks -= 1;
            }
            else
            {
                // TODO difficulty modifier recharging

                if(damage.flags.shieldDepleted)
                {
                    // TODO create recharging effect
                    // TODO make regions go on, that go off with shield

                    damage.flags.shieldDepleted = false;
                }

                damage.shield += tagCollision.shieldRechargePerTick; // TODO unhardcode frames per second

                if(damage.shield >= 1.0f)
                {
                    damage.shield = 1.0f;
                }
                else
                {
                    damage.flags.shieldRecharging = true;
                }
            }
        }
    }

    damage.updateRecentDamage();
}

void triggerShieldDepleted()
{
    if(damage.flags.shieldDepleted)
    {
        return;
    }

    damage.flags.shieldDepleted = true;

    const tagObject = Cache.get!TagObject(tagIndex);

    if(tagObject.collisionModel)
    {
        // TODO create shield depleted effect
    }

    // TODO hide regions with shield off flag

}

void triggerHealthDepleted()
{
    if(damage.flags.healthDepleted)
    {
        return;
    }

    damage.flags.healthDepleted = true;

    const tagObject = Cache.get!TagObject(tagIndex);

    if(tagObject.collisionModel)
    {
        // TODO create health depleted effect
    }

    if(type == TagEnums.ObjectType.vehicle)
    {
        // TODO tell children objects they were eliminated
    }

    triggerShieldDepleted();
}

private
struct ImplDamageFlags
{
    mixin(bitfields!(
        bool, "friendly",       1,
        bool, "healthDepleted", 1,
        bool, "shieldDepleted", 1,
        ushort, "", 13,
    ));
}

private
void dealDamageToShield(
    const(TagDamageEffect)*          tagDamageEffect,
    const(Tag.DamageMaterialsBlock)* tagDamageMaterial,
    ref ImplDamageFlags              damageFlags,
    ref float                        damageAmount,
    ref float                        damageDealt)
{
    const tagObject    = Cache.get!TagObject(tagIndex);
    const tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);

    // TODO check singleplayer, special case with falling damage if singleplayer

    float leftover = damageAmount;
    float dealt    = 0.0f;

    if(damage.shield > 0.0f)
    {
        // TODO difficulty setting, scale shield maximum
        const float shieldMaximum    = damage.shieldMaximum;
        const float shieldMaxDivisor = shieldMaximum <= 0.0f ? 0.0f : 1.0f / shieldMaximum;
        const float materialModifier = tagDamageEffect.getMaterialModifier(tagCollision.shieldMaterialType);

        if(!damageFlags.friendly || tagCollision.flags.alwaysShieldsFriendlyDamage)
        {
            dealt = leftover * (1.0f - tagDamageMaterial.shieldLeakPercentage);

            if(tagCollision.shieldFailureThreshold > 0.0f && damage.shield <= tagCollision.shieldFailureThreshold)
            {
                // TODO shield failure function
            }
        }

        bool preventDamage = false;

        if(damage.flags.overShieldCharging)
        {
            dealt    = leftover;
            leftover = 0.0f;
        }
        else
        {
            dealt = max(dealt, 0.0f);
            leftover -= dealt;

            // TODO friendly difficulty scaling

            float dealtScaled  = dealt * tagDamageMaterial.shieldDamageMultiplier * materialModifier;
            float dealtPercent = dealtScaled * shieldMaxDivisor;
            preventDamage      = dealtScaled < 0.0001f;

            if(dealtPercent > damage.shield || tagDamageEffect.sideEffect == TagEnums.DamageSideEffect.emp)
            {
                if(dealtScaled - damage.shield * shieldMaximum > 0.0f)
                {
                    leftover += dealtScaled - damage.shield * shieldMaximum;
                }

                damage.shield = 0.0f;

                if(!damage.flags.shieldDepleted)
                {
                    triggerShieldDepleted();
                    damageFlags.shieldDepleted = true;
                }
            }
            else
            {
                if(!damage.flags.shieldDepleted)
                {
                    damage.shield -= dealtPercent;
                }

                if(!damage.flags.shieldDamaged && damage.shield < tagCollision.shieldDamagedThreshold)
                {
                    // TODO create effect, tagCollision.shieldDamagedEffect
                    damage.flags.shieldDamaged = true;
                }
            }
        }

        if(!preventDamage)
        {
            if(damage.flags.shieldDepleted)
            {
                damage.shieldDamageCurrent = 1.0f;
            }

            const float dealtPercent = (damageAmount - leftover) / shieldMaxDivisor;

            damage.shieldDamageUpdateTick = 0;
            damage.shieldDamageRecent     = min(damage.shieldDamageRecent  + dealtPercent, 1.0f);
            damage.shieldDamageCurrent    = min(damage.shieldDamageCurrent + dealtPercent, 1.0f);
        }
    }
    else
    {
        damage.shield = 0.0f;
    }

    if(dealt >= tagCollision.minimumStunDamage || damage.shield == 0.0f)
    {
        damage.stunTicks = cast(int)(tagCollision.stunTime * gameFramesPerSecond);
    }

    damageAmount = leftover;
    damageDealt  = dealt;
}

private
void dealDamageToHealth(
    const(TagDamageEffect)*          tagDamageEffect,
    const(Tag.DamageMaterialsBlock)* tagDamageMaterial,
    int                              nodeIndex,
    int                              regionIndex,
    ref DamageOptions                options,
    ref ImplDamageFlags              damageFlags,
    float                            damageAmount,
    ref float                        damageDealt)
{
    const tagObject    = Cache.get!TagObject(tagIndex);
    const tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);

    float dealt = damageAmount * tagDamageMaterial.bodyDamageMultiplier;

    if(tagCollision.flags.onlyDamagedWhileOccupied && type == TagEnums.ObjectType.vehicle)
    {
        // TODO check occupied, has driver in powered seat, set dealt to zero
    }

    // TODO falling category check in singleplayer
    // TODO scale maximum health based on team

    const float healthMaximum    = damage.healthMaximum;
    const float healthMaxDivisor = healthMaximum <= 0.0f ? 0.0f : 1.0f / healthMaximum;
    const float materialModifier = tagDamageEffect.getMaterialModifier(tagDamageMaterial.materialType);

    // TODO friendly fire based scaling

    float dealtPercent = dealt * healthMaxDivisor * materialModifier;

    if(!damage.flags.cannotTakeDamage)
    {
        if(dealt > 0.0f && tagDamageMaterial.flags.head)
        {
            if(tagDamageEffect.damageFlags.canCauseHeadshots)
            {
                // TODO check player controlled for single player, or multiplayer game
                //      set health to zero and flags
            }
            else if(tagDamageEffect.damageFlags.canCauseMultiplayerHeadshots)
            {
                // TODO multiplayer headshot, don't think this is ever used?
            }
        }

        damage.health -= dealtPercent;
    }

    if(regionIndex != indexNone)
    {
        // TODO damage specific region
    }

    damage.healthDamageUpdateTick = 0;
    damage.healthDamageCurrent    = min(damage.healthDamageCurrent + dealtPercent, 1.0f);
    damage.healthDamageRecent     = min(damage.healthDamageRecent  + dealtPercent, 1.0f);

    if(tagCollision.bodyDestroyedThreshold >= 0.0f || damage.health >= healthMaxDivisor * tagCollision.bodyDestroyedThreshold)
    {
        if(damage.health < 0.0f)
        {
            if(!damage.flags.healthDepleted)
            {
                foreach(ref tagRegion ; tagCollision.regions)
                {
                    if(tagRegion.flags.diesWhenObjectDies)
                    {
                        // TODO destroy region
                    }
                }

                triggerHealthDepleted();
                damageFlags.healthDepleted = true;
            }
        }
        else if(damage.health < healthMaxDivisor * tagCollision.bodyDestroyedThreshold && !damage.flags.healthDamaged)
        {
            // TODO create health damaged effect
            damage.flags.healthDamaged = true;
        }
    }
    else
    {
        assert(0); // TODO destroy object
    }

    // TODO create localized damage effect
    // TODO create area damage effect

    damageDealt = dealt;
}

private
void reactToDamage(ref DamageOptions options)
{
    const tagObject       = Cache.get!TagObject(tagIndex);
    const tagDamageEffect = Cache.get!TagDamageEffect(options.tagIndex);

    if(tagObject.accelerationScale >= 0.0001f)
    {
        Vec3 force = options.direction;
        force.z += 0.45f;

        normalize(force);

        force *= tagObject.accelerationScale * tagDamageEffect.instantaneousAcceleration * (1.0f / gameFramesPerSecond);

        switch(type)
        {
        case TagEnums.ObjectType.biped:
            Biped* biped = cast(Biped*)&this;

            if(!biped.unit.flags.impervious)
            {
                // TODO implement biped reaction
            }
            break;
        case TagEnums.ObjectType.vehicle:
            Vehicle* vehicle = cast(Vehicle*)&this;

            if(!vehicle.unit.flags.impervious)
            {
                if(tagDamageEffect.damageFlags.detonatesExplosives)
                {
                    force += force;
                }

                vehicle.applyForce(force);
            }
            break;
        case TagEnums.ObjectType.weapon:
        case TagEnums.ObjectType.equipment:
        case TagEnums.ObjectType.garbage:
            // TODO implement item reaction
            break;
        case TagEnums.ObjectType.projectile:
            // TODO implement projectile reaction
            break;
        default:
        }
    }

    // TODO damage related
    // TODO unit related

}

void dealDamage(ref DamageOptions options, int nodeIndex, int regionIndex, int materialIndex)
{
    const tagDamageEffect = Cache.get!TagDamageEffect(options.tagIndex);

    float damage = mix(tagDamageEffect.damageLowerBound, randomValue(tagDamageEffect.damageUpperBound), options.scale);
    damage *= options.multiplier;

    // TODO ai related damage scale
    // TODO multiplayer or singleplayer damage scaling

    // TODO flags that only uses the object and no parents
    GObject*[16] parents = void;
    int numParents = getParentHierarchy(parents.ptr, parents.length);

    bool passBodyDamageToParents = true;

    {
        const tagObject = Cache.get!TagObject(tagIndex);
        if(const tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel))
        {
            passBodyDamageToParents = !tagCollision.flags.parentNeverTakesBodyDamageForUs;
        }
    }

    // TODO entangled object, add to list of parents

    if(type == TagEnums.ObjectType.vehicle)
    {
        const tagUnit = Cache.get!TagUnit(tagIndex);
        float multiplier = tagUnit.riderDamageFraction * (1.0f - tagDamageEffect.vehiclePassthroughPenalty);

        // TODO multiplayer, count number of players in vehicle and divide damage by that amount

        options.multiplier = multiplier;

        for(GObject* next = firstChildObject; next; next = next.nextSiblingObject)
        {
            if(next.type != TagEnums.ObjectType.biped)
            {
                continue;
            }

            // TODO player controlled / has driver
            // TODO adjust options.flags

            next.dealDamage(options, indexNone, indexNone, indexNone);

        }

        options.multiplier = 1.0f;

    }

    foreach(GObject* parent ; parents[0 .. numParents])
    {
        if(!parent.isUnit())
        {
            continue;
        }

        // TODO check player controlled and apply effects of damage
    }

    foreach_reverse(i, parent ; parents[0 .. numParents])
    {
        if(damage <= 0.0f)
        {
            break;
        }

        const tagObject = Cache.get!TagObject(parent.tagIndex);

        ImplDamageFlags damageFlags;
        float           shieldDamage = 0.0f;
        float           healthDamage = 0.0f;

        if(const tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel))
        {
            // TODO hidden node field in collision
            // TODO team related damage checks
            // TODO lethal damage to unsuspecting (singleplayer only)

            const(Tag.DamageMaterialsBlock)* tagDamageMaterial;

            if(i == 0 && tagCollision.materials.inBounds(materialIndex))
            {
                tagDamageMaterial = &tagCollision.materials[materialIndex];
            }
            else if(tagCollision.materials.inBounds(tagCollision.indirectDamageMaterial))
            {
                tagDamageMaterial = &tagCollision.materials[tagCollision.indirectDamageMaterial];
            }
            else
            {
                static immutable Tag.DamageMaterialsBlock defaultDamageMaterial =
                {
                    shieldLeakPercentage:   0.0f,
                    shieldDamageMultiplier: 0.0f,
                    bodyDamageMultiplier:   0.0f,
                };

                tagDamageMaterial = &defaultDamageMaterial;
            }

            // TODO team related checks
            if(!tagDamageEffect.damageFlags.skipsShields && parent.damage.shieldMaximum > 0.0f)
            {
                if(i == 0 || tagCollision.flags.takesShieldDamageForChildren)
                {
                    dealDamageToShield(tagDamageEffect, tagDamageMaterial, damageFlags,  damage, shieldDamage);
                }
            }

            if(!tagDamageEffect.damageFlags.onlyHurtsShields)
            {
                if(i == 0 || passBodyDamageToParents && tagCollision.flags.takesBodyDamageForChildren)
                {
                    // TODO only damaged by explosives, set dmg to zero
                    // TODO team related checks, set dmg to zero

                    int bodyNodeIndex   = indexNone;
                    int bodyRegionIndex = indexNone;

                    if(i == 0)
                    {
                        bodyNodeIndex   = nodeIndex;
                        bodyRegionIndex = regionIndex;
                    }

                    dealDamageToHealth(tagDamageEffect, tagDamageMaterial, bodyNodeIndex, bodyRegionIndex,
                        options, damageFlags, damage, healthDamage);

                    damage = 0.0f; // don't pass damage to any other objects
                }
            }

            // TODO check first damage, set options output result to that amount
            // TODO update shields if damage dealt to it
            // TODO acceleration scale related update

            reactToDamage(options); // TODO
        }
    }
}

void dealAreaDamage(ref DamageOptions options, bool doSiblings = false)
{
    const tagObject       = Cache.get!TagObject(tagIndex);
    const tagCollision    = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);
    const tagDamageEffect = Cache.get!TagDamageEffect(options.tagIndex);

    bool doDamage = true;

    if(flags.hidden)
    {
        doDamage = false;
    }
    else
    {
        World.LineResult  lineResult = void;
        World.LineOptions lineOptions;

        lineOptions.surface.frontFacing = true;
        lineOptions.structure           = true;

        Vec3 direction = bound.center - options.center;

        if(!isUnit() || tagDamageEffect.aoeCoreRadius < 0.0001f)
        {
            if(world.collideLine(null, options.center, direction, lineOptions, lineResult))
            {
                doDamage = false;
            }
        }
        else
        {
            Vec3 perp = anyPerpendicularTo(direction);
            Vec3 left = cross(direction, perp);

            normalize(perp);
            normalize(left);

            bool blocked = true;

            foreach(i ; 0 .. 4)
            {
                Vec3 segment;

                switch(i)
                {
                case 0: segment =  tagDamageEffect.aoeCoreRadius * perp; break;
                case 1: segment = -tagDamageEffect.aoeCoreRadius * perp; break;
                case 2: segment =  tagDamageEffect.aoeCoreRadius * left; break;
                case 3: segment = -tagDamageEffect.aoeCoreRadius * left; break;
                default: assert(0);
                }

                world.collideLine(null, options.center, segment, lineOptions, lineResult);

                if(!world.collideLine(null, lineResult.point, bound.center - lineResult.point, lineOptions, lineResult))
                {
                    blocked = false;
                    break;
                }
            }

            if(blocked)
            {
                doDamage = false;
            }
        }
    }

    if(tagDamageEffect.damageFlags.doesNotHurtOwner)
    {
        if(&this is options.instigatorObject)
        {
            doDamage = false;
        }
    }

    // TODO does not hurt friends
    // TODO infection form pop
    // TODO unit flag, inconsequential

    options.flags.areaOfEffect = true;

    if(doDamage)
    {
        options.direction = bound.center - options.center;
        float distance = options.direction.normalize();

        const float deltaRadius = tagDamageEffect.radius.upper - tagDamageEffect.radius.lower;
        float scale = 1.0f;

        if(!tagDamageEffect.flags.dontScaleDamageByDistance)
        {
            if(deltaRadius > 0.0f)
            {
                scale = saturate(1.0f - (distance - tagDamageEffect.radius.lower) / deltaRadius);
            }
        }

        options.scale = scale;

        if(scale > 0.0f)
        {
            dealDamage(options, indexNone, indexNone, indexNone);
        }

        if(tagCollision.flags.passesAreaDamageToChildren)
        {
            if(firstChildObject)
            {
                firstChildObject.dealAreaDamage(options, true);
            }
        }
    }

    // TODO infection form pop related

    if(doSiblings)
    {
        for(GObject* next = nextSiblingObject; next; next = next.nextSiblingObject)
        {
            next.dealAreaDamage(options, false);
        }
    }
}

float getFunctionValue(TagEnums.FunctionScaleBy value) const
{
    switch(value)
    {
    case TagEnums.FunctionScaleBy.aIn:  return importFunctionValues[0];
    case TagEnums.FunctionScaleBy.bIn:  return importFunctionValues[1];
    case TagEnums.FunctionScaleBy.cIn:  return importFunctionValues[2];
    case TagEnums.FunctionScaleBy.dIn:  return importFunctionValues[3];

    case TagEnums.FunctionScaleBy.aOut: return exportFunctionValues[0];
    case TagEnums.FunctionScaleBy.bOut: return exportFunctionValues[1];
    case TagEnums.FunctionScaleBy.cOut: return exportFunctionValues[2];
    case TagEnums.FunctionScaleBy.dOut: return exportFunctionValues[3];
    default:
    }

    return 0.0f;
}

void updateExportFunctions()
{
    const tagObject = Cache.get!TagObject(tagIndex);

    float time = world.getTickCounter() / float(gameFramesPerSecond);

    foreach(int i, ref tagFunction ; tagObject.functions)
    {
        float period = tagFunction.initialPeriod;

        if(tagFunction.scalePeriodBy != TagEnums.FunctionScaleBy.none)
        {
            float scale = getFunctionValue(tagFunction.scalePeriodBy);

            if(scale > 0.0f)
            {
                period *= scale;
            }
        }

        bool  valid = true;
        float value = evalTagFunctionWithTime(tagFunction.func, time * period);

        if(tagFunction.scaleFunctionBy != TagEnums.FunctionScaleBy.none)
        {
            value *= getFunctionValue(tagFunction.scaleFunctionBy);
        }

        if(tagFunction.flags.invert)
        {
            value = 1.0f - value;
        }

        if(tagFunction.wobbleMagnitude != 0.0f)
        {
            float wobble = evalTagFunctionWithTime(tagFunction.wobbleFunction, time * tagFunction.wobblePeriod);
            value += (wobble - 0.5f) * tagFunction.wobbleMagnitude * 2.0f;
        }

        if(tagFunction.squareWaveThreshold != 0.0f)
        {
            if(value <= tagFunction.squareWaveThreshold) value = 0.0f;
            else                                         value = 1.0f;
        }

        if(tagFunction.stepCount > 1)   value = floor(value * tagFunction.stepCount) * tagFunction.stepMultiplier;
        if(tagFunction.modulus != 0.0f) value %= tagFunction.modulus;

        if(tagFunction.add != TagEnums.FunctionScaleBy.none) value = min(1.0f, value + getFunctionValue(tagFunction.add));
        if(tagFunction.scaleResultBy != TagEnums.FunctionScaleBy.none) value *= getFunctionValue(tagFunction.scaleResultBy);

        value = evalTagMapToFunction(tagFunction.mapTo, value);

        if(tagFunction.scaleBy > 0.0f)
        {
            value *= tagFunction.scaleBy;
        }

        switch(tagFunction.boundsMode)
        {
        case TagEnums.BoundsMode.clip:
        case TagEnums.BoundsMode.clipAndNormalize:

            if(value <= tagFunction.bounds.lower + 0.0001f)
            {
                value = tagFunction.bounds.lower;
                valid = tagFunction.flags.alwaysActive;
            }

            if(value > tagFunction.bounds.upper)
            {
                value = tagFunction.bounds.upper;
            }

            if(tagFunction.boundsMode == TagEnums.BoundsMode.clipAndNormalize)
            {
                value = (value - tagFunction.bounds.lower) / tagFunction.boundsDelta;
            }

            break;
        case TagEnums.BoundsMode.scaleToFit:

            value = tagFunction.bounds.mix(value);

            if(value <= tagFunction.bounds.lower + 0.0001f)
            {
                valid = tagFunction.flags.alwaysActive;
            }
            break;
        default:
        }

        if(tagFunction.turnOffWith != indexNone)
        {
            if(!exportFunctionValidities[tagFunction.turnOffWith])
            {
                valid = false;
            }
        }

        if(tagFunction.flags.additive)
        {
            value = (exportFunctionValues[i] + value) % 1.0f;
        }

        exportFunctionValues[i]     = value;
        exportFunctionValidities[i] = valid;

    }
}

bool implUpdateImportFunctions()
{
    const tagObject = Cache.get!TagObject(tagIndex);

    foreach(i ; 0 .. TagConstants.Object.maxFunctions)
    {
        TagEnums.ObjectImport type;

        switch(i)
        {
        case 0: type = tagObject.aIn; break;
        case 1: type = tagObject.bIn; break;
        case 2: type = tagObject.cIn; break;
        case 3: type = tagObject.dIn; break;
        default: continue;
        }

        float value;

        switch(type) with(TagEnums.ObjectImport)
        {
        case bodyVitality:       value = damage.health;              break;
        case shieldVitality:     value = min(damage.shield, 1.0f);   break;
        case recentBodyDamage:   value = damage.healthDamageCurrent; break;
        case recentShieldDamage: value = damage.shieldDamageCurrent; break;
        case randomConstant:
            if(isNaN(importFunctionValues[i]))
            {
                value = randomPercent();
            }
            break;
        case region00Damage:
        case region01Damage:
        case region02Damage:
        case region03Damage:
        case region04Damage:
        case region05Damage:
        case region06Damage:
        case region07Damage:
            value = regionVitalities[type - region00Damage] / float(ubyte.max);
            break;
        case alive:
            if(damage.flags.healthDepleted) value = 0.0f;
            else                            value = 1.0f;
            break;
        case compass:
            Transform* transform = &transforms[0];
            if(abs(transform.forward.z) >= 0.995f)
            {
                value = importFunctionValues[i];
            }
            else
            {
                float localNorth = Cache.inst.scenario.localNorth;
                float angle      = atan2(transform.forward.y, transform.forward.x);
                float clamped    = (angle - localNorth) % M_2_PI;

                value = clamp(clamped / M_2_PI + 0.5f, 0.0f, 1.0f);
            }
            break;
        default: value = 0.0f;
        }

        importFunctionValues[i] = value;
    }

    return true;
}

bool collideObjectLine(Vec3 position, Vec3 segment, World.SurfaceOptions options, ref World.ObjectLineResult result)
{
    import Game.World.WorldLine : WorldLine;

    bool collision = false;
    result.percent = float.max;

    auto tagObject = Cache.get!TagObject(tagIndex);

    if(!tagObject.collisionModel)
    {
        return false;
    }

    auto tagCollision = Cache.get!TagModelCollisionGeometry(tagObject.collisionModel);

    foreach(int i, ref node ; tagCollision.nodes)
    {
        if(node.region == indexNone) continue;
        if(node.bsps.size == 0)      continue;

        int bspIndex = clamp(regionPermutationIndices[node.region], 0, node.bsps.size - 1);
        Tag.Bsp* bsp = node.bsps + bspIndex;

        Transform inverseTransform = inverse(transforms[i]);

        Vec3 p = inverseTransform * position;
        Vec3 s = inverseTransform.mat3 * (inverseTransform.scale * segment);

        WorldLine line = WorldLine(options, false, p, s, bsp, result.percent);

        if(line && line.percent < result.percent)
        {
            result.percent      = line.percent;
            result.surface      = line.surface;
            result.regionIndex  = node.region;
            result.nodeIndex    = i;
            result.bspIndex     = bspIndex;
            result.surfacePlane = bsp.planes[line.surface.planeIndex & int.max].plane;

            if(line.surface.materialIndex == indexNone)
            {
                result.materialType = TagEnums.MaterialType.invalid;
            }
            else
            {
                result.materialType = tagCollision.materials[line.surface.materialIndex].materialType;
            }

            collision = true;
        }
    }

    return collision;
}

bool implDebugUi()
{
    igSetNextTreeNodeOpen(true, ImGuiSetCond.FirstUseEver);
    if(igCollapsingHeader("Object"))
    {
        igText("%p", &this);

        igListBoxHeader("occupied clusters");
        foreach(ref node ; occupiedClusters[0 .. occupiedClustersCount])
        {
            igText("%d", node.cluster);
        }
        igListBoxFooter();

        igText(Cache.inst.metaAt(tagIndex).path);
        igText(enumName(type).ptr);

        igInputFloat("scale", &scale);
        igInputFloat3("position", position[]);

        if(igInputFloat3("rotation.forward", rotation.forward[]))
        {
            if(normalize(rotation.forward) == 0.0f)
            {
                rotation.forward = Vec3(1, 0, 0);
            }
        }

        if(igInputFloat3("rotation.up", rotation.up[]))
        {
            if(normalize(rotation.up) == 0.0f)
            {
                rotation.up = Vec3(1, 0, 0);
            }
        }

        igSeparator();
        igText("Lighting (desired)");
        igColorEdit3("ambient color", cachedLighting.desired.ambientColor[]);
        igColorEdit3("distant light 0 color", cachedLighting.desired.distantLight[0].color[]);
        igInputFloat3("distant light 0 vector", cachedLighting.desired.distantLight[0].direction[]);
        igColorEdit3("distant light 1 color", cachedLighting.desired.distantLight[1].color[]);
        igInputFloat3("distant light 1 vector", cachedLighting.desired.distantLight[1].direction[]);
        igColorEdit3("shadow color", cachedLighting.desired.shadowColor[]);
        igInputFloat3("shadow vector", cachedLighting.desired.shadowVector[]);
        igColorEdit3("reflection tint", cachedLighting.desired.reflectionTint.rgb[]);

        igSeparator();
        igDragFloat("health", &damage.health);
        igDragFloat("shield", &damage.shield);

    }


    return true;
}

}

private enum ByType
{
    doTopDown, // do ordering top down, eg GObject -> Unit -> Vehicle
    doBotUp,   // do ordering bottom up, eg Vehicle -> Unit -> Object
    doDerived, // do call only on derived type, eg Vehicle and nothing else
}

private
template makeCallByTypeError(string type)
{
    pragma(msg, __FILE__ ~ " Reminder: missing type for enum " ~ type);
    enum makeCallByTypeError = true;
}

private
bool makeCallByType(string func, ByType order = ByType.doTopDown, Args...)(ref inout GObject object, auto ref Args args)
{
    import std.ascii : toUpper;
    import std.meta  : AliasSeq, Reverse;

    enum declaresImplFunc(T) = declaresMember!(T, func);

    static
    bool callImpl(O, Types...)(ref inout GObject object, Args args)
    {
        static      if(order == ByType.doTopDown) alias List = Types;
        else static if(order == ByType.doBotUp)   alias List = Reverse!(Types);
        else static if(order == ByType.doDerived)
        {
            alias List = AliasSeq!(Types[$ - 1]);
            static assert(is(List[0] == O), "Call not made on derived type, got ("
                ~ List[0].stringof ~ ") but expect (" ~ O.stringof ~ ")");
        }
        else
        {
            static assert(0, "No call order defined.");
        }

        foreach(t ; List)
        {
            static if(is(ReturnType!(mixin("t." ~ func)) : void))
            {
                mixin("(cast(" ~ t.stringof ~ "*)&object)." ~ func ~ "(args);");
            }
            else
            {
                if(!mixin("(cast(" ~ t.stringof ~ "*)&object)." ~ func ~ "(args)"))
                {
                    return false;
                }
            }
        }

        return true;
    }

    template Expand(V)
    {
        enum parents = __traits(getAliasThis, V);
        static if(parents.length) alias Expand = AliasSeq!(Expand!(typeof(mixin("V." ~ parents[0]))), V);
        else                      alias Expand = V;
    }

    template strInit(T...)
    {
        static if(T.length == 0)
        {
            enum strInit = "";
        }
        else static if(T[0] == "invalid")
        {
            enum strInit = strInit!(T[1 .. $]);
        }
        else static if(mixin("is(" ~ toUpper(T[0][0]) ~ T[0][1..$] ~ " O)"))
        {
            static if(hasMember!(O, func))
            {
                enum strInit = "&callImpl!(" ~ O.stringof ~ ", Filter!(declaresImplFunc, Expand!"
                    ~ O.stringof ~ ")), " ~ strInit!(T[1 .. $]);
            }
            else
            {
                enum strInit = "null, " ~ strInit!(T[1 .. $]);
            }
        }
        else
        {
            static assert(makeCallByTypeError!(T[0]));
            enum strInit = "null, " ~ strInit!(T[1 .. $]);
        }
    }

    static immutable functionPtrs = mixin("[ " ~ strInit!(__traits(allMembers, TagEnums.ObjectType)) ~ " ]");

    if(auto result = functionPtrs[object.type])
    {
        return result(object, args);
    }

    return true;
}
