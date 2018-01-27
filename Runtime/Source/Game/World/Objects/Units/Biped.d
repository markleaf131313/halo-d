
module Game.World.Units.Biped;

import Game.World.FirstPerson;
import Game.World.Objects.Object;
import Game.World.Items.Weapon;
import Game.World.Units.Unit;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Biped
{
@nogc nothrow:

@disable this(this);

enum MovementState
{
    stationary,
    moving,
    everythingElse,
}

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "airborne", 1,
        bool, "sliding",  1,
        bool, "limp",     1,
        int, "", 5
    ));
}

alias unit this;
Unit unit;

Flags flags;

MovementState movementState;

int ticksInAir;
int ticksOnGround;
int ticksSliding;

int ticksMeleeDuration;
int meleeDamageTick;

float crouchPercent = 0.0f;

Vec3 groundNormal;

bool implPreInitialize(GObject.Creation* data) const
{
    const tagBiped = Cache.get!TagBiped(data.tagIndex);

    if(tagBiped.flags.physicsPillCenteredAtOrigin && !tagBiped.flags.flying)
    {
        // todo update data.position
    }

    return true;
}

bool implInitialize()
{
    flags.airborne = true;
    return true;
}

bool implUpdateLogic()
{
    const tagBiped      = Cache.get!TagBiped(tagIndex);
    const tagModel      = Cache.get!TagGbxmodel(tagBiped.model);
    const tagAnimations = Cache.get!TagModelAnimations(tagBiped.animationGraph);

    Unit.State desiredState = Unit.State.idle;

    if(parent)
    {
        // todo vehicle related

        if(control.action)
        {
            if(animation.state != Unit.State.entering && animation.state != Unit.State.exiting)
            {
                auto unitSeatAnimation = animation.unitSeat(tagAnimations);

                if(unitSeatAnimation.animations.inUpperBound(TagEnums.UnitSeatAnimation.exit))
                {
                    int index = unitSeatAnimation.animations[TagEnums.UnitSeatAnimation.exit].animation;

                    if(index != indexNone)
                    {
                        baseAnimation.animationIndex = index;
                        baseAnimation.frame = 0;

                        animation.state = Unit.State.exiting;
                    }
                }
            }
        }

        incrementFrames(desiredState);

        return true;
    }


    // todo figure out state

    aim.direction = aim.desired; // todo this is just a temporary fix

    if(!(tagBiped.flags.canClimbAnySurface || tagBiped.flags.flying))
    {
        desiredForwardDirection.z = 0.0f;

        if(normalize(desiredForwardDirection) == 0.0f)
        {
            desiredForwardDirection = Vec3(1, 0, 0);
        }
    }

    switch(animation.state) with(Unit.State)
    {
    case idle:
    case turnLeft:
    case turnRight: movementState = MovementState.stationary; break;
    case airborne:
    case moveFront:
    case moveBack:
    case moveLeft:
    case moveRight: movementState = MovementState.moving; break;
    default:        movementState = MovementState.everythingElse; break;
    }

    if(lengthSqr(throttle) < sqr(0.1f))
    {
        throttle = Vec3(0.0f);
    }

    if(flags.airborne) ticksInAir = clampedIncrement(ticksInAir);
    else               ticksInAir = 0;

    if(flags.sliding) ticksSliding = clampedIncrement(ticksSliding);
    else              ticksSliding = 0;

    // rotation update //
    if(!damage.flags.healthDepleted)
    {
        // todo climb any surface, flying, flaming, alert etc..
        // this is only for base case of playing walking around

        float d    = dot(desiredForwardDirection, rotation.forward);
        float perp = perpDot(rotation.forward.xy, desiredForwardDirection.xy);

        bool left = perp > 0.0f;

        // continue rotating in same direction if desired direction is almost completely
        // in the opposite direction.

        if(d < -0.9f)
        {
            if     (animation.state == Unit.State.turnLeft)  left = true;
            else if(animation.state == Unit.State.turnRight) left = false;
        }

        if(movementState == MovementState.moving || tagBiped.flags.turnsWithoutAnimating)
        {
            float turnRate = tagBiped.movingTurningSpeed / gameFramesPerSecond;

            if(!left)
            {
                turnRate = -turnRate;
            }

            if(tagBiped.flags.canClimbAnySurface)
            {
                // todo climb any surface
            }
            else
            {
                Vec2 forward = Mat2.fromEulerAngleZ(turnRate) * rotation.forward.xy;

                bool afterLeft = perpDot(forward, desiredForwardDirection.xy) >= 0.0f;

                if(afterLeft != left)
                {
                    // passed the desired direction
                    rotation.forward = desiredForwardDirection;
                }
                else
                {
                    rotation.forward = Vec3(forward, 0);
                }
            }
        }
        else if(movementState == MovementState.stationary)
        {
            // todo biped control flag that stops turning
            // todo flag that forces 0.99 threshold (instant turning)

            if(d < tagBiped.stationaryTurningThresholdCos)
            {
                desiredState = left ? Unit.State.turnLeft : Unit.State.turnRight;
            }
        }
    }
    // end rotation update //

    // movement update //

    if(throttle != Vec3(0))
    {
        // todo stun from recent damage and stun > 0.2f
        bool stunned = false;

        if(abs(throttle.x) >= abs(throttle.y))
        {
            if(throttle.x >= 0.0f)
            {
                if(stunned) desiredState = Unit.State.stunnedFront;
                else        desiredState = Unit.State.moveFront;
            }
            else
            {
                if(stunned) desiredState = Unit.State.stunnedBack;
                else        desiredState = Unit.State.moveBack;
            }
        }
        else
        {
            if(throttle.y >= 0.0f)
            {
                if(stunned) desiredState = Unit.State.stunnedLeft;
                else        desiredState = Unit.State.moveLeft;
            }
            else
            {
                if(stunned) desiredState = Unit.State.stunnedRight;
                else        desiredState = Unit.State.moveRight;
            }
        }
    }

    if(baseAnimation)
    {
        // todo animation and damage flags

        if(!tagBiped.flags.flying)
        {
            auto controller = &baseAnimation;
            auto anim = &tagAnimations.animations[controller.animationIndex];

            Vec3 deltaTranslation = 0.0f;
            float deltaYaw        = 0.0f;

            // todo should make thise switch statement a function somewhere, when needed
            switch(anim.frameInfoType)
            {
            default:
            case TagEnums.AnimationFrameInfoType.none: break;
            case TagEnums.AnimationFrameInfoType.dxDy:
            {
                deltaTranslation.xy = anim.frameInfo.dataAs!Vec2[controller.frame];
                break;
            }
            case TagEnums.AnimationFrameInfoType.dxDyDyaw:
            {
                import std.typecons : Tuple;

                alias DataType = Tuple!(Vec2, float); static assert(DataType.sizeof == 12);

                auto data = anim.frameInfo.dataAs!DataType[controller.frame];

                deltaTranslation.xy = data[0];
                deltaYaw            = data[1];
                break;
            }
            case TagEnums.AnimationFrameInfoType.dxDyDzDyaw:
            {
                import std.typecons : Tuple;

                alias DataType = Tuple!(Vec3, float); static assert(DataType.sizeof == 16);

                auto data = anim.frameInfo.dataAs!DataType[controller.frame];

                deltaTranslation = data[0];
                deltaYaw         = data[1];
                break;
            }
            }

            if(abs(deltaYaw) >= 0.0001f)
            {
                // todo rotate using up

                Vec3 forward = Vec3(Mat2.fromEulerAngleZ(deltaYaw) * rotation.forward.xy, 0);

                // todo biped flag of some sort
                if(animation.state == Unit.State.turnLeft || animation.state == Unit.State.turnRight)
                {
                    // todo not 2d ... ? this turn state shouldn't happen when not 2d though

                    float d0 = perpDot(desiredForwardDirection.xy, rotation.forward.xy);
                    float d1 = perpDot(desiredForwardDirection.xy, forward.xy);

                    if(d0 * d1 <= 0.0f)
                    {
                        setState(Unit.State.idle);
                    }
                }

                rotation.forward = forward;
            }

            // todo delta position for animation...
        }
    }

    bool wasAlreadyOnGround = !flags.airborne;

    // todo biped flying flag + some other flag

    //////////////////////////////////////////////////////
    // todo this section of biped needs to be fixed
    /////////////////////////////////////////////////////

    Vec2 movement = throttle.xy;
    Vec2 feet     = rotation.forward.xy;

    normalize(movement);
    normalize(feet);

    if(tagBiped.flags.usesPlayerPhysics)
    {
        // todo check state == custom animation
        // todo tagBiped->flags.usesOldNtscPlayerPhysics
        // todo multiplayer speed multiplier (copies global player info)
        // todo animation delta with speed ?
    }

    float sneakPercent = crouchPercent;
    float standPercent = 1.0f - crouchPercent;

    auto playerInfo = Cache.inst.globals.playerInformation.ptr;

    if(movement.x > 0.0f) movement.x *= playerInfo.runForward  * standPercent + playerInfo.sneakForward  * sneakPercent;
    else                  movement.x *= playerInfo.runBackward * standPercent + playerInfo.sneakBackward * sneakPercent;

    movement.y *= playerInfo.runSideways * standPercent + playerInfo.sneakSideways * sneakPercent;

    movement = Mat2.fromUnitVector(feet) * (movement / gameFramesPerSecond);

    float acceleration = flags.airborne
        ? playerInfo.airborneAcceleration
        : playerInfo.runAcceleration * standPercent + playerInfo.sneakAcceleration * sneakPercent;

    acceleration /= gameFramesPerSecond;

    Vec2 change = movement - velocity.xy;

    if(normalize(change) <= acceleration)
    {
        velocity.xy = movement;
    }
    else
    {
        velocity += Vec3(change * acceleration, 0);
    }

    if(flags.airborne)
    {
        velocity.z -= gameGravity;
    }
    else
    {
        velocity += -(1.0f / 128.0f) * groundNormal;
    }

    float crouchVelocity = 0.0f;
    float crouchChange   = 0.0f;

    if(animation.baseSeat == Unit.BaseSeat.crouch)
    {
        crouchChange = 1.0f - crouchPercent;

        if(crouchChange > tagBiped.crouchTransitionTimeCompiled)
        {
            crouchChange = tagBiped.crouchTransitionTimeCompiled;
            crouchPercent += crouchChange;
        }
        else
        {
            crouchPercent = 1.0f;
        }
    }
    else
    {
        crouchChange = -crouchPercent;

        if(crouchChange < -tagBiped.crouchTransitionTimeCompiled)
        {
            crouchChange = -tagBiped.crouchTransitionTimeCompiled;
            crouchPercent += crouchChange;
        }
        else
        {
            crouchPercent = 0.0f;
        }
    }

    if(abs(crouchChange) > 0.01f && flags.airborne)
    {
        crouchVelocity = (tagBiped.standingCollisionHeight - tagBiped.crouchingCollisionHeight) * crouchChange;
    }

    velocity.z += crouchVelocity;

    Vec3[World.maxBipedPhysicsIterations] colls = void;
    int count = 0;

    float difference = tagBiped.standingCollisionHeight - tagBiped.crouchingCollisionHeight;
    float height     = tagBiped.standingCollisionHeight - difference * crouchPercent;

    world.collidePlayer(&this.object, position, tagBiped.collisionRadius, height, velocity, colls, count);

    // TODO //////////////////////////////////////////////////////////////////////////////////////////////
    disconnectFromWorld(); // TODO fix, needs reworking, temporary hack to make biped connect to map properly
    connectToWorld();
    // TODO END //////////////////////////////////////////////////////////////////////////////////////////

    velocity.z -= crouchVelocity;

    flags.airborne = true;
    flags.sliding  = false;

    float angle = -float.max;
    int ci;

    foreach(i ; 0 .. count)
    {
        if(angle <= colls[i].z)
        {
            ci = i;
            angle = colls[i].z;
        }
    }

    if(count)
    {
        flags.sliding = true;
        groundNormal = colls[ci];
    }

    if(angle > tagBiped.maximumSlopeAngleCos)
    {
        flags.airborne = false;
        groundNormal = colls[ci];
    }

    if(control.jump && !flags.airborne && ticksOnGround >= 3)
    {
        velocity.z = tagBiped.jumpVelocity;
        flags.airborne = true;
    }

    if(wasAlreadyOnGround && !flags.airborne) ticksOnGround = clampedIncrement(ticksOnGround);
    else                                      ticksOnGround = 0;

    // end of movement update //

    if(damage.flags.healthDepleted)
    {
        // TODO biped limping

        if(ticksInAir <= 3 || tagBiped.flags.hasNoDyingAirborne)
        {
            desiredState = State.landingDead;
        }
        else
        {
            desiredState = State.airborneDead;
        }
    }
    else if(flags.airborne)
    {
        // TODO state specific handling
        if(ticksInAir > 3 || animation.state == Unit.State.airborne)
        {
            desiredState = Unit.State.airborne;
        }
    }
    else if(false)
    {
        // todo landing specific
    }
    else if(false)
    {
        // todo unknown (sliding?)
    }

    if(ticksMeleeDuration)
    {
        if(ticksMeleeDuration == meleeDamageTick)
        {
            // todo do melee damage
        }

        ticksMeleeDuration -= 1;
    }
    else if(control.melee)
    {
        // todo check player controlled

        if(auto currentWeapon = currentWeapon())
        {
            if(currentWeapon.canMelee())
            {
                // todo check zoomed

                currentWeapon.attemptFirstPersonAction(FirstPerson.Action.melee);
                setReplacement(Unit.ReplacementState.weaponMelee);
                currentWeapon.resetTriggers();

                // todo first person melee

                int length = currentWeapon.getFirstPersonAnimationFrameCount(TagEnums.FirstPersonAnimation.melee);
                int key    = currentWeapon.getFirstPersonAnimationFrameCount(TagEnums.FirstPersonAnimation.melee, true);

                int duration = length - (length / 4);

                ticksMeleeDuration = duration;
                meleeDamageTick    = duration - key;

            }
        }
    }

    incrementFrames(desiredState);

    return true;
}

bool implProcessOrientations(Orientation* orientations)
{
    const tagBiped      = Cache.get!TagBiped(tagIndex);
    const tagAnimations = Cache.get!TagModelAnimations(tagBiped.animationGraph);

    if(animation.replacement)
    {
        tagAnimations.animations[animation.replacement.animationIndex]
            .decodeReplace(animation.replacement.frame, orientations);
    }

    if(animation.overlay)
    {
        tagAnimations.animations[animation.overlay.animationIndex]
            .decodeOverlay(animation.overlay.frame, orientations);
    }

    if(!tagBiped.unit.flags.simpleCreature && animation.unitIndex != indexNone)
    {
        // todo emtion related animation
        // todo talking related animation
        // todo acceleration related animation

        if(!tagBiped.unit.flags.hasNoAiming)
        {
            if(animation.weaponAimAnimation != indexNone)
            {
                // todo check animation state when more are added

                auto tagUnitSeat   = animation.unitSeat(tagAnimations);
                auto tagUnitWeapon = animation.unitWeapon(tagAnimations);

                Vec3 direction = transpose(rotation.toMat3()) * aim.direction;

                float yaw   = atan2(direction.y, direction.x);
                float pitch = atan2(direction.z, length(direction.xy));

                tagAnimations.animations[animation.weaponAimAnimation]
                    .decodeOverlayAim(tagUnitWeapon, yaw, pitch, orientations);
            }

            if(animation.headAimAnimation != indexNone)
            {
                // todo check if is playerControlled ?

                if(auto currentWeapon = currentWeapon())
                {

                }
            }
        }
    }

    return true;
}
}
