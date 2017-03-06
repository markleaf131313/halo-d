
module Game.World.Objects.Projectile;

import std.bitmanip : bitfields;

import Game.World.Objects.Object;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

private
{
    enum maxUpdateIterations = 10;

    immutable Tag.ProjectileMaterialResponseBlock defaultMaterialResponse =
    {
        skipFraction:          0.0f,
        angleBounds:           TagBounds!float(0.0f, 0.0f),
        velocityBounds:        TagBounds!float(0.0f, 0.0f),
        angularNoise:          0.0f,
        velocityNoise:         0.0f,
        initialFriction:       0.0f,
        maximumDistance:       0.0f,
        parallelFriction:      0.0f,
        perpendicularFriction: 0.0f,
    };

}

struct Projectile
{
@nogc nothrow:

struct Flags
{
    mixin(bitfields!(
        bool, "_bit0_x01_", 1,
        bool, "tracer",     1,
        bool, "_bit2_x04_", 1,
        bool, "attached",   1,
        bool, "startArming", 1,
        bool, "detonating", 1,
        bool, "_bit6_x40_", 1,
        bool, "_bit7_x80_", 1,
        uint, "", 8,
    ));
}

// NOTE: order matters, a lower value State can't be set over a higher value State
enum State
{
    idle,
    detonating,
    detonated,
}

alias object this;
GObject object;

Flags flags;
State state;

SheepGObjectPtr sourceObject; // prevent hitting this object, until projectile ricochets off something else.
SheepGObjectPtr targetObject; // guided homing target
                              // TODO make SheepGObjectPtr DatumIndex instead, See: Game.World.SheepGObjectPtr

float armingTimer = 0.0f;
float armingRate  = 0.0f;

float safetyTimer = 0.0f;
float safetyRate  = 0.0f;

// TODO better comments/names
float damageRangeTimer;
float damagePerVelocity; // (init^2 - final^2) / (2 * (upper - lower))
float damageRangeUpper;  // damage range (upper)
float damageRangeScale;  // initial velocity / damage range (lower)

bool implInitialize()
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    flags.tracer = true;

    // TODO sourceObject, taken from object and the absoluteParent() of (need to implement in object)

    const float safetyRate = tagProjectile.armingTime * gameFramesPerSecond;

    if(safetyRate >= 1.0f)
    {
        this.safetyRate = safetyRate;
    }

    // TODO timer
    // TODO arming timer
    // TODO contrail

    velocity += rotation.forward * tagProjectile.initialVelocity;

    // TODO initialize object.flags.inWater
    // TODO update rotation
    updateDamageRange();

    this.object.flags.doesNotCastShadow          = true;
    this.object.flags.deactivationCausesDeletion = true;

    return true;
}

bool implUpdateLogic()
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    damageRangeTimer += damageRangeScale;
    safetyTimer      += safetyTimer;

    if(!flags.tracer)
    {
        // TODO remove contrail
    }

    bool startDetonationTimer;

    switch(tagProjectile.detonationTimerStarts)
    {
    case TagEnums.DetonationTimer.afterFirstBounce:
    case TagEnums.DetonationTimer.whenAtRest:        startDetonationTimer = flags.startArming; break;
    default:                                         startDetonationTimer = true;              break;
    }

    if(flags.detonating || !flags.attached || startDetonationTimer)
    {
        flags.detonating = true;

        armingTimer += armingRate;

        if(armingTimer >= 1.0f)
        {
            setState(State.detonating);
        }
    }

    // TODO update import function values here, for some reason, hack?

    float percent   = 1.0f;
    int   iteration = 0;

    Vec3 position = this.position;
    Vec3 velocity = this.velocity;

    while(percent > 0.0f)
    {
        if(state == State.detonating)
        {
            if(safetyRate == 0.0f || safetyTimer >= 1.0f)
            {
                break;
            }
        }

        if(state == State.detonated || this.object.flags.atRest || parent !is null)
        {
            break;
        }

        float velocityLength = length(velocity);

        if(targetObject && tagProjectile.guidedAngularVelocity > 0.0f)
        {
            if(auto target = targetObject.ptr)
            {
                // TODO guiding projectile to target
            }
        }

        if(damageRangeTimer >= 1.0f)
        {
            // TODO
        }

        // TODO maximum range
        // TODO modify velocity, gravity, maximum distance traveled, final/inital speed, etc...

        float gravity = gameGravity;

        if(this.object.flags.inWater) gravity *= tagProjectile.waterGravityScale;
        else                          gravity *= tagProjectile.airGravityScale;

        velocity.z -= gravity;

        if(iteration >= maxUpdateIterations)
        {
            setState(State.detonating);
            percent = 0.0f;
            break;
        }
        else if(state == State.detonated)
        {
            percent = 0.0f;
            break;
        }

        World.LineResult collision = void;

        if(collideWorld(velocity * percent, collision))
        {
            iteration += 1;

            percent      = 1.0f - collision.percent;
            sourceObject = SheepGObjectPtr();

            if(percent < 0.0001f)
            {
                percent = 0.0f;
            }

            doImpact(position, velocity, collision);
        }
        else
        {
            percent = 0.0f;
            position += velocity; // TODO remove

            // TODO
        }

        if(tagProjectile.flybySound)
        {
            // TODO(SOUND) flyby sound for players
        }

        if(tagProjectile.flags.orientedAlongVelocity && velocity != Vec3(0.0f))
        {
            // TODO align with velocity
        }
        else if(flags._bit0_x01_)
        {
            // TODO rotate
        }

        disconnectFromWorld();

        this.position = position;
        this.velocity = velocity;

        connectToWorld(&collision.location);

        if(percent > 0.0f && iteration != 0)
        {
            // TODO add contrail point
        }
    }

    switch(state)
    {
    case State.detonating:
        if(safetyRate == 0.0f || safetyTimer >= 1.0f)
        {
            // TODO detonation
            requestDeletion();
        }
        break;
    case State.detonated:
        requestDeletion();
        break;
    default:
    }

    return true;
}

private void setState(State desired)
{
    if(state < desired)
    {
        state = desired;
    }
}

private void updateDamageRange()
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    TagBounds!float range = object.flags.inWater ? tagProjectile.waterDamageRange : tagProjectile.airDamageRange;

    damageRangeUpper = range.upper;
    damagePerVelocity = tagProjectile.getDamageRangePerVelocity(range.upper - range.lower);

    if(range.lower > 0.0f)
    {
        damageRangeScale = range.lower / tagProjectile.initialVelocity;
    }
    else
    {
        // todo
    }
}

private bool collideWorld(Vec3 segment, ref World.LineResult lineResult)
{
    World.LineOptions options;

    options.surface.frontFacing     = true;
    options.surface.ignoreInvisible = true;

    options.structure = true;
    options.water     = true;
    options.objects   = true;
    options.tryToKeepValidLocation = true;

    if(world.collideLine(sourceObject.ptr, position, segment, options, lineResult))
    {
        return true;
    }

    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    if(tagProjectile.collisionRadius >= 0.0001f)
    {
        Vec3 offset = cross(segment, Vec3(0, 0, 1));

        if(normalize(offset) == 0.0f)
        {
            offset = Vec3(0, 1, 0);
        }

        offset *= tagProjectile.collisionRadius;

        options.tryToKeepValidLocation = false;

        if(world.collideLine(sourceObject.ptr, position + offset, segment, options, lineResult)) return true;
        if(world.collideLine(sourceObject.ptr, position - offset, segment, options, lineResult)) return true;
    }

    return false;
}

private void doImpact(ref Vec3 position, ref Vec3 velocity, ref World.LineResult line)
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    Vec3  direction = velocity;
    float speed     = normalize(direction);

    if(speed == 0.0f)
    {
        direction = Vec3(0, 0, 1);
    }

    float throttle;

    if(tagProjectile.initialVelocity == tagProjectile.finalVelocity)
    {
        throttle = 1.0f;
    }
    else
    {
        float diff = tagProjectile.initialVelocity - tagProjectile.finalVelocity;
        throttle = saturate((speed - tagProjectile.finalVelocity) / diff);
    }

    auto materialType = line.materialType;

    if(line.collisionType == World.CollisionType.object && tagProjectile.impactDamage)
    {
        GObject.DamageOptions options =
        {
            // TODO flags
            // TODO instigator
            tagIndex:  tagProjectile.impactDamage.index,
            center:    position,
            position:  position,
            direction: velocity,
            scale:     throttle,
        };

        normalize(options.direction);

        line.model.object.dealDamage(options, line.model.nodeIndex, line.model.regionIndex, line.materialType);

        if(options.material != TagEnums.MaterialType.invalid)
        {
            materialType = options.material;
        }

        // TODO use damage amount as scale for effect below (need to add to DamageOptions)
    }

    const(Tag.ProjectileMaterialResponseBlock)* tagResponse = &defaultMaterialResponse;

    if(tagProjectile.materialResponses.inBounds(materialType))
    {
        tagResponse = &tagProjectile.materialResponses[materialType];
    }

    TagEnums.MaterialResponse responseType   = tagResponse.defaultResponse;
    DatumIndex                responseEffect = tagResponse.defaultEffect.index;

    const float angle    = randomNoise(tagResponse.angularNoise)  + angleBetween(line.plane.normal, velocity) - PI_2;
    const float hitSpeed = randomNoise(tagResponse.velocityNoise) - dot(line.plane.normal, velocity);

    if(tagResponse.potentialResponse != TagEnums.MaterialResponse.disappear)
    {
        if(tagResponse.angleBounds.upper    == 0.0f || tagResponse.angleBounds.inBounds!"[]"(angle))
        if(tagResponse.velocityBounds.upper == 0.0f || tagResponse.velocityBounds.inBounds!"[]"(hitSpeed))
        {
            responseType   = tagResponse.potentialResponse;
            responseEffect = tagResponse.potentialEffect.index;
        }
    }

    if(line.collisionType == World.CollisionType.structure && line.surface.flags.breakable)
    {
        // TODO breakable surfaces
    }

    position = line.point;

    switch(responseType)
    {
    default:
        velocity = Vec3(0.0f);
        break;
    case TagEnums.MaterialResponse.overpenetrate:
        switch(line.collisionType)
        {
        case World.CollisionType.water:
            object.flags.inWater = !object.flags.inWater;
            updateDamageRange();
            position -= line.plane.normal * 0.001f;
            break;
        case World.CollisionType.object:
            velocity *= 1.0f - tagResponse.initialFriction;
            sourceObject = line.model.object.selfPtr;
            break;
        default:
            if(tagProjectile.timer.upper == 0.0f)
            {
                responseType = TagEnums.MaterialResponse.detonate;
            }
            else
            {
                responseType = TagEnums.MaterialResponse.attach;
                flags._bit2_x04_ = true;
                flags.startArming = true;
            }

            velocity = Vec3(0.0f);
        }
        break;
    case TagEnums.MaterialResponse.reflect:
        Vec3 perp;
        Vec3 parallel;
        reflectVectors(line.plane.normal, velocity, perp, parallel);

        velocity = (1.0f - tagResponse.parallelFriction) * parallel - (1.0f - tagResponse.perpendicularFriction) * perp;
        break;
    }

    if(tagResponse.angularNoise != 0.0f)
    {
        velocity = randomRotatedVector(velocity, TagBounds!float(0.0f, tagResponse.angularNoise));
    }

    if(tagResponse.velocityNoise != 0.0f)
    {
        float len = normalize(velocity);

        if(len != 0.0f)
        {
            velocity *= len + randomNoise(tagResponse.velocityNoise);
        }
    }

    const float velocityLengthSqr = lengthSqr(velocity);

    if(responseType != TagEnums.MaterialResponse.attach)
    {
        if(velocityLengthSqr < sqr(tagProjectile.minimumVelocity))
        {
            setState(State.detonating);
        }
    }

    if(velocityLengthSqr < 0.0001f)
    {
        flags.startArming = true;

        if(line.plane.normal.z > 0.3f)
        {
            this.object.flags.atRest = true;

            if(tagProjectile.timer.upper == 0.0f)
            {
                setState(State.detonating);
            }
        }
    }

    float effectScale = 1.0f;

    switch(tagResponse.scaleEffectsBy)
    {
    case TagEnums.ScaleEffectBy.damage: effectScale = saturate(throttle);       break;
    case TagEnums.ScaleEffectBy.angle:  effectScale = saturate(angle * M_2_PI); break;
    default:
    }

    World.EffectMarker[5] effectMarkers =
    [
        { "normal",            line.point, line.plane.normal                    },
        { "incident",          line.point, velocity                             },
        { "negative incident", line.point, -velocity                            },
        { "reflection",        line.point, reflect(line.plane.normal, velocity) },
        { "gravity",           line.point, Vec3(0.0f, 0.0f, -1.0f)              },
    ];

    if(hitSpeed > 1.0f / (4 * gameFramesPerSecond))
    {
        // TODO scaleA/scaleB for the following effect creations
        if(line.collisionType == World.CollisionType.object)
        {
            world.createEffect(responseEffect, &this.object, line.model.object, line.model.nodeIndex,
                effectMarkers, velocity, effectScale, 0.0f);
        }
        else
        {
            world.createEffect(responseEffect, &this.object, effectMarkers, velocity, effectScale, 0.0f);
        }
    }

    if(!flags.detonating && (flags.startArming || responseType == TagEnums.MaterialResponse.attach))
    {
        DatumIndex detonationEffect = tagProjectile.detonationStarted.index;

        // TODO scaleA/scaleB for the following effect creations
        if(line.collisionType == World.CollisionType.object)
        {
            world.createEffect(detonationEffect, &this.object, line.model.object, line.model.nodeIndex,
                effectMarkers, velocity, effectScale, 0.0f);
        }
        else
        {
            world.createEffect(detonationEffect, &this.object, effectMarkers, velocity, effectScale, 0.0f);
        }
    }

    switch(responseType)
    {
    case TagEnums.MaterialResponse.disappear:
        setState(State.detonated);
        break;
    case TagEnums.MaterialResponse.detonate:
        setState(State.detonating);
        break;
    case TagEnums.MaterialResponse.attach:
        // TODO attach to object
        break;
    default:
    }
}

}
