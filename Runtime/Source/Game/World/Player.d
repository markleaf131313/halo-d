
module Game.World.Player;

import Game.World.Objects;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Player
{
    struct LocalControl
    {
        Biped* biped;
        // Vec2 aimingAngles;

        int weaponIndex  = indexNone;
        int grenadeIndex = indexNone;
    }

    struct Action
    {
        // NOTE: order matters!
        enum Type
        {
            none,
            pickupPowerup,
            swapPowerup,
            exitSeat,
            swapEquipment,
            swapWeapon,
            pickupWeapon,
            enterSeat,
            touchDevice,
            flipVehicle,
        }

        Type     type;
        GObject* object;
        int      seatIndex;
    }

    Biped* biped;
    Action  action;
    bool    weaponSwapHandled;

    bool processVehicleAction()
    {
        bool result = false;

        if(action.type == Action.Type.enterSeat)
        {
            result = biped.enterSeat(cast(Unit*)action.object, action.seatIndex);
        }

        return result;
    }

    bool processWeaponAction()
    {
        switch(action.type)
        {
        default: return false;
        case Action.Type.swapWeapon:
        {
            auto weapon = cast(Weapon*)action.object;

            if(biped.throwAwayCurrentWeapon() && biped.pickupWeapon(weapon))
            {
                // todo hud message picked up
            }

            return true;
        }
        case Action.Type.pickupWeapon:
        {
            if(biped.pickupWeapon(cast(Weapon*)action.object))
            {
                // todo hud message pickup
            }

            return true;
        }
        }
    }

    void setAction(Action desired)
    {
        if(desired.type > action.type)
        {
            action = desired;
        }
        else if(desired.type == action.type)
        {
            float actionDistanceSqr  = lengthSqr(action.object.position  - biped.position);
            float desiredDistanceSqr = lengthSqr(desired.object.position - biped.position);

            if(desiredDistanceSqr < actionDistanceSqr)
            {
                action = desired;
            }
        }
    }

    void requestVehicleAction(Vehicle* vehicle)
    {
        const tagVehicle = Cache.get!TagVehicle(vehicle.tagIndex);
        const tagBiped   = Cache.get!TagBiped(biped.tagIndex);
        const tagModel   = Cache.get!TagGbxmodel(tagBiped.model);

        if(Cache.inst.globals.playerControl.minimumAngleForVehicleFlipping >= vehicle.rotation.up.z)
        {
            if(vehicle.poweredSeats[0].rider is null && !vehicle.flags.flipping)
            {
                Action action = { Action.Type.flipVehicle, &vehicle.object, indexNone };
                setAction(action);
            }
        }
        else
        {
            static struct Best
            {
                float distance = float.max;
                int   seat     = indexNone;
                bool  driver   = false;
            }

            Best best;

            Orientation[TagConstants.Animation.maxNodes] orientations;

            foreach(i, ref seat ; tagVehicle.seats)
            {
                const(char)[] seatLabel = seat.label;

                if(!seatLabel.length) continue;
                if(seat.flags.notValidWithoutDriver && vehicle.poweredSeats[0].rider is null) continue;

                if(auto enterAnimation = biped.getSeatEnterAnimation(seatLabel))
                {
                    if(!enterAnimation.decodeBase(0, orientations.ptr))
                    {
                        tagModel.copyDefaultOrientation(orientations.ptr);
                    }

                    GObject.MarkerTransform seatMarker = void;
                    vehicle.findMarkerTransform(seat.markerName, seatMarker);

                    Vec3 enterAnimationPosition = (seatMarker.world * Transform(orientations[0])).position;
                    Vec3 seatPosition = seatMarker.world.position;

                    float distanceSqr = min(
                        lengthSqr(biped.bound.center - seatPosition),
                        lengthSqr(biped.bound.center - enterAnimationPosition));

                    if(distanceSqr > TagConstants.Player.minEnterSeatDistanceSqr) continue;
                    if(!biped.seatExists(seatLabel, null))                        continue;
                    if(vehicle.checkSeatOccupied(i))                              continue;

                    float advantage = best.driver && !seat.flags.driver
                        ? TagConstants.Player.driverAdvantageMultiplier
                        : 1.0f;

                    if(best.seat == indexNone || distanceSqr * advantage < best.distance)
                    {
                        best.distance = distanceSqr;
                        best.seat     = i;
                        best.driver   = seat.flags.driver;
                    }
                }
            }

            if(best.seat != indexNone)
            {
                setAction(Action(Action.Type.enterSeat, &vehicle.object, best.seat));
            }
        }
    }

    void handleItemInProximity(Item* item)
    {
        if(biped is null)                     return;
        if(&biped.unit == item.droppedByUnit) return;

        foreach(Weapon* weapon ; biped.weapons)
        {
            if(weapon && weapon.attemptConsumeAmmo(item))
            {
                // todo player picked up ammo message ?
                break;
            }
        }

        if(item.type == TagEnums.ObjectType.equipment)
        {
            const tagEquipment = Cache.get!TagEquipment(item.tagIndex);

            switch(tagEquipment.powerupType)
            {
            // todo other equipment types
            case TagEnums.EquipmentType.grenade:
            {
                //todo pickup grenade
                break;
            }
            default:
            }
        }
        else if(item.type == TagEnums.ObjectType.weapon)
        {
            auto  pickupWeapon = cast(Weapon*)item;
            const tagPickupWeapon = Cache.get!TagWeapon(pickupWeapon.tagIndex);

            if(biped.weaponSeatExists(pickupWeapon))
            {
                int  countedWeapons = biped.countHeldWeapons();
                bool triggerPressed = biped.control.primaryTrigger || biped.control.secondaryTrigger;
                bool canPickup      = true;

                auto currentWeapon = biped.currentWeapon();

                // we cannot pickup the weapon if it counts toward maximum and the current weapon doesn't
                // that would mean we'd be over the counted held weapon limit

                if(countedWeapons >= TagConstants.Unit.maxCountedHeldWeapons)
                {
                    if(!tagPickupWeapon.flags.doesntCountTowardMaximum && currentWeapon)
                    {
                        const tagWeapon = Cache.get!TagWeapon(currentWeapon.tagIndex);

                        if(tagWeapon.flags.doesntCountTowardMaximum)
                        {
                            canPickup = false;
                        }
                    }
                }

                if(!triggerPressed || !tagPickupWeapon.flags.mustBeReadied)
                {
                    if(biped.shouldPickupWeaponInstantly(pickupWeapon))
                    {
                        if(biped.pickupWeapon(pickupWeapon))
                        {
                            // todo hud messages
                        }
                    }
                    else if(canPickup && biped.canPickupWeapon(pickupWeapon))
                    {
                        if(countedWeapons < TagConstants.Unit.maxCountedHeldWeapons
                            && (currentWeapon && currentWeapon.tagIndex != pickupWeapon.tagIndex))
                        {
                            Action action = { Action.Type.pickupWeapon, &pickupWeapon.object, indexNone };
                            setAction(action);
                        }
                        else
                        {
                            Action action = { Action.Type.swapWeapon, &pickupWeapon.object, indexNone };
                            setAction(action);
                        }
                    }
                }
            }
        }
    }


}