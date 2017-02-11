
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
        between:               TagBounds!float(0.0f, 0.0f),
        and:                   TagBounds!float(0.0f, 0.0f),
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
        bool, "tracer", 1,
        bool, "_bit2_x04_", 1,
        bool, "_bit3_x08_", 1,
        bool, "_bit4_x10_", 1,
        bool, "_bit5_x20_", 1,
        bool, "_bit6_x40_", 1,
        bool, "_bit7_x80_", 1,
        uint, "", 8,
    ));
}

// NOTE: order matters, a lower value State can't be set over a higher value State
enum State
{
    idle,
    arming,
    detonated,
}

alias object this;
GObject object;

Flags flags;
State state;

GObject* sourceObject; // prevent hitting this object, until projectile ricochets off something else.
GObject* targetObject; // guided homing target

bool implUpdateLogic()
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    // TODO update import function values here, for some reason, hack?

    float percent   = 1.0f;
    int   iteration = 0;

    while(percent > 0.0f)
    {
        if(state == State.arming)
        {
            // TODO values that determine if this loop is run
        }

        // TODO don't run if at rest
        if(state == State.detonated || parent !is null)
        {
            break;
        }

        float velocityLength = length(velocity);

        if(targetObject !is null && tagProjectile.guidedAngularVelocity > 0.0f)
        {
            // TODO guiding projectile to target
        }

        if(iteration == maxUpdateIterations)
        {
            setState(State.arming);
            percent = 0.0f;
            break;
        }
        else if(state == State.detonated)
        {
            percent = 0.0f;
            break;
        }

        // TODO modify velocity, gravity, maximum distance traveled, final/inital speed, etc...

        // World.LineResult collision = void;

        // if(collideWorld(, collision))
        // {
        //     percent = 1.0f - collision.percent;
        //     doImpact(, collision);
        // }
        // else
        // {
        //     percent = 0.0f;
        // }

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


        // disconnectFromMap();
        // TODO
        // connectToMap();

        if(percent != 0.0f && iteration != 0)
        {
            // TODO add contrail point
        }

        assert(0);
    }

    assert(0);

    return true;
}

private void setState(State desired)
{
    if(state < desired)
    {
        state = desired;
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

    if(world.collideLine(sourceObject, position, segment, options, lineResult))
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

        if(world.collideLine(sourceObject, position + offset, segment, options, lineResult)) return true;
        if(world.collideLine(sourceObject, position - offset, segment, options, lineResult)) return true;
    }

    return false;
}

private void doImpact(ref Vec3 velocity, ref const World.LineResult line)
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
        // TODO create damage effect
        // TODO set material type from damage effect result
    }

    const(Tag.ProjectileMaterialResponseBlock)* response = &defaultMaterialResponse;

    if(tagProjectile.materialResponses.inBounds(materialType))
    {
        response = &tagProjectile.materialResponses[materialType];
    }

    // TODO check to see if we use the "potential" material reponse
    auto       responseType   = response.defaultResponse;
    DatumIndex responseEffect = response.defaultEffect.index;

    if(response.potentialResponse != TagEnums.MaterialResponse.disappear)
    {
        // TODO potential response
    }

    if(line.collisionType == World.CollisionType.structure && line.surface.flags.breakable)
    {
        // TODO breakable surfaces
    }

    switch(responseType)
    {
    default:
        // TODO
        break;
    case TagEnums.MaterialResponse.overpenetrate:
        // TODO
        break;
    case TagEnums.MaterialResponse.reflect:
        // TODO
        break;
    }

    if(response.angularNoise != 0.0f)
    {
        // TODO angular noise
    }

    if(response.velocityNoise != 0.0f)
    {
        // TODO velocity noise
    }

    // TODO minimum velocity
    // TODO scale effect by damage/angle
    // TODO create reponseEffect
    // TODO detonation started effect

    switch(responseType)
    {
    case TagEnums.MaterialResponse.disappear:
        setState(State.detonated);
        break;
    case TagEnums.MaterialResponse.detonate:
        setState(State.arming);
        break;
    case TagEnums.MaterialResponse.attach:
        // TODO attach to object
        break;
    default:
    }
}

}