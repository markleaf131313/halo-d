
module Game.World.Items.Weapon;


import Game.World.FirstPerson;
import Game.World.Objects.Object;
import Game.World.Objects.Projectile;
import Game.World.Items.Item;
import Game.World.Units.Unit;

import Game.Cache;
import Game.Core;
import Game.Tags;


struct Weapon
{
@nogc nothrow:

@disable this(this);

alias item this;

enum State
{
    idle,
    fire1,    fire2,
    chamber1, chamber2,
    reload1,  reload2,
    charged1, charged2,
    ready,
    putAway,
}

struct Magazine
{
@nogc nothrow:

    enum State
    {
        idle,
        reloading,
        chamberingStart,
        chambering,
    }

    State state = State.idle;

    int timeRemaining;
    int reloadTime;

    int roundsUnloaded;
    int roundsLoaded;

    void setIdle()
    {
        state = State.idle;
        timeRemaining = 0;
    }

    void setChamberingStart()
    {
        state = State.chamberingStart;
        timeRemaining = 0;
    }

    void setReloading(int time)
    {
        state = State.reloading;
        timeRemaining = time;
        reloadTime    = time;
    }
}

struct Trigger
{
@nogc nothrow:

    enum State
    {
        idle,
        overload,
        spewing,
        charging,
        charged,
        frozenWhileTriggered,
        frozenTimed,

        // todo tracking related, alternative shots/overload states
    }

    struct FiringEffect
    {
        uint bits;
        int  used;
        int  index;
        int  shots;
    }

    struct Flags
    {
        import std.bitmanip : bitfields;

        mixin(bitfields!(
            bool, "blurred", 1,
            int, "", 7
        ));
    }

    Flags flags;
    State state = State.idle;
    byte timeIdle;

    int time;

    FiringEffect firingEffect;

    int roundsSinceLastTracer;

    float firingPercent = 0.0f;
    float errorPercent  = 0.0f;
    float ejectionPortRecoveryPercent = 0.0f;
    float illuminationRecoveryPercent = 0.0f;

    void setIdle()
    {
        timeIdle = 0;
        time = 0;
        state = State.idle;
    }

    void setCharging(int t)
    {
        state = State.charging;
        time = t;
    }

    void setFrozenWhileTriggered()
    {
        state = State.frozenWhileTriggered;
        time = 0;
    }

    void setFrozenTimed(int t)
    {
        state = State.frozenTimed;
        time = t;
    }
}

struct Control
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "light",            1,
        bool, "zoomed",           1,
        bool, "primaryTrigger",   1,
        bool, "secondaryTrigger", 1,
        bool, "reload",           1,
        bool, "occupied",         1,
        int, "", 2,
    ));
}

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "overheated",  1,
        bool, "recovering",  1,
        bool, "chargeFired", 1,
        bool, "reload",      1,
        int, "", 4,
    ));
}

Item item;

Flags   flags;
Control control;

State state;

float heat         = 0.0f;
float age          = 0.0f;
float illumination = 0.0f;
float integratedLightPower = 0.0f;

int alternateShotsLoaded;
int readyTimer;

Magazine[TagConstants.Weapon.maxMagazines] magazines;
Trigger[TagConstants.Weapon.maxTriggers]   triggers;

bool implInitialize()
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);

    foreach(i, ref tagMagazine ; tagWeapon.magazines)
    {
        auto magazine = &magazines[i];

        magazine.roundsUnloaded = tagMagazine.roundsTotalInitial;
        magazine.roundsLoaded   = tagMagazine.roundsLoadedMaximum;
    }

    return true;
}

bool implUpdateLogic()
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);
    const tagModel  = Cache.get!TagGbxmodel(tagWeapon.model);

    bool[TagConstants.Weapon.maxTriggers] triggersPulled;

    bool* primaryTriggerPulled   = &triggersPulled[0];
    bool* secondaryTriggerPulled = &triggersPulled[1];

    // TODO(IMPLEMENT) global bool disables weapons, for cutscenes ?

    if(tagWeapon.animationGraph)
    {
        const tagAnimations = Cache.get!TagModelAnimations(tagWeapon.animationGraph);

        switch(baseAnimation.increment(tagAnimations))
        {
        case AnimationController.State.key:
        {
            if(state == State.chamber1 || state == State.chamber2)
            {
                int i = state == State.chamber1 ? 0 : 1;

                auto tagTrigger = &tagWeapon.triggers[i];
                auto trigger    = &triggers[i];

                if(tagTrigger.ejectionPortRecoveryTime != 0.0f && tagTrigger.flags.ejectsDuringChamber)
                {
                    trigger.ejectionPortRecoveryPercent = 1.0f;
                }
            }
            break;
        }
        case AnimationController.State.end:
        {

            switch(state)
            {
            case State.idle:
            case State.fire1:
            case State.fire2:
            case State.chamber1:
            case State.chamber2:
            case State.reload1:
            case State.reload2:
            case State.ready:   changeState(State.idle); break;
            default:
            }

            break;
        }
        default:
        }
    }

    if(tagWeapon.flags.detonatesWhenDropped)
    {
        // TODO(IMPLEMENT) detonates when dropped
    }

    if(heat > 0.0f)
    {
        if(heat >= tagWeapon.overheatedThreshold)
        {
            if(!flags.overheated)
            {
                flags.overheated = true;

                if(tagWeapon.weaponType != TagEnums.WeaponType.plasmaPistol || !flags.chargeFired)
                {
                    attemptFirstPersonAction(FirstPerson.Action.overheating);
                }
                else
                {
                    attemptFirstPersonAction(FirstPerson.Action.overheatExit);
                }

                // TODO(IMPLEMENT) overheat effect
            }
        }

        if(illumination == 0.0f)
        {
            float heatLoss = tagWeapon.heatLossPerSecond * gameFramesPerSecond;

            if(tagWeapon.ageHeatRecoveryPenalty > 0.0f)
            {
                heatLoss *= 1.0f - (age * tagWeapon.ageHeatRecoveryPenalty);
            }

            heat = max(0.0f, heat - heatLoss);

            if(flags.overheated && !flags.recovering)
            {
                if((heat - tagWeapon.heatRecoveryThreshold) / heatLoss <= 1.0f)
                {
                    flags.recovering = true;
                }
            }
        }

        if(flags.overheated)
        {
            if(heat < tagWeapon.heatRecoveryThreshold)
            {
                flags.overheated = false;
                flags.recovering = false;

                // TODO(IMPLEMENT) destroy overheat effect
            }
        }
    }

    readyTimer = decrementToZero(readyTimer);

    if(readyTimer > 0) // TODO(IMPLEMENT) parent flags that nullify trigger
    {
        *primaryTriggerPulled   = false;
        *secondaryTriggerPulled = false;
    }
    else
    {
        *primaryTriggerPulled = control.primaryTrigger;

        if(tagWeapon.flags.secondaryTriggerOverridesGrenades)
        {
            // TODO(IMPLEMENT) secondary trigger parent flag
        }
        else
        {
            *secondaryTriggerPulled = false;
        }
    }

    switch(tagWeapon.secondaryTriggerMode)
    {
    case TagEnums.SecondaryTriggerMode.loadsAlternateAmmunition: break; // TODO(IMPLEMENT) secondary trigger modes
    default:
    }

    if(control.reload)
    {
        if(tagWeapon.magazines)
        {
            flags.reload = true;
        }
    }

    if(flags.reload)
    {
        magazineRequestReload(0);
    }

    foreach(int i, ref tagMagazine ; tagWeapon.magazines)
    {
        auto magazine = &magazines[i];

        magazine.timeRemaining = decrementToZero(magazine.timeRemaining);

        switch(magazine.state)
        {
        case Magazine.State.reloading:
        {
            if(magazine.timeRemaining <= 0)
            {
                magazineReload(i);
            }
            break;
        }
        case Magazine.State.chamberingStart:
        {
            // TODO(IMPLEMENT) chamering
            magazine.setIdle();
            break;
        }
        case Magazine.State.chambering:
        {
            if(magazine.timeRemaining <= 0)
            {
                magazine.setIdle();
            }

            break;
        }
        default:
        }
    }

    foreach(int i, ref tagTrigger ; tagWeapon.triggers)
    {
        auto trigger = &triggers[i];
        bool triggered = triggersPulled[i];

        if(tagTrigger.flags.analogRateOfFire)
        {
            // TODO(IMPLEMENT) analog rate of fire
        }

        if(tagTrigger.flags.sticksWhenDropped)
        {
            // TODO(IMPLEMENT) sticks when dropped
        }

        if(tagTrigger.flags.locksInOnOffState)
        {
            // TODO(IMPLEMENT) locks in on/off state
        }

        trigger.time = decrementToZero(trigger.time);

        if(trigger.ejectionPortRecoveryPercent > 0.0f)
        {
            trigger.ejectionPortRecoveryPercent
                = max(0.0f, trigger.ejectionPortRecoveryPercent - tagTrigger.ejectionPortRecoveryPercent);
        }

        if(trigger.illuminationRecoveryPercent > 0.0f)
        {
            trigger.illuminationRecoveryPercent
                = max(0.0f, trigger.illuminationRecoveryPercent - tagTrigger.illuminationRecoveryPercent);
        }

        switch(trigger.state)
        {
        case Trigger.State.idle:
        {
            // TODO(IMPLEMENT) some flag that skips reloading
            if(parent && tagTrigger.magazine != indexNone)
            {
                const tagMagazine = &tagWeapon.magazines[tagTrigger.magazine];
                auto  magazine    = &magazines[tagTrigger.magazine];

                if((magazine.roundsLoaded < tagTrigger.roundsPerShot && !tagTrigger.flags.canFireWithPartialAmmo)
                    || magazine.roundsLoaded < tagTrigger.minimumRoundsLoaded
                    || magazine.roundsLoaded == 0)
                {
                    // TODO(IMPLEMENT) reload checks and stuff
                    magazineRequestReload(tagTrigger.magazine);
                }
            }

            if(triggered && triggerCanFire(i))
            {
                triggerAttemptFire(i, true);
            }
            else
            {
                trigger.timeIdle = clampedIncrement(trigger.timeIdle);
            }

            break;
        }
        case Trigger.State.charging:
        {
            if(trigger.time == 0)
            {
                // TODO(IMPLEMENT) chage complete, state change to charged
            }

            break;
        }
        case Trigger.State.charged:
        {
            if(trigger.time == 0)
            {
                // TODO(IMPLEMENT) trigger has overcharged
            }
            break;
        }
        case Trigger.State.frozenWhileTriggered:
        {
            if(!triggered)
            {
                trigger.setIdle();
            }

            break;
        }
        case Trigger.State.frozenTimed:
        {
            if(trigger.time == 0)
            {
                trigger.setIdle();
            }
            break;
        }
        default:
        }

        if(triggered)
        {
            trigger.firingPercent = min(1.0f, trigger.firingPercent + tagTrigger.firingAccelerationPercent);

            if(tagTrigger.blurredRateOfFire != 0.0f && !trigger.flags.blurred)
            {
                if(trigger.firingPercent > tagTrigger.blurredRateOfFire)
                {
                    // TODO(IMPLEMENT) parent checs, not hidden, add object permutation for primary/secondary blur

                    trigger.flags.blurred = true;
                }
            }
        }
        else
        {
            trigger.firingPercent = max(0.0f, trigger.firingPercent - tagTrigger.firingDeaccelerationPercent);

            if(tagTrigger.blurredRateOfFire != 0.0f && trigger.flags.blurred)
            {
                if(trigger.firingPercent < tagTrigger.blurredRateOfFire)
                {
                    // TODO(IMPLEMENT) parent checs, not hidden, add object permutation for primary/secondary blur

                    trigger.flags.blurred = false;
                }
            }
        }

        // TODO(IMPLEMENT) still need a trackign state condition here
        if(triggered || trigger.state == Trigger.State.spewing)
        {
            trigger.errorPercent = min(1.0f, trigger.errorPercent + tagTrigger.errorAccelerationPercent);
        }
        else
        {
            trigger.errorPercent = max(0.0f, trigger.errorPercent - tagTrigger.errorDeaccelerationPercent);
        }

    }

    return true;
}

bool implUpdateImportFunctions()
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);
    GObject* dest = getFirstVisibleObject();

    foreach(i ; 0 .. TagConstants.Object.maxFunctions)
    {
        TagEnums.WeaponImport type;

        switch(i)
        {
        case 0: type = tagWeapon.aIn; break;
        case 1: type = tagWeapon.bIn; break;
        case 2: type = tagWeapon.cIn; break;
        case 3: type = tagWeapon.dIn; break;
        default: continue;
        }

        float value = 0.0f;

        switch(type)
        {
        case TagEnums.WeaponImport.heat:
            value = this.heat;
            break;
        case TagEnums.WeaponImport.primaryAmmunition:
        case TagEnums.WeaponImport.secondaryAmmunition:
            int index = type - TagEnums.WeaponImport.primaryAmmunition;

            if(index < tagWeapon.magazines.size)
            {
                int maximum = tagWeapon.magazines[index].roundsLoadedMaximum;
                value = cast(float)magazines[index].roundsLoaded / maximum;
            }
            break;
        case TagEnums.WeaponImport.primaryRateOfFire:
            if(tagWeapon.triggers.size > 0) value = triggers[0].firingPercent;
            break;
        case TagEnums.WeaponImport.secondaryRateOfFire:
            if(tagWeapon.triggers.size > 1) value = triggers[1].firingPercent;
            break;
        case TagEnums.WeaponImport.ready:
            value = 1.0f;
            break;
        case TagEnums.WeaponImport.primaryEjectionPort:
            if(tagWeapon.triggers.size > 0) value = triggers[0].ejectionPortRecoveryPercent;
            break;
        case TagEnums.WeaponImport.secondaryEjectionPort:
            if(tagWeapon.triggers.size > 1) value = triggers[1].ejectionPortRecoveryPercent;
            break;
        case TagEnums.WeaponImport.overheated:
            if(flags.overheated && tagWeapon.heatRecoveryThreshold != 1.0f)
            {
                value = (heat - tagWeapon.heatRecoveryThreshold) / (1.0f - tagWeapon.heatRecoveryThreshold);
            }
            else
            {
                value = 0.0f;
            }
            break;
        case TagEnums.WeaponImport.primaryCharged:   if(tagWeapon.triggers.size > 0) value = chargedPercent(0); break;
        case TagEnums.WeaponImport.secondaryCharged: if(tagWeapon.triggers.size > 1) value = chargedPercent(1); break;
        case TagEnums.WeaponImport.illumination:
            break;
        case TagEnums.WeaponImport.age:             value = age;                  break;
        case TagEnums.WeaponImport.integratedLight: value = integratedLightPower; break;
        case TagEnums.WeaponImport.primaryFiring:
        case TagEnums.WeaponImport.secondaryFiring:
            assert(0); // TODO(IMPLEMENT)
            break;
        case TagEnums.WeaponImport.primaryFiringOn:
        case TagEnums.WeaponImport.secondaryFiringOn:
            static bool checkReloading(const ref Weapon weapon, const TagWeapon* tagWeapon)
            {
                if(tagWeapon.magazines.size > 0 && weapon.magazines[0].state == Magazine.State.reloading)
                {
                    return true;
                }
                return false;
            }

            int index = type - TagEnums.WeaponImport.primaryFiringOn;
            if(index < tagWeapon.triggers.size)
            {
                const tagTrigger = &tagWeapon.triggers[index];
                Magazine* magazine;

                if(tagTrigger.magazine != indexNone)
                {
                    magazine = &magazines[tagTrigger.magazine];
                }

                value = triggers[index].firingPercent;

                if((magazine && magazine.roundsLoaded == 0) || flags.overheated || checkReloading(this, tagWeapon))
                {
                    value = 0.0f;
                }
            }
            break;
        default: value = 0.0f;
        }

        importFunctionValues[i] = value;
    }

    return true;
}

const(char)[] getLabelName()
{
    return Cache.get!TagWeapon(tagIndex).label;
}

bool triggerCanFire(int triggerIndex)
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    const tagTrigger = &tagWeapon.triggers[triggerIndex];
    auto  trigger    = &triggers[triggerIndex];

    bool fire = false;

    if(tagTrigger.flags.analogRateOfFire)
    {
        // todo analog rate of fire
    }

    float shotsPerSecond = tagTrigger.roundsPerSecond.mix(trigger.firingPercent);

    if(shotsPerSecond < 0.0001f) shotsPerSecond = 0.0f;
    else                         shotsPerSecond = gameFramesPerSecond / shotsPerSecond;

    if(tagWeapon.ageRateOfFirePenalty != 0.0f)
    {
        shotsPerSecond = shotsPerSecond * (age * tagWeapon.ageRateOfFirePenalty + 1.0f);
    }

    if(shotsPerSecond < float(trigger.timeIdle) + 1.0f)
    {
        fire = true;
    }

    if(tagTrigger.flags.doesNotRepeatAutomatically)
    {
        // todo does not repeat automatically
    }

    return fire;
}

void triggerAttemptFire(int triggerIndex, bool canCharge)
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    const tagTrigger = &tagWeapon.triggers[triggerIndex];
    auto  trigger    = &triggers[triggerIndex];

    if(tagTrigger.magazine != indexNone)
    {
        auto magazine = &magazines[tagTrigger.magazine];

        if(magazine.state != Magazine.State.idle)
        {
            return;
        }
    }

    if(false) // todo weapon object flag - bit 01
    {
        return;
    }

    if(canCharge)
    {
        if(tagTrigger.chargingTime == 0.0f)
        {
            if(tagTrigger.overloadTime != 0.0f)
            {
                // todo change trigger to overload state

                return;
            }
        }
        else if(!(tagWeapon.flags.cannotFireAtMaximumAge && age == 1.0f))
        {
            if(tagWeapon.triggers.size > 1)
            {
                // todo create charging effect
                // tagTrigger.chargingEffect
            }
            else
            {
                // some weird behavior for weapons here
                // basically if has a charging time and only 1 trigger, then it will only fire
                // when the trigger has a non zero rate of fire

                if(trigger.firingPercent == 0.0f)
                {
                    // todo remove trigger flag - bit 0x20
                }
                else
                {
                    // todo set flag - bit 0x20
                    triggerFire(triggerIndex);
                }
            }

            trigger.setCharging(cast(int)(tagTrigger.chargingTime * gameFramesPerSecond));

            return;
        }
    }

    triggerFire(triggerIndex);
}

private
void triggerFire(int triggerIndex)
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);

    const tagTrigger = &tagWeapon.triggers[triggerIndex];
    auto  trigger    = &triggers[triggerIndex];

    bool fire          = false;
    bool misfire       = false;
    bool alternateAmmo = false;

    DatumIndex tagEffectIndex;
    DatumIndex tagDamageEffectIndex;

    float effectFiringRate = 0.0f;
    float effectHeat       = 0.0f;

    // todo check if has parent

    if(triggerIndex == 1)
    {
        switch(tagWeapon.secondaryTriggerMode)
        {
        case TagEnums.SecondaryTriggerMode.loadsAlternateAmmunition:
        case TagEnums.SecondaryTriggerMode.loadsMultiplePrimaryAmmunition:
            alternateAmmo = true;
            break;
        default:
        }
    }

    if(tagTrigger.magazine != indexNone)
    {
        const tagMagazine = &tagWeapon.magazines[tagTrigger.magazine];
        auto  magazine    = &magazines[tagTrigger.magazine];

        if(!alternateAmmo || alternateShotsLoaded < tagWeapon.maximumAlternateShotsLoaded)
        {
            if(magazine.roundsLoaded >= tagTrigger.roundsPerShot || tagTrigger.flags.canFireWithPartialAmmo)
            {
                if(!tagWeapon.flags.cannotFireAtMaximumAge || age != 1.0f)
                {
                    if(magazine.roundsLoaded >= tagTrigger.minimumRoundsLoaded)
                    {
                        // todo trigger flag - bit 0x01

                        magazine.roundsLoaded -= tagTrigger.roundsPerShot;

                        if(magazine.roundsLoaded < 0)
                        {
                            magazine.roundsLoaded = 0;
                        }
                        else if(tagMagazine.flags.everyRoundMustBeChambered)
                        {
                            magazine.setChamberingStart();
                        }

                        fire = true;
                    }
                }
            }
        }
    }
    else
    {
        fire = true;
    }

    if(tagTrigger.firingEffects.size > 0)
    {
        if(trigger.firingEffect.shots <= 0)
        {
            int index = trigger.firingEffect.index;

            if(tagTrigger.flags.randomFiringEffects)
            {
                index = randomValueFromZero(tagTrigger.firingEffects.size);
            }

            foreach(i ; 0 .. tagTrigger.firingEffects.size)
            {
                if(trigger.firingEffect.used == tagTrigger.firingEffects.size)
                {
                    trigger.firingEffect.bits = 0;
                    trigger.firingEffect.used = 0;
                }

                do
                {
                    index = (index + 1) % tagTrigger.firingEffects.size;
                }
                while((1 << index) & trigger.firingEffect.bits);

                auto tagFiringEffect = &tagTrigger.firingEffects[index];

                trigger.firingEffect.bits |= (1 << index);
                trigger.firingEffect.used += 1;
                trigger.firingEffect.index = index;
                trigger.firingEffect.shots = randomValue(tagFiringEffect.shotCountBounds);

                if(trigger.firingEffect.shots > 0)
                {
                    break;
                }
            }
        }

        trigger.firingEffect.shots -= 1;

        auto tagFiringEffect = &tagTrigger.firingEffects[trigger.firingEffect.index];

        if(tagWeapon.ageMisfireChance > 0.0f && tagWeapon.ageMisfireChance < 1.0f && age > tagWeapon.ageMisfireStart)
        {
            float chance = (age - tagWeapon.ageMisfireStart)
                * tagWeapon.ageMisfireChance / (1.0f - tagWeapon.ageMisfireStart);

            if(trigger.state == Trigger.State.spewing)
            {
                chance *= 2.0f;
            }

            if(randomPercent() < chance)
            {
                misfire = true;
            }
        }

        if(fire)
        {
            effectFiringRate = trigger.firingPercent;

            if(misfire)
            {
                tagEffectIndex       = tagFiringEffect.misfireEffect.index;
                tagDamageEffectIndex = tagFiringEffect.misfireDamage.index;
            }
            else
            {
                tagEffectIndex       = tagFiringEffect.firingEffect.index;
                tagDamageEffectIndex = tagFiringEffect.firingDamage.index;

                if(tagWeapon.overheatedThreshold != 0.0f)
                {
                    effectHeat = heat / tagWeapon.overheatedThreshold;
                }
            }
        }
        else
        {
            tagEffectIndex       = tagFiringEffect.emptyEffect.index;
            tagDamageEffectIndex = tagFiringEffect.emptyDamage.index;

            effectFiringRate = 1.0f;
        }
    }

    if(fire)
    {
        // todo item related flag - camo ?
        // todo last trigger fire time

        FirstPerson.Action action;

        if(misfire) action = triggerIndex == 0 ? FirstPerson.Action.misfire1 : FirstPerson.Action.misfire2;
        else        action = triggerIndex == 0 ? FirstPerson.Action.fire1    : FirstPerson.Action.fire2;

        attemptFirstPersonAction(action);

        if(tagTrigger.ejectionPortRecoveryTime > 0.0f)
        {
            if(tagTrigger.flags.ejectsDuringChamber)
            {
                trigger.ejectionPortRecoveryPercent = 1.0f;
            }
        }

        if(tagTrigger.illuminationRecoveryTime > 0.0f)
        {
            trigger.illuminationRecoveryPercent = 1.0f;
        }

        heat += tagTrigger.heatGeneratedPerRound;

        // todo item flag again... if we overheat and not in inventory stay overheated ?

        heat = min(heat, 1.0f);

        // todo item flags if none set skips ... ?

        age += tagTrigger.ageGeneratedPerRound;

        if(age > 1.0f)
        {
            age = 1.0f;

            // todo set object flag
        }

        changeState(triggerIndex == 0 ? State.fire1 : State.fire2);

        if(!misfire)
        {
            if(alternateAmmo)
            {
                alternateShotsLoaded += 1;
            }
            else
            {
                // todo client side only projectile flag
                createProjectiles(triggerIndex);
            }
        }

        if(tagWeapon.weaponType == TagEnums.WeaponType.plasmaPistol)
        {
            if(triggerIndex == 1)
            {
                flags.chargeFired = true;
            }
        }
    }

    if(heat > tagWeapon.heatDetonationThreshold)
    {
        // todo detonation RNG
    }

    if(fire)
    {
        // todo trackign related states
        trigger.setIdle();
    }
    else
    {
        trigger.setFrozenWhileTriggered();
    }

    createEffectOrSound(tagEffectIndex, effectFiringRate, effectHeat);
}

void magazineRequestReload(int magazineIndex)
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    const tagMagazine = &tagWeapon.magazines[magazineIndex];
    auto  magazine    = &magazines[magazineIndex];

    if(magazine.state == Magazine.State.idle || magazine.state == Magazine.State.chamberingStart)
    {
        if(triggers[0].state == Trigger.State.idle && triggers[1].state == Trigger.State.idle && state == State.idle)
        {
            if(magazine.roundsUnloaded != 0)
            {
                if(magazine.roundsLoaded < tagMagazine.roundsLoadedMaximum)
                {
                    changeState(magazineIndex == 0 ? State.reload1 : State.reload2);

                    attemptFirstPersonAction(magazine.roundsLoaded == 0
                        ? FirstPerson.Action.reloadEmpty
                        : FirstPerson.Action.reloadFull);

                    // todo shots to recharge

                    magazine.setReloading(getFirstPersonAnimationFrameCount(TagEnums.FirstPersonAnimation.reloadEmpty));
                }
            }

            flags.reload = false;
        }
    }
}

void magazineReload(int magazineIndex)
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    const tagMagazine = &tagWeapon.magazines[magazineIndex];
    auto  magazine    = &magazines[magazineIndex];

    if(tagMagazine.flags.wastesRoundsWhenReloaded)
    {
        magazine.roundsLoaded = 0;
    }

    int roundsToReload = min(magazine.roundsUnloaded, tagMagazine.roundsReloaded);
    int roundsLoaded   = min(magazine.roundsLoaded + roundsToReload, tagMagazine.roundsLoadedMaximum);

    // todo global state ?
    // todo infintie cheat ammo

    magazine.roundsUnloaded -= roundsLoaded - magazine.roundsLoaded;
    magazine.roundsLoaded = roundsLoaded;

    magazine.setChamberingStart();

    if(magazine.roundsUnloaded > 0)
    {
        if(roundsLoaded < tagMagazine.roundsLoadedMaximum && tagMagazine.flags.wastesRoundsWhenReloaded)
        {
            if(!(control.primaryTrigger || control.secondaryTrigger)) // todo control bit (not next weapon)
            {
                magazineRequestReload(magazineIndex);
            }
        }
    }
}

bool attemptConsumeAmmo(Item* item)
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);

    bool result = false;

    foreach(i, ref tagMagazine ; tagWeapon.magazines)
    {
        auto magazine = &magazines[i];

        if(magazine.roundsUnloaded >= tagMagazine.roundsTotalMaximum)
        {
            continue;
        }

        int roundsUnloadedSpace = tagMagazine.roundsTotalMaximum - magazine.roundsUnloaded;
        int roundsToPickup = 0;

        if(tagIndex == item.tagIndex)
        {
            Weapon*   pickupWeapon   = cast(Weapon*)item;
            Magazine* pickupMagazine = &pickupWeapon.magazines[i];

            roundsToPickup = min(roundsUnloadedSpace, pickupMagazine.roundsUnloaded);

            if(roundsToPickup != 0)
            {
                // TODO(IMPLEMENT) pick up sound

                pickupMagazine.roundsUnloaded -= roundsToPickup;

                if(pickupMagazine.roundsUnloaded == 0)
                {
                    pickupWeapon.requestDeletion();
                }
            }

            result = true;
        }
        else
        {
            foreach(ref tagAmmoPack ; tagMagazine.magazines)
            {
                if(tagAmmoPack.equipment.index == item.tagIndex)
                {
                    roundsToPickup = min(roundsUnloadedSpace, tagAmmoPack.rounds);

                    // TODO(IMPLEMENT) pickup sound

                    item.requestDeletion();
                    result = true;

                    break;
                }
            }
        }

        magazine.roundsUnloaded += roundsToPickup;
    }

    return result;
}

void changeState(State desiredState)
{
    auto tagWeapon     = Cache.get!TagWeapon(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagWeapon.animationGraph);

    if(tagAnimations && tagAnimations.weapons)
    {
        TagEnums.WeaponAnimation index;

        switch(desiredState)
        {
        case State.idle:     index = TagEnums.WeaponAnimation.idle; break;
        case State.ready:    index = TagEnums.WeaponAnimation.ready; break;
        case State.putAway:  index = TagEnums.WeaponAnimation.putAway; break;
        case State.fire1:    index = TagEnums.WeaponAnimation.fire1; break;
        case State.fire2:    index = TagEnums.WeaponAnimation.fire2; break;
        case State.reload1:
        case State.reload2:  index = TagEnums.WeaponAnimation.reload1; break;
        case State.chamber1:
        case State.chamber2: index = TagEnums.WeaponAnimation.chamber1; break;
        case State.charged1: index = TagEnums.WeaponAnimation.charged1; break;
        case State.charged2: index = TagEnums.WeaponAnimation.charged2; break;
        default: assert(0);
        }

        int animationIndex = tagAnimations.weapons.animations[index].animation;

        if(animationIndex != indexNone || desiredState == State.idle)
        {
            // todo animation random

            baseAnimation.animationIndex = animationIndex;
            baseAnimation.frame = 0;
            state = desiredState;
        }
    }

    if(parent)
    {
        auto unit = cast(Unit*)parent;

        switch(desiredState)
        {
        case State.fire1:    unit.setOverlay(Unit.OverlayState.fire1);    break;
        case State.fire2:    unit.setOverlay(Unit.OverlayState.fire2);    break;
        case State.chamber1: unit.setOverlay(Unit.OverlayState.chamber1); break;
        case State.chamber2: unit.setOverlay(Unit.OverlayState.chamber2); break;
        case State.charged1: unit.setOverlay(Unit.OverlayState.charged1); break;
        case State.charged2: unit.setOverlay(Unit.OverlayState.charged2); break;

        case State.reload1: unit.setReplacement(Unit.ReplacementState.weaponReload1); break;
        case State.reload2: unit.setReplacement(Unit.ReplacementState.weaponReload2); break;
        case State.ready:   unit.setReplacement(Unit.ReplacementState.weaponReady);   break;
        case State.putAway: unit.setReplacement(Unit.ReplacementState.weaponPutAway); break;
        default:
        }
    }
}

void resetTriggers()
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    for(int i = 0; i < tagWeapon.triggers.size; ++i)
    {
        triggers[i].setFrozenTimed(0);
    }

    for(int i = 0; i < tagWeapon.magazines.size; ++i)
    {
        auto magazine = &magazines[i];

        if(magazine.state == Magazine.State.reloading)
        {
            if(2 * magazine.timeRemaining < magazine.reloadTime)
            {
                magazineReload(i);
            }
        }
    }
}

void readyWeapon()
{
    auto tagWeapon = Cache.get!TagWeapon(tagIndex);

    resetTriggers();

    changeState(State.ready);
    attemptFirstPersonAction(FirstPerson.Action.ready);

    // todo creation effects

    readyTimer = getFirstPersonAnimationFrameCount(TagEnums.FirstPersonAnimation.ready);
}

bool canMelee()
{
    switch(triggers[0].state)
    {
    case Trigger.State.charging:
    case Trigger.State.charged:
        return false;
    default:
        return !Cache.get!TagWeapon(tagIndex).flags.preventsMeleeAttack;
    }
}

bool canThrowGrenade()
{
    const tagWeapon = Cache.get!TagWeapon(tagIndex);

    bool result = !tagWeapon.flags.preventsGrenadeThrowing;

    switch(state)
    {
    case State.reload1:
    case State.reload2:
    case State.charged1:
    case State.charged2:
    case State.ready:
    case State.putAway:
        return false;
    default:
    }

    return result;
}

void attemptFirstPersonAction(FirstPerson.Action action)
{
    // TODO
}

int getFirstPersonAnimationFrameCount(TagEnums.FirstPersonAnimation i, bool keyFrame = false)
{
    auto tagAnimations = Cache.get!TagModelAnimations(Cache.get!TagWeapon(tagIndex).firstPersonAnimations);

    if(tagAnimations)
    {
        if(tagAnimations.firstPersonWeapons && tagAnimations.firstPersonWeapons.animations.inUpperBound(i))
        {
            int animationIndex = tagAnimations.firstPersonWeapons.animations[i].animation;

            if(animationIndex != indexNone)
            {
                if(keyFrame) return tagAnimations.animations[animationIndex].keyFrameIndex;
                else         return tagAnimations.animations[animationIndex].frameCount;
            }
        }
    }

    return 0;
}

private
void createProjectiles(int triggerIndex)
{
    const tagWeapon  = Cache.get!TagWeapon(tagIndex);
    const tagTrigger = &tagWeapon.triggers[triggerIndex];
    auto  trigger    = &triggers[triggerIndex];

    Unit* host;

    if(parent && parent.isUnit())
    {
        host = cast(Unit*)parent;
    }

    const(char)[] triggerMarker = triggerIndex == 0 ? "primary trigger" : "secondary trigger";
    GObject.MarkerTransform[64] transforms = void;

    GObject* markerObject = this.object.flags.hidden && parent ? parent : &this.object;
    int      count        = markerObject.findMarkerTransform(triggerMarker, transforms.length, transforms.ptr);

    foreach(ref transform ; transforms[0 .. count])
    {
        Vec3  forward   = transform.world.forward;
        Vec3  position  = transform.world.position;
        float hostSpeed = 0.0f;
        float projectileError = 0.0f;

        if(!tagTrigger.flags.projectileVectorCannotBeAdjusted && host && !host.damage.flags.healthDepleted)
        {
            const tagUnit = Cache.get!TagUnit(host.tagIndex);
            DatumIndex controllingPlayerIndex = host.controllingPlayerIndex;

            if(auto gunner = host.poweredSeats[1].rider)
            {
                controllingPlayerIndex = gunner.controllingPlayerIndex;
            }
            else
            {
                forward = host.aim.direction;
            }

            if(tagUnit.flags.firesFromCamera)
            {
                const Vec3 origin = host.getCameraOrigin();

                // make new position same distance away in direction of projectile forward as previously.
                position = origin + dot(position - origin, forward) * forward;
            }

            hostSpeed = dot(host.getAbsoluteParent().velocity, forward);

            if(controllingPlayerIndex)
            {
                // TODO aim assist modification
            }
        }

        if(tagTrigger.flags.projectilesUseWeaponOrigin)
        {
            position = transform.world.position;
        }

        int        numProjectiles     = tagTrigger.projectilesPerShot;
        DatumIndex projectileTagIndex = tagTrigger.projectile.index;

        if(triggerIndex == 0 && alternateShotsLoaded > 0)
        {
            numProjectiles = alternateShotsLoaded;
            alternateShotsLoaded = 0;

            if(tagWeapon.secondaryTriggerMode == TagEnums.SecondaryTriggerMode.loadsMultiplePrimaryAmmunition)
            {
                numProjectiles += 1;
            }

            numProjectiles *= tagTrigger.projectilesPerShot;
            projectileTagIndex = tagWeapon.triggers[1].projectile.index;
        }

        if(!projectileTagIndex)
        {
            continue;
        }

        Unit* gunnerUnit;

        if(host)
        {
            gunnerUnit = host.poweredSeats[1].rider;

            if(gunnerUnit is null)
            {
                gunnerUnit = host;
            }
        }

        const tagProjectile = Cache.get!TagProjectile(projectileTagIndex);
        Vec3 firstForward;

        foreach(p ; 0 .. numProjectiles)
        {
            bool isTracer;
            GObject.Creation creation;

            creation.tagIndex = projectileTagIndex;
            creation.position = position;
            creation.forward  = forward;

            trigger.roundsSinceLastTracer += 1;
            if(trigger.firingPercent == 0.0f || trigger.roundsSinceLastTracer >= tagTrigger.roundsBetweenTracers)
            {
                isTracer = true;
                trigger.roundsSinceLastTracer = 0;
            }

            if(projectileError == 0.0f)
            {
                // TODO implement analog rate of fire, replace constant 0.5f
                float alpha = tagTrigger.flags.analogRateOfFire ? 0.5f : trigger.firingPercent;
                projectileError = tagTrigger.errorAngle.mix(alpha);
            }

            if(!tagTrigger.flags.useErrorWhenUnzoomed || !control.zoomed)
            {
                auto error = TagBounds!float(tagTrigger.minimumError, projectileError);
                creation.forward = randomRotatedVector(creation.forward, error);
            }

            if(p == 0)
            {
                firstForward = creation.forward;
            }

            if(tagTrigger.flags.projectilesHaveIdenticalError)
            {
                creation.forward = firstForward;
            }

            creation.up = anyPerpendicularTo(creation.forward);
            normalize(creation.up);

            // TODO weapon trigger distribution horizontal fan

            if(tagProjectile.flags.combineInitialVelocityWithParentVelocity)
            {
                creation.velocity = host.getAbsoluteParent().velocity;
            }
            else
            {
                creation.velocity = creation.forward * hostSpeed;
            }

            if(auto projectile = cast(Projectile*)world.createObject(creation))
            {
                // TODO if player controlled, check to make sure no collision
                //      happens from camera origin -> projectile position (projectile can be offseted)

                // TODO target object, related to aim assist above

                if(!isTracer)
                {
                    projectile.flags.tracer = false;
                }
            }
        }
    }
}

private
DatumIndex createEffectOrSound(DatumIndex index, float scaleA, float scaleB)
{
    if(index != DatumIndex.none)
    {
        auto meta = &Cache.inst.metaAt(index);

        switch(meta.type)
        {
        case TagId.effect:
        {
            auto tagEffect = meta.tagData!TagEffect;

            world.createEffectFromItem(index, &this.object, scaleA, scaleB);

            break;
        }
        case TagId.sound:
        {
            // TODO(IMPLEMENT, SOUND) play sound tag
            break;
        }
        default:
        }
    }

    return DatumIndex.none;
}

private float chargedPercent(int triggerIndex)
{
    Trigger* trigger = &triggers[triggerIndex];

    if(trigger.state == Trigger.State.charging)
    {
        const tagWeapon = Cache.get!TagWeapon(tagIndex);
        return 1.0f - (trigger.time / cast(float)gameFramesPerSecond) / tagWeapon.triggers[triggerIndex].chargingTime;
    }
    else if(trigger.state == Trigger.State.charged)
    {
        return 1.0f;
    }
    else
    {
        return 0.0f;
    }
}

}
