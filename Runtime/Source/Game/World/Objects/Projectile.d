
module Game.World.Objects.Projectile;

import std.bitmanip : bitfields;

import Game.World.Objects.Object;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Projectile
{

struct Flags
{
    mixin(bitfields!(
        bool, "_bit0_x01_", 1,
        bool, "_bit1_x02_", 1,
        bool, "_bit2_x04_", 1,
        bool, "_bit3_x08_", 1,
        bool, "_bit4_x10_", 1,
        bool, "_bit5_x20_", 1,
        bool, "_bit6_x40_", 1,
        bool, "_bit7_x80_", 1,
        uint, "", 8,
    ));
}

enum State
{
    idle,
    timing,
    detonated,
}

alias object this;
GObject object;

Flags flags;
State state;

GObject* sourceObject;
GObject* targetObject;

bool implUpdateLogic()
{
    const tagProjectile = Cache.get!TagProjectile(tagIndex);

    // TODO update import function values here, for some reason, hack?

    float percent = 1.0f;

    while(percent > 0.0f)
    {
        if(state == State.timing)
        {
            // TODO
        }

        if(state == State.detonated || parent !is null)
        {
            break;
        }

        if(targetObject !is null && tagProjectile.guidedAngularVelocity > 0.0f)
        {
            // TODO
        }


        World.LineResult collision = void;

        // if(collideWorld( , collision)) // TODO scale velocity
        // {
        //     doImpact(collision);
        // }

        assert(0);
    }

    return true;
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

private void doImpact(ref const World.LineResult lineResult)
{

}

}