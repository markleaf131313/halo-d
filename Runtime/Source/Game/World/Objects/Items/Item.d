
module Game.World.Objects.Items.Item;

import Game.World.Objects.Object;
import Game.World.Objects.Units.Unit;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Item
{

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "resting",                1,
        bool, "inUnitInventory",        1,
        bool, "hiddenInUnitInventory",  1,
        bool, "collidedWithBsp",        1,
        bool, "collidedWithObject",     1,
        bool, "rotating",               1,
        int, "", 2
    ));

}

alias object this;
GObject object;

Flags flags;

Unit* droppedByUnit;

bool implUpdateLogic()
{
    const tagItem  = Cache.get!TagItem(tagIndex);
    const tagModel = Cache.get!TagGbxmodel(tagItem.model);

    if(parent is null)
    {
        if(tagItem.flags.alwaysMaintainsZUp)
        {
            // TODO(IMPLEMENT) z up
        }

        if(flags.resting)
        {
            // TODO some calculations
        }
        else
        {
            if(!tagItem.flags.unaffectedByGravity)
            {
                velocity.z -= gameGravity;
            }

            World.LineResult result = void;
            World.LineOptions options;

            options.structure = true;

            if(world.collideLine(&this.object, position, velocity, options, result))
            {
                // TODO(IMPLEMENT) some normal calculat for material effect

                if(tagItem.materialEffects)
                {
                    // TODO(IMPLEMENT) material effects
                }

                if(tagItem.collisionSound)
                {
                    // TODO(IMPLEMENT, SOUND) collision sound
                }

                if(result.plane.normal.z > SQRT1_2 && -dot(result.plane.normal, velocity) <= 0.05f)
                {
                    // place on surface

                    GObject.MarkerTransform marker;

                    if(tagModel && findMarkerTransform("ground point", marker))
                    {
                        Vec3 forward;

                        if(1.0f - abs(dot(result.plane.normal, marker.world.forward)) < 0.01f)
                        {
                            forward = cross(marker.world.left, result.plane.normal);
                            forward = cross(cross(result.plane.normal, forward), result.plane.normal);
                        }
                        else
                        {
                            forward = cross(cross(result.plane.normal, marker.world.forward), result.plane.normal);
                        }

                        normalize(forward);

                        Transform desired = Transform(Mat3.fromPerpUnitVectors(forward, result.plane.normal), result.point);
                        Transform object  = inverse(Transform(rotation.toMat3(), position));

                        Transform calc = desired * inverse(object * marker.world);

                        rotation.forward = calc.forward;
                        rotation.up      = calc.up;
                        position         = calc.position;
                    }

                    flags.resting = true; // TODO temporary to stop movement, replace with object flags
                    velocity = Vec3(0);
                }
                else
                {
                    // bound off surface

                    Vec3 temp = velocity * result.plane.normal;
                    float extra = -(temp.x * 1.4f) - (temp.y * 1.4f) - (temp.z * 1.4f);

                    velocity += result.plane.normal * extra;

                    position = result.point;
                }
            }
            else
            {
                position += velocity;
            }
        }
    }

    // TODO(IMPLEMENT) detonation of item

    return true;
}

}