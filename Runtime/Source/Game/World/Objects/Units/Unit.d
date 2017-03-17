
module Game.World.Units.Unit;

import Game.World.FirstPerson;
import Game.World.Objects;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

private immutable const(char)[][] unitSeatStateNames = [ "asleep", "alert", "crouch", "stand", "flee", "flaming" ];

struct Unit
{
@nogc nothrow:

@disable this(this);
alias object this;

alias AnimationController = GObject.AnimationController;

enum State
{
    idle,

    turnLeft,
    turnRight,

    moveFront,
    moveBack,
    moveLeft,
    moveRight,

    stunnedFront,
    stunnedBack,
    stunnedLeft,
    stunnedRight,

    airborne,

    airborneDead,
    landingDead,

    entering,
    exiting,

    throwingGrenade,

    none = indexNone,
}

enum ReplacementState
{
    disarm,
    weaponDrop,
    weaponReady,
    weaponPutAway,
    weaponReload1,
    weaponReload2,
    weaponMelee,
    throwGrenade,
    overheat,

    none = indexNone,
}

// order matters, it determines if one OverlayState can override another
enum OverlayState
{
    fire1,
    fire2,
    charged1,
    charged2,
    chamber1,
    chamber2,

    none = indexNone,
}

enum BaseSeat
{
    asleep,
    alert,
    crouch,
    stand,
    flee,
    flaming,

    none = indexNone,
}

enum GrenadeState
{
    idle,
    begin,
    holding,
    thrown,
}

struct Control
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "crouch",           1,
        bool, "jump",             1,
        bool, "light",            1,
        bool, "melee",            1,
        bool, "reload",           1,
        bool, "action",           1,
        bool, "primaryTrigger",   1,
        bool, "secondaryTrigger", 1,
        bool, "swapWeapon",       1,
        ushort, "", 7
    ));
}

struct Animation
{
@nogc nothrow:

    @disable this(this);

    struct Flags
    {
        bool hasSeatAcceleration; // todo make bitfield
    }

    Flags flags;

    AnimationController replacement;
    AnimationController overlay;

    State state;
    ReplacementState replacementState;
    OverlayState overlayState;
    BaseSeat baseSeat;
    BaseSeat desiredBaseSeat;

    int unitIndex           = indexNone;
    int unitWeaponIndex     = indexNone;
    int unitWeaponTypeIndex = indexNone;

    int weaponAimAnimation  = indexNone;
    int headAimAnimation    = indexNone;

    inout(Tag.AnimationGraphUnitSeatBlock)* unitSeat(inout(TagModelAnimations)* anim)
    {
        return &anim.units[unitIndex];
    }

    inout(Tag.AnimationGraphWeaponBlock)* unitWeapon(inout(TagModelAnimations)* anim)
    {
        return &unitSeat(anim).weapons[unitWeaponIndex];
    }

    inout(Tag.AnimationGraphWeaponTypeBlock)* unitWeaponType(inout(TagModelAnimations)* anim)
    {
        return &unitWeapon(anim).weaponTypes[unitWeaponTypeIndex];
    }
}

struct PoweredSeat
{
    Unit* rider;
    float  power = 0.0f;
}

struct AimVectors
{
    Vec3 direction;
    Vec3 desired;
    Vec3 velocity;
}

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "impervious", 1,
        uint, "", 7,
    ));
}

GObject object;

Flags flags;

DatumIndex controllingPlayerIndex;

Control control;
Animation animation;

int currentWeaponIndex     = indexNone;
int nextWeaponIndex        = indexNone;
int enteredParentSeatIndex = indexNone;

GrenadeState grenadeState;
int          grenadeTime;
int          grenadeThrowTime;
Projectile*  heldGrenade;

int currentGrenadeIndex = indexNone;
int nextGrenadeIndex    = indexNone;

int[TagConstants.Unit.maxGrenadeTypes] grenades;

ubyte aimingChange; // TODO(IMPLEMENT)

Weapon*[TagConstants.Unit.maxHeldWeapons]      weapons;
PoweredSeat[TagConstants.Unit.maxPoweredSeats] poweredSeats;

Vec3 throttle                = 0.0f;
Vec3 desiredForwardDirection = Vec3(1, 0, 0);

float mouthAperture; // TODO(IMPLEMENT)

AimVectors aim;
AimVectors look;

bool implInitialize()
{
    auto tagUnit = Cache.get!TagUnit(tagIndex);

    if(!tagUnit.animationGraph)
    {
        return false;
    }

    desiredForwardDirection = rotation.forward;

    look.desired   = rotation.forward;
    look.direction = rotation.forward;

    aim.desired   = rotation.forward;
    aim.direction = rotation.forward;

    setSeat(unitSeatStateNames[BaseSeat.stand], null);

    if(tagUnit.weapons)
    {
        GObject.Creation data;

        data.tagIndex = tagUnit.weapons[0].weapon.index;
        data.regionPermutation = 0;

        // todo pickup weapon
    }

    return true;
}

bool implUpdateLogic()
{
    auto tagUnit       = Cache.get!TagUnit(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    if(!tagUnit.flags.simpleCreature)
    {
        if(auto driver = poweredSeats[0].rider) // todo cehck object damage - body depleted flag
        {
            // todo set team from driver
            // todo player check for driver

            // todo copy throttle and direction from driver

            control.jump = driver.control.jump;

            desiredForwardDirection = driver.desiredForwardDirection;
            throttle = driver.throttle;
        }

        if(auto gunner = poweredSeats[1].rider) // todo cehck object damage - body depleted flag
        {
            // todo set team from gunner
            // todo player check for gunner

            // todo copy gunner aim and control flags

            aim.desired = gunner.aim.desired;
        }

        // todo camo powerup stuff
        // todo spectrum power up stuff (removed?)
        // todo unit stunned
        // todo feign death
    }

    if(!tagUnit.flags.hasNoAiming)
    {
        // todo check object damage state flag - ?

        if(nextWeaponIndex != currentWeaponIndex && nextWeaponIndex != indexNone)
        {
            if(auto unitWeapon = weapons[nextWeaponIndex])
            {
                auto tagWeapon = Cache.get!TagWeapon(unitWeapon.tagIndex);

                if(weaponSeatExists(tagWeapon.label))
                {
                    updateWeapons();
                }
            }
        }

        // todo grenade index - next != current

        // todo cheat infinite ammo

        // todo weapon zoom state

        if(tagUnit.aimingVelocityMaximum != 0.0f || tagUnit.aimingAccelerationMaximum != 0.0f)
        {
            // todo implement
        }
        else
        {
            // todo implement
        }

        // todo aim change byte


        if(tagUnit.lookingVelocityMaximum != 0.0f || tagUnit.lookingAccelerationMaximum != 0.0f)
        {
            // todo implement
        }
        else
        {
            // todo implement
        }

        switch(grenadeState)
        {
        case GrenadeState.idle:
            if(control.secondaryTrigger)
            {
                attemptGrenadeThrow();
            }
            break;
        case GrenadeState.begin:
            if(baseAnimation.frame >= 2)
            {
                beginGrenadeThrow();
            }
            break;
        case GrenadeState.holding:
            grenadeTime += 1;

            if(animation.state != State.throwingGrenade)
            {
                assert(0); // TODO throw grenade
            }
            break;
        case GrenadeState.thrown:
            if(animation.state != State.throwingGrenade && !control.secondaryTrigger)
            {
                grenadeState = GrenadeState.idle;
            }
            break;
        default:
        }

        if(auto weapon = currentWeapon())
        {
            Weapon.Control weaponControl;

            weaponControl.primaryTrigger   = control.primaryTrigger;
            weaponControl.secondaryTrigger = control.secondaryTrigger;
            weaponControl.reload           = control.reload;

            if(tagUnit.flags.integratedLightCntrlsWeapon)
            {
                // todo integrated light
            }

            // todo update weapon owner data

            weapon.control = weaponControl;
        }

        // todo melee related

        // todo speech related

        // todo light / nightvision related

    }

    if(!tagUnit.flags.simpleCreature)
    {
        // todo animation related flags

        foreach(i, ref tagPoweredSeat ; tagUnit.poweredSeats)
        {
            auto poweredSeat = &poweredSeats[i];

            bool powered = false;

            switch(i)
            {
            case 0: if(poweredSeat.rider)                                               powered = true; break;
            case 1: if(poweredSeat.rider && poweredSeat.rider != poweredSeats[0].rider) powered = true; break;
            default:
            }

            if(powered) // todo object damage flag - body depleted
            {
                float change = 1.0f / (gameFramesPerSecond * tagPoweredSeat.driverPowerupTime);
                poweredSeat.power = min(1.0f, poweredSeat.power + change);
            }
            else
            {
                float change = 1.0f / (gameFramesPerSecond * tagPoweredSeat.driverPowerdownTime);
                poweredSeat.power = max(0.0f, poweredSeat.power - change);
            }
        }
    }

    return true;
}

bool implUpdateMatrices()
{
    auto tagUnit = Cache.get!TagUnit(tagIndex);

    if(tagUnit.flags.simpleCreature || animation.unitIndex == indexNone)
    {
        return true;
    }

    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    auto tagUnitSeat   = animation.unitSeat(tagAnimations);
    auto tagUnitWeapon = animation.unitWeapon(tagAnimations);

    if(parent)
    {
        switch(animation.state)
        {
        // todo more states once they are implemented
        case State.entering:
        case State.exiting:
            break;
        default:
            foreach(ref ikPoint ; tagUnitSeat.ikPoints)
            {
                solveMarkerIk(&this, ikPoint.marker, parent, ikPoint.attachToMarker);
            }
            break;
        }
    }

    if(auto currentWeapon = currentWeapon())
    {
        static bool shouldDoIk(ref Unit unit)
        {
            // todo some sort of weapon ik animation state with frames/animation index

            switch(unit.animation.state)
            {
            case State.throwingGrenade: return false;
            default:                    return true;
            }
        }

        if(shouldDoIk(this))
        {
            foreach(ref ikPoint ; tagUnitWeapon.ikPoints)
            {
                solveMarkerIk(&this, ikPoint.marker, &currentWeapon.object, ikPoint.attachToMarker);
            }
        }
    }

    return true;
}

bool implUpdateImportFunctions()
{
    const tagUnit = Cache.get!TagUnit(tagIndex);

    foreach(i ; 0 .. TagConstants.Object.maxFunctions)
    {
        TagEnums.UnitImport type;

        switch(i)
        {
        case 0: type = tagUnit.aIn; break;
        case 1: type = tagUnit.bIn; break;
        case 2: type = tagUnit.cIn; break;
        case 3: type = tagUnit.dIn; break;
        default: continue;
        }

        float value = 0.0f;

        switch(type)
        {
        case TagEnums.UnitImport.driverSeatPower: value = poweredSeats[0].power; break;
        case TagEnums.UnitImport.gunnerSeatPower: value = poweredSeats[1].power; break;
        case TagEnums.UnitImport.aimingChange:    value = aimingChange / float(ubyte.max); break;
        case TagEnums.UnitImport.mouthAperture:   value = mouthAperture; break;
        case TagEnums.UnitImport.integratedLightPower:
            break;
        case TagEnums.UnitImport.canBlink:
            // TODO(IMPLEMENT)
            break;
        case TagEnums.UnitImport.shieldSapping:
            // TODO(IMPLEMENT)
            break;
        default: value = 0.0f;
        }

        importFunctionValues[i] = value;
    }

    return true;
}

void incrementFrames(State desiredState)
{
    auto tagUnit       = Cache.get!TagUnit(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    bool forceState = false;

    if(parent)
    {
        // todo vehicle stuff
    }
    else
    {
        // todo change unit state

        // todo force crouch state if no room for stand in check

        ////////////////////////////////////////
        // todo need to fix this not implemented correctly
        ///////////////////////////////////////

        auto desired = control.crouch ? BaseSeat.crouch : BaseSeat.stand;

        if(desired != animation.baseSeat)
        {
            // todo rework implementation there are more states
            setSeat(control.crouch ? "crouch" : "stand", getWeaponLabel());
        }

        // update animation state if unit change state

    }

    if(baseAnimation)
    {
        switch(baseAnimation.increment(tagAnimations))
        {
        case AnimationController.State.key:
            // todo grenade throw related
            // todo all melee realted
            break;
        case AnimationController.State.end:
            switch(animation.state)
            {
            case State.landingDead:
                auto biped = isBiped;

                if(tagUnit.flags.destroyedAfterDying)
                {
                    const tagBiped = cast(const(TagBiped)*)tagUnit;

                    if(this.object.flags.atRest || biped && (!biped.flags.airborne || !tagBiped.flags.hasNoDyingAirborne))
                    {
                        // TODO destroy + spawned actors
                        requestDeletion(); // TODO temporary
                    }
                }

                if(biped)
                {
                    // TODO set body limp
                }

                // TODO animation flag

                baseAnimation.frame -= 1;

                break;
            case State.entering:
                break;
            case State.exiting:

                // todo implement

                disconnectFromWorld();

                auto unit = cast(Unit*)parent;

                foreach(ref seat ; unit.poweredSeats)
                {
                    if(seat.rider is &this)
                    {
                        seat.rider = null;
                    }
                }

                parent = null;
                enteredParentSeatIndex = indexNone;

                position = transforms[0].position + Vec3(0, 0, 0.2f);
                animation.baseSeat = BaseSeat.none;

                updateHierarchyMatrices();

                connectToWorld();

                break;
            default:
            }

            // todo forceState of certain animation states that end

            switch(animation.state)
            {
            case State.entering:
            case State.exiting:
                forceState = true;
                break;
            default:
            }
            break;
        default:
        }
    }

    if(animation.replacement)
    {
        switch(animation.replacement.increment(tagAnimations))
        {
        case AnimationController.State.end:

            interpolateCurrent(6);

            animation.replacement.animationIndex = indexNone;
            animation.replacementState = ReplacementState.none;

            break;
        default:
        }
    }

    if(animation.overlay)
    {
        switch(animation.overlay.increment(tagAnimations))
        {
        case AnimationController.State.end:
        case AnimationController.State.loop:

            // todo loop if state == turnleft/movefront (potentially a bug?)

            animation.overlay.animationIndex = indexNone;
            animation.overlayState = OverlayState.none;

            break;
        default:
        }
    }

    immutable auto canEnterState = (State current, State desired)
    {
        switch(current)
        {
        case State.exiting:
        case State.entering: return false;
        case State.turnLeft:
        case State.turnRight:
                // turnLeft/Right auto terminates, so prevent idle from changing state
            if(desired == State.idle) return false;
            return true;
        case State.landingDead:
        case State.airborneDead:
            switch(desired)
            {
            case State.landingDead:
            case State.airborneDead: return true;
            default:
            }
            return false;
        default:
        }

        return true;
    };

    if(forceState || (animation.state != desiredState && canEnterState(animation.state, desiredState)))
    {
        setState(desiredState);
    }
}

bool getCameraOrigin(ref Vec3 result)
{
    GObject.MarkerTransform transform = void;

    if(parent)
    {
        if(!parent.isUnit() || enteredParentSeatIndex == indexNone)
        {
            return false;
        }

        Unit* parentUnit = cast(Unit*)parent;
        const tagUnit    = Cache.get!TagUnit(parentUnit.tagIndex);
        const tagSeat    = &tagUnit.seats[enteredParentSeatIndex];

        if(parentUnit.type == TagEnums.ObjectType.vehicle && !tagSeat.cameraMarkerName)
        {
            return false;
        }

        parent.findMarkerTransform(tagSeat.cameraMarkerName, transform);
        result = transform.world.position;
    }
    else if(damage.flags.healthDepleted || type != TagEnums.ObjectType.biped)
    {
        const tagUnit = Cache.get!TagUnit(tagIndex);

        if(auto gunner = poweredSeats[1].rider)
        {
            findMarkerTransform(tagUnit.seats[gunner.enteredParentSeatIndex].markerName, transform);
        }
        else
        {
            findMarkerTransform("head", transform);
        }

        result = transform.world.position;
    }
    else
    {
        import Game.World.Objects : Biped;

        Biped* biped = cast(Biped*)&this;
        const tagBiped = Cache.get!TagBiped(tagIndex);

        result = getWorldPosition();

        // TODO airbourne crouching compensation for camera movement

        result.z += mix(tagBiped.standingCameraHeight, tagBiped.crouchingCameraHeight, biped.crouchPercent);
    }

    return true;
}

bool weaponSeatExists(Weapon* weapon)
{
    return setSeat(getSeatName(), Cache.get!TagWeapon(weapon.tagIndex).label, false);
}

bool weaponSeatExists(const(char)[] weapon)               { return setSeat(getSeatName(), weapon, false); }
bool seatExists(const(char)[] seat, const(char)[] weapon) { return setSeat(seat, weapon, false); }
bool setSeat(const(char)[] seat, const(char)[] weapon)    { return setSeat(seat, weapon, true); }

bool checkSeatOccupied(int seat)
{
    for(GObject* child = firstChildObject; child !is null; child = child.nextSiblingObject)
    {
        if(child.type == TagEnums.ObjectType.biped)
        {
            auto unit = cast(Unit*)child;

            // todo check team types

            if(unit.enteredParentSeatIndex == seat)
            {
                return true;
            }
        }
    }

    return false;
}

bool enterSeat(Unit* desiredParent, int desiredSeatIndex)
{
    if(desiredParent.checkSeatOccupied(desiredSeatIndex))
    {
        return false;
    }

    const tagSeat = &Cache.get!TagUnit(desiredParent.tagIndex).seats[desiredSeatIndex];

    const tagUnit       = Cache.get!TagUnit(tagIndex);
    const tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    attachTo("", &desiredParent.object, tagSeat.markerName);

    enteredParentSeatIndex = desiredSeatIndex;

    // todo better power seat assignment

    if(tagSeat.flags.driver) desiredParent.poweredSeats[0].rider = &this;
    if(tagSeat.flags.gunner) desiredParent.poweredSeats[1].rider = &this;

    nextWeaponIndex = indexNone; // todo actual calculations for nextWeaponindex
    // todo force weapon update (updates current weapon index)

    if(!setSeat(tagSeat.label, getWeaponLabel()))
    {
        setSeat(tagSeat.label, null);
    }

    const unitSeatAnimation = animation.unitSeat(tagAnimations);

    if(unitSeatAnimation.animations.inUpperBound(TagEnums.UnitSeatAnimation.enter))
    {
        int index = unitSeatAnimation.animations[TagEnums.UnitSeatAnimation.enter].animation;

        if(index != indexNone)
        {
            interpolateCurrent(6);

            // todo random animation ?

            baseAnimation.animationIndex = index;
            baseAnimation.frame = 0;

            // todo translate interpolate nodes

            animation.state = State.entering;

            updateHierarchyMatrices();
        }
    }

    return true;
}

Tag.AnimationBlock* getSeatEnterAnimation(const(char)[] seat)
{
    auto tagUnit       = Cache.get!TagUnit(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    foreach(ref animationUnit ; tagAnimations.units)
    {
        if(iequals(animationUnit.label, seat))
        {
            if(animationUnit.animations.inUpperBound(TagEnums.UnitSeatAnimation.enter))
            {
                int index = animationUnit.animations[TagEnums.UnitSeatAnimation.enter].animation;

                if(index != indexNone)
                {
                    return &tagAnimations.animations[index];
                }
            }

            return null;
        }
    }

    return null;
}

const(char)[] getSeatName()
{
    if(parent && enteredParentSeatIndex != indexNone)
    {
        return Cache.get!TagUnit(parent.tagIndex).seats[enteredParentSeatIndex].label;
    }

    return unitSeatStateNames[animation.baseSeat];
}

const(char)[] getWeaponLabel()
{
    if(auto weapon = currentWeapon())
    {
        return weapon.getLabelName();
    }

    return "unarmed";
}

Weapon* currentWeapon()
{
    if(currentWeaponIndex != indexNone)
    {
        return weapons[currentWeaponIndex];
    }

    return null;
}

int findAvailableWeaponIndex()
{
    foreach(int i, weapon ; weapons)
    {
        if(weapon is null)
        {
            return i;
        }
    }

    return indexNone;
}

int findUsableWeaponIndex(int startIndex = 0)
{
    // todo this has a bool input, that checks ready times and picks weapons that must be readied

    if(startIndex == indexNone)
    {
        startIndex = 0;
    }

    int result = indexNone;
    int i      = startIndex;

    do
    {
        if(auto weapon = weapons[i])
        {
            const tagWeapon = Cache.get!TagWeapon(weapon.tagIndex);

            if(weaponSeatExists(tagWeapon.label))
            {
                result = i; // todo ready weapon times

                if(i != startIndex)
                {
                    return result;
                }
            }
        }

        if(++i >= weapons.length)
        {
            i = 0;
        }

    } while(i != startIndex);

    return result;
}

int countHeldWeapons()
{
    int count = 0;

    foreach(weapon ; weapons)
    {
        if(weapon)
        {
            const tagWeapon = Cache.get!TagWeapon(weapon.tagIndex);

            if(!tagWeapon.flags.doesntCountTowardMaximum)
            {
                count += 1;
            }
        }
    }

    return count;
}

bool isWeaponUnique(Weapon* weapon)
{
    foreach(w ; weapons)
    {
        if(w && w.tagIndex == weapon.tagIndex)
        {
            return false;
        }
    }

    return true;
}

bool shouldPickupWeaponInstantly(Weapon* desiredWeapon)
{
    const tagDesiredWeapon = Cache.get!TagWeapon(desiredWeapon.tagIndex);

    int countedWeapons = countHeldWeapons();

    if(isWeaponUnique(desiredWeapon))
    {
        if(tagDesiredWeapon.flags.doesntCountTowardMaximum || countedWeapons < TagConstants.Unit.maxCountedHeldWeapons)
        {
            return true;
        }
    }

    if(countedWeapons == 0)
    {
        return true;
    }

    return false;
}

bool canPickupWeapon(Weapon* desiredWeapon)
{
    if(currentWeapon() is null)
    {
        return true;
    }

    foreach(i, weapon ; weapons)
    {
        if(weapon && weapon.tagIndex == desiredWeapon.tagIndex)
        {
            if(i == currentWeaponIndex)
            {
                if(weapon.age > 0.0f && desiredWeapon.age < weapon.age)
                {
                    continue;
                }
            }

            return false;
        }
    }

    return true;
}

bool pickupWeapon(Weapon* weapon)
{
    if(!weapon.object.flags.connectedToMap) return false;
    if(weapon.parent)                       return false;
    if(!weaponSeatExists(weapon))           return false;

    int weaponIndex = findAvailableWeaponIndex();

    if(weaponIndex == indexNone)
    {
        return false;
    }

    weapon.disconnectFromWorld();

    weapon.headerFlags.visible = false;
    weapon.object.flags.hidden = true;

    weapons[weaponIndex] = weapon;
    nextWeaponIndex = weaponIndex;

    return true;
}

void pickupItem(Item* item)
{
    item.flags.resting               = false;
    item.flags.inUnitInventory       = true;
    item.flags.hiddenInUnitInventory = true;

    item.flags.collidedWithBsp    = false;
    item.flags.collidedWithObject = false;

    location = World.Location(); // is this correct? should this be setting for item ?
}

bool throwAwayCurrentWeapon()
{
    auto currentWeapon = currentWeapon();

    if(currentWeapon is null)             return false;
    if(currentWeapon.object.flags.hidden) return false; // todo not sure why this is needed

    // todo put away (never used ?)

    currentWeapon.attemptFirstPersonAction(FirstPerson.Action.invalidateWeapon);

    throwAwayItem(&currentWeapon.item);

    weapons[currentWeaponIndex] = null;
    currentWeaponIndex = indexNone;

    nextWeaponIndex = findUsableWeaponIndex();

    // todo check if weapon should live (always lives in multiplayer?)

    return true;
}

void throwAwayItem(Item* item)
{
    // todo some weird attach to left hand (dont know if ever used?)

    item.flags.inUnitInventory       = false;
    item.flags.hiddenInUnitInventory = false;

    item.placeInWorldRelativeToParent();

    // todo randomize velocity

    GObject* topParent = getAbsoluteParent();

    item.velocity           = topParent.velocity;
    item.rotationalVelocity = topParent.rotationalVelocity;

    item.droppedByUnit = &this;

    // todo item rotation ?
    // todo strange bsp check and deleting

    // todo unit doesn't dorp items


}

void updateWeapons()
{
    auto tagUnit       = Cache.get!TagUnit(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    Weapon* nextWeapon = nextWeaponIndex == indexNone ? null : weapons[nextWeaponIndex];

    if(auto currentWeapon = currentWeapon())
    {
        // todo put away state ?
        // todo simplify (we don't want to place in world, just hiding it in inventory)
        currentWeapon.placeInWorldRelativeToParent();

        currentWeapon.disconnectFromWorld();
        currentWeapon.activate();

        currentWeaponIndex = indexNone;
    }

    if(currentWeaponIndex == indexNone)
    {
        if(nextWeapon)
        {
            auto tagWeapon = Cache.get!TagWeapon(nextWeapon.tagIndex);

            setSeat(getSeatName(), nextWeapon.getLabelName());

            auto seat       = animation.unitSeat(tagAnimations);
            auto seatWeapon = animation.unitWeapon(tagAnimations);

            currentWeaponIndex = nextWeaponIndex;

            if(tagWeapon.model)
            {
                nextWeapon.headerFlags.visible = true;
                nextWeapon.object.flags.hidden = false;
            }

            if(currentWeaponIndex != indexNone)
            {
                // todo set ready time start
            }

            // todo needs reworking with new parent system ??
            nextWeapon.attachTo(seatWeapon.gripMarker, &this.object, seatWeapon.handMarker);
            nextWeapon.readyWeapon();
        }
        else
        {
            setSeat(getSeatName(), "unarmed");
            currentWeaponIndex = indexNone;
        }
    }

    // todo weapon zoom out play sound and other related

}

void attemptGrenadeThrow()
{
    const tagUnit = Cache.get!TagUnit(tagIndex);

    if(currentGrenadeIndex == indexNone || grenades[currentGrenadeIndex] <= 0)
    {
        return;
    }

    Weapon* currentWeapon = currentWeapon();

    if(currentWeapon is null || !currentWeapon.canThrowGrenade())
    {
        return;
    }

    currentWeapon.resetTriggers();

    if(auto biped = this.isBiped)
    {
        biped.ticksMeleeDuration = 0; // stop biped melee
    }

    animation.replacementState = ReplacementState.none;
    animation.replacement.reset();

    if(!setState(State.throwingGrenade))
    {
        return;
    }

    const tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);
    const tagAnimation  = &tagAnimations.animations[baseAnimation.animationIndex];

    grenadeState     = GrenadeState.begin;
    grenadeThrowTime = tagAnimation.keyFrameIndex + 1;
    grenadeTime      = 0;

    Vec2 direction = aim.direction.xy;

    if(normalize(direction) != 0.0f)
    {
        setRotationVertical(direction);
    }

    // TODO first person throw grenade

    if(DatumIndex throwingEffect = Cache.inst.globals.grenades[currentGrenadeIndex].throwingEffect.index)
    {
        // TODO throw effect
    }
}

void beginGrenadeThrow()
{
    const tagGrenade = &Cache.inst.globals.grenades[currentGrenadeIndex];

    grenades[currentGrenadeIndex] -= 1;
    auto leftHandMarker = findMarkerTransform("left hand");

    GObject.Creation creation =
    {
        tagIndex: tagGrenade.projectile.index,
    };

    if(Projectile* grenade = cast(Projectile*)world.createObject(creation))
    {
        heldGrenade  = grenade;
        grenadeState = GrenadeState.holding;

        heldGrenade.attachTo(&this.object, leftHandMarker.node);
    }
    else
    {
        grenadeState = GrenadeState.thrown;
    }
}

bool setState(State desired)
{
    auto tagUnit       = Cache.get!TagUnit(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagUnit.animationGraph);

    int index = indexNone;

    // TODO this switch statement can be split into two (essentially)
    //      by diving each different type of animation in half
    switch(desired)
    {

    // Unit Weapon Animation

    case State.idle:       index = getAnimationIndex(TagEnums.UnitWeaponAnimation.idle); break;
    case State.turnLeft:   index = getAnimationIndex(TagEnums.UnitWeaponAnimation.turnLeft); break;
    case State.turnRight:  index = getAnimationIndex(TagEnums.UnitWeaponAnimation.turnRight); break;
    case State.moveFront:  index = getAnimationIndex(TagEnums.UnitWeaponAnimation.moveFront); break;
    case State.moveBack:   index = getAnimationIndex(TagEnums.UnitWeaponAnimation.moveBack); break;
    case State.moveLeft:   index = getAnimationIndex(TagEnums.UnitWeaponAnimation.moveLeft); break;
    case State.moveRight:  index = getAnimationIndex(TagEnums.UnitWeaponAnimation.moveRight); break;
    case State.airborne:   index = getAnimationIndex(TagEnums.UnitWeaponAnimation.airborne); break;

    // Unit Seat Animation

    case State.airborneDead: index = getAnimationIndex(TagEnums.UnitSeatAnimation.airborneDead); break;
    case State.landingDead:  index = getAnimationIndex(TagEnums.UnitSeatAnimation.landingDead);  break;
    case State.entering:     index = getAnimationIndex(TagEnums.UnitSeatAnimation.enter);        break;
    case State.exiting:      index = getAnimationIndex(TagEnums.UnitSeatAnimation.exit);         break;

    default: assert(0, "Need to implement something here.");
    }

    if(index == indexNone)
    {
        switch(desired)
        {
        // TODO melee, leap, leap melee, etc...
        case State.throwingGrenade:
            return false;
        default:
        }
    }

    auto animUnitWeapon = animation.unitWeapon(tagAnimations);
    auto animUnitSeat   = animation.unitSeat(tagAnimations);

    // TODO handle index == indexNone better
    // TODO randomize animation selection

    baseAnimation.animationIndex = index;
    baseAnimation.frame = 0;

    // todo interpolate frame length;

    int interpolateLength = 6;

    switch(desired)
    {
    case State.idle:
    case State.turnLeft:
    case State.turnRight:
        switch(animation.state)
        {
        case State.idle:
        case State.turnLeft:
        case State.turnRight:
            interpolateLength = 1;
            break;
        default:
        }
        break;
    default:
    }

    switch(desired)
    {
    case State.idle:
    case State.turnLeft:
    case State.turnRight:
        animation.weaponAimAnimation = getAnimationIndex(TagEnums.UnitWeaponAnimation.aimStill);
        break;

    case State.moveFront:
    case State.moveBack:
    case State.moveLeft:
    case State.moveRight:
        animation.weaponAimAnimation = getAnimationIndex(TagEnums.UnitWeaponAnimation.aimMove);
        break;
    default:
    }

    if(animation.weaponAimAnimation == indexNone)
    {
        animation.headAimAnimation = getAnimationIndex(TagEnums.UnitSeatAnimation.look);
    }
    else
    {
        animation.headAimAnimation = indexNone;
    }

    interpolateCurrent(interpolateLength);
    animation.state = desired;

    return true;
}

void setOverlay(OverlayState desired)
{
    if(desired < animation.overlayState)
    {
        return;
    }

    int animationIndex;

    switch(desired) with(OverlayState)
    {
    default: return;
    case fire1:    animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.fire1); break;
    case fire2:    animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.fire2); break;
    case charged1: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.charged1); break;
    case charged2: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.charged2); break;
    case chamber1: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.chamber1); break;
    case chamber2: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.chamber2); break;
    }

    if(animationIndex != indexNone)
    {
        // todo animation randomize

        animation.overlay.animationIndex = animationIndex;
        animation.overlay.frame = 0;

        animation.overlayState = desired;
    }
}

void setReplacement(ReplacementState desired)
{
    if(desired == ReplacementState.none)
    {
        animation.replacementState = ReplacementState.none;
        animation.replacement.animationIndex = indexNone;
    }

    int animationIndex;

    switch(desired) with(ReplacementState)
    {
    default: return;
    case disarm:        animationIndex = getAnimationIndex(TagEnums.UnitWeaponAnimation.disarm);       break;
    case weaponDrop:    animationIndex = getAnimationIndex(TagEnums.UnitWeaponAnimation.drop);         break;
    case weaponReady:   animationIndex = getAnimationIndex(TagEnums.UnitWeaponAnimation.ready);        break;
    case weaponPutAway: animationIndex = getAnimationIndex(TagEnums.UnitWeaponAnimation.putAway);      break;
    case throwGrenade:  animationIndex = getAnimationIndex(TagEnums.UnitWeaponAnimation.throwGrenade); break;

    case weaponReload1: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.reload1);  break;
    case weaponReload2: animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.reload2);  break;
    case weaponMelee:   animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.melee);    break;
    case overheat:      animationIndex = getAnimationIndex(TagEnums.UnitWeaponTypeAnimation.overheat); break;
    }

    if(animationIndex != indexNone)
    {
        if(desired != ReplacementState.weaponMelee)
        {
            interpolateCurrent(6);
        }

        // todo random animation

        animation.replacement.animationIndex = animationIndex;
        animation.replacement.frame = 0;

        animation.replacementState = desired;
    }

}

private:

bool setSeat(const(char)[] seat, const(char)[] weapon, bool setState)
{
    const tagObject     = Cache.get!TagObject(tagIndex);
    const tagAnimations = Cache.get!TagModelAnimations(tagObject.animationGraph);

    bool isUnarmed = weapon ? iequals("unarmed", weapon) : false;
    bool found;

    foreach(int i, ref animUnit ; tagAnimations.units)
    {
        if(seat && !iequals(seat, animUnit.label))
        {
            continue;
        }

        foreach(int j, ref animWeap ; animUnit.weapons)
        foreach(int k, ref animWeapType ; animWeap.weaponTypes)
        if(weapon is null || (isUnarmed && animWeapType.label.isEmpty()) || iequals(animWeapType.label, weapon))
        {
            found = true;

            if(setState)
            {
                animation.baseSeat = BaseSeat.none;

                foreach(n, name ; unitSeatStateNames)
                {
                    if(iequals(seat, name))
                    {
                        animation.baseSeat = cast(BaseSeat)n;
                    }
                }

                enum indices =
                [
                    TagEnums.UnitSeatAnimation.accelFrontBack,
                    TagEnums.UnitSeatAnimation.accelLeftRight,
                    TagEnums.UnitSeatAnimation.accelUpDown,
                ];

                animation.flags.hasSeatAcceleration = false;

                foreach(anim ; indices)
                {
                    if(animUnit.animations.inUpperBound(anim) && animUnit.animations[anim].animation != indexNone)
                    {
                        animation.flags.hasSeatAcceleration = true;
                        break;
                    }
                }

                animation.state = State.none;
                animation.unitIndex           = i;
                animation.unitWeaponIndex     = j;
                animation.unitWeaponTypeIndex = k;
            }
        }
    }

    return found;
}

int getAnimationIndex(TagEnums.UnitSeatAnimation i)
{
    auto seat = animation.unitSeat(Cache.get!TagModelAnimations(Cache.get!TagUnit(tagIndex).animationGraph));
    return seat.animations.inUpperBound(i) ? seat.animations[i].animation : indexNone;
}

int getAnimationIndex(TagEnums.UnitWeaponAnimation i)
{
    auto weapon = animation.unitWeapon(Cache.get!TagModelAnimations(Cache.get!TagUnit(tagIndex).animationGraph));
    return weapon.animations.inUpperBound(i) ? weapon.animations[i].animation : indexNone;
}

int getAnimationIndex(TagEnums.UnitWeaponTypeAnimation i)
{
    auto type = animation.unitWeaponType(Cache.get!TagModelAnimations(Cache.get!TagUnit(tagIndex).animationGraph));
    return type.animations.inUpperBound(i) ? type.animations[i].animation : indexNone;
}

}


// end of Unit ////////////////////////////////////////////////////////////////////////////////////////////////////////////


private @nogc nothrow
void solveIk(Transform destination, ref Transform wrist, ref Transform elbow, ref Transform shoulder)
{
    Vec3 direction = destination.position - shoulder.position;
    float lengthToDestination = normalize(direction);

    Vec3 shoulderToElbow = elbow.position - shoulder.position;

    float lengthToElbow = length(shoulderToElbow);
    float lengthToWrist = length(wrist.position - elbow.position);

    const float maxLength = 0.98f * (lengthToElbow + lengthToWrist);

    // adjust destination position if it is out of reach of the length of the arm.

    if(lengthToDestination > maxLength)
    {
        destination.position = maxLength * direction + shoulder.position;
        lengthToDestination = maxLength;
    }

    Vec3 shoulderRotationAxis = cross(cross(direction, shoulderToElbow), direction);

    normalize(shoulderRotationAxis);


    float a = (sqr(lengthToDestination) + sqr(lengthToElbow) - sqr(lengthToWrist)) / (2.0f * lengthToDestination);
    Vec3 offset = shoulderRotationAxis * sqrt(sqr(lengthToElbow) - sqr(a));

    normalize(shoulder.forward = a * direction + offset);
    normalize(shoulder.up      = cross(shoulder.forward, shoulder.left));
    normalize(shoulder.left    = cross(shoulder.up, shoulder.forward));

    normalize(elbow.forward = (lengthToDestination - a) * direction - offset);
    normalize(elbow.up      = cross(elbow.forward, elbow.left));
    normalize(elbow.left    = cross(elbow.up, elbow.forward));

    elbow.position = shoulder.forward * lengthToElbow + shoulder.position;

    wrist = destination;
}

private @nogc nothrow
void solveMarkerIk(Unit* unit, const(char)[] marker, GObject* object, const(char)[] attachToMarker)
{
    GObject.MarkerTransform markerTransform         = void;
    GObject.MarkerTransform attachToMarkerTransform = void;

    if(!unit.findMarkerTransform(marker, markerTransform)
        || !object.findMarkerTransform(attachToMarker, attachToMarkerTransform))
    {
        return;
    }

    const tagUnit  = Cache.get!TagUnit(unit.tagIndex);
    const tagModel = Cache.get!TagGbxmodel(tagUnit.model);

    int parentNodeIndex = tagModel.nodes[markerTransform.node].parentNodeIndex;

    if(parentNodeIndex == indexNone)
    {
        return;
    }

    int grandParentNodeIndex = tagModel.nodes[parentNodeIndex].parentNodeIndex;

    if(grandParentNodeIndex == indexNone)
    {
        return;
    }

    solveIk(attachToMarkerTransform.world * inverse(markerTransform.local),
        unit.transforms[markerTransform.node],
        unit.transforms[parentNodeIndex],
        unit.transforms[grandParentNodeIndex]);

}
