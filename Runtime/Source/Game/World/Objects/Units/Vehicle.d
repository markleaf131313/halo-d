
module Game.World.Units.Vehicle;

import Game.World.Objects.Object;
import Game.World.Units.Unit;
import Game.World.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

private
{
    enum int vehicleLinePhysicsIterations = 4;

    // cutoff point of mass inwhich global material ground friction scale is applied
    enum float groundFrictionCutoffMass = 7500.0f;

    enum int maxPhysicsMassPoints = 32;
    enum int maxPhysicsPoweredMassPoints = 32;

    enum int numJeepPoweredMass = 2; // front and back
    enum int numTankPoweredMass = 2; // left and right

    enum float speedSquareSleepCutoff = 0.001111111f; // sqrt(1/3)
    enum int numJeepPointsOnGroundSleep = 3;
    enum int numTicksToSleep = 15;
    enum float fakeFriction = 0.853f;

    enum float hoverDeltaGhost = 0.1f;
}

struct Vehicle
{
@nogc nothrow:

@disable this(this);
alias unit this;

struct PoweredMassControl
{
    float speed;
    float hover;

    Mat3 turn;
}

struct MassPointData
{
    struct Flags
    {
        import std.bitmanip : bitfields;

        mixin(bitfields!(
            bool, "resting",  1,
            bool, "grounded", 1,
            bool, "drowning", 1,
            bool, "antigrav", 1,
            ubyte, "", 4,
        ));
    }

    Flags flags;

    Vec3 position;
    Vec3 direction;

    Vec3 totalVelocity;
    Vec3 scaledTotalVelocity;

    Vec3 responseForce;
    Vec3 scaledForce;
    Vec3 airFrictionForce;
    Vec3 antigravForce;

    Vec3 forward;
    Vec3 up;
}

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "sleeping", 1, // TODO use object.flag.atRest
        bool, "grounded", 1,
        bool, "blur",     1,
        bool, "brakes",   1,
        bool, "flipping", 1,
        ubyte, "", 3,
    ));
}

Unit unit;

Flags flags;

float wheelSteering = 0.0f;
float wheelPosition = 0.0f;

float leftTreadPosition  = 0.0f; // TODO(IMPLEMENT)
float rightTreadPosition = 0.0f; // TODO(IMPLEMENT)

int ticksToSleep;

float speed = 0.0f;
float hover = 0.0f;

float[TagConstants.Vehicle.maxSuspension] suspensionPositions = 0.0f;

Vec3 vehicleCollisionForce        = 0.0f;
Vec3 vehicleCollisionAngularForce = 0.0f;

int ticksOnGround;
int ticksInAir;

bool implInitialize()
{
    auto tagVehicle = Cache.get!TagVehicle(tagIndex);

    if(tagVehicle.physics)
    {
        position.z += tagVehicle.boundingRadius * 0.5f;
    }

    return true;
}

bool implUpdateLogic()
{
    static void calcVehicleSpeed(ref float speed, Vec2 maxSpeed, Vec2 acceleration, float throttle, float scale)
    {
        assert(scale > 0.0f); // untested with negatives, shouldnt happen though

        float desiredSpeed = 0.0f;

        if     (throttle > 0.0f) desiredSpeed = maxSpeed[0] * throttle;
        else if(throttle < 0.0f) desiredSpeed = maxSpeed[1] * throttle;

        float accel = acceleration[0] * scale;
        float decel = acceleration[1] * scale;

        if(speed < desiredSpeed)
        {
            float forwardSpeed = maxSpeed[0] * scale;

            if     (speed < -decel) speed += decel;
            else if(speed >= 0.0f)  speed += accel;
            else                    speed += (1.0f - (speed / decel)) * accel;

            speed = min(speed, desiredSpeed, forwardSpeed);
        }
        else if(speed > desiredSpeed)
        {
            float reverseSpeed = maxSpeed[0] * scale;

            if     (speed > decel) speed -= decel;
            else if(speed <= 0.0f) speed -= accel;
            else                   speed -= (1.0f + (speed / decel)) * accel;

            speed = max(speed, desiredSpeed, -reverseSpeed);
        }
    }

    auto tagVehicle    = Cache.get!TagVehicle(tagIndex);
    auto tagPhysics    = Cache.get!TagPhysics(tagVehicle.physics);
    auto tagModel      = Cache.get!TagGbxmodel(tagVehicle.model);
    auto tagAnimations = Cache.get!TagModelAnimations(tagVehicle.animationGraph);

    if(!tagVehicle.physics)
    {
        return true; // todo better support no physics
    }

    flags.brakes = control.jump;

    if(!control.jump && tagVehicle.flags.controlOppositeSpeedSetsBrake)
    {
        // todo throttle and speed checks
    }

    Vec2 vehicleSpeed = Vec2(tagVehicle.maximumForwardSpeed, tagVehicle.maximumReverseSpeed);
    Vec2 vehicleAccel = Vec2(tagVehicle.speedAcceleration, tagVehicle. speedDeceleration);

    calcVehicleSpeed(speed, vehicleSpeed, vehicleAccel, flags.brakes ? 0.0f : throttle.x, 1.0f);

    float aimAngle = atan2(
        dot(desiredForwardDirection, rotation.side()),
        dot(desiredForwardDirection, rotation.forward));

    if(tagVehicle.type == TagEnums.VehiclePhysicsType.humanTank)
    {
        if(speed == 0.0f)
        {
            calcVehicleSpeed(wheelSteering, vehicleSpeed, vehicleAccel, 0.0f, 1.0f);
        }
        else
        {
            float throttle = aimAngle * (2 / PI);
            calcVehicleSpeed(wheelSteering, vehicleSpeed, vehicleAccel, clamp(throttle, -1.0f, 1.0f), 2.0f);
        }
    }
    else
    {
        float angle = speed < 0.0f ? -aimAngle : aimAngle;
        float clamped = clamp(angle, toRadians(tagVehicle.maximumRightTurn), toRadians(tagVehicle.maximumLeftTurn));
        float turnRate = toRadians(tagVehicle.turnRate) / gameFramesPerSecond;
        float difference = clamped - wheelSteering;

        if(abs(difference) < turnRate) wheelSteering += difference;
        else                           wheelSteering += (difference < 0.0f) ? -turnRate : turnRate;
    }

    if(tagVehicle.flags.speedWakesPhysics && abs(speed) > 0.0f)                  flags.sleeping = false;
    if(tagVehicle.flags.driverPowerWakesPhysics && poweredSeats[0].power > 0.0f) flags.sleeping = false;

    if(!flags.sleeping)
    {
        MassPointData[maxPhysicsMassPoints] massPointData = void;

        switch(tagVehicle.type)
        {
        case TagEnums.VehiclePhysicsType.humanJeep:
        {
            wheelPosition = fmod(wheelPosition + speed, tagVehicle.wheelCircumference);

            if(wheelPosition < 0.0f)
            {
                wheelPosition += tagVehicle.wheelCircumference;
            }

            if(tagPhysics.poweredMassPoints.size == numJeepPoweredMass)
            {
                PoweredMassControl[numJeepPoweredMass] poweredMassPoints;

                PoweredMassControl* front = &poweredMassPoints[0];
                PoweredMassControl* back  = &poweredMassPoints[1];

                front.turn = Mat3.fromEulerAngleZ(wheelSteering);
                back.turn  = transpose(front.turn);

                front.speed = speed;
                back.speed  = speed;

                doGenericPhysics(tagVehicle, tagPhysics, poweredMassPoints, massPointData);
            }
            else
            {
                doGenericPhysics(tagVehicle, tagPhysics, null, massPointData);
            }
            break;
        }
        case TagEnums.VehiclePhysicsType.humanTank:
        {
            if(tagPhysics.poweredMassPoints.size == numTankPoweredMass)
            {
                PoweredMassControl[numTankPoweredMass] poweredMassPoints = void;

                PoweredMassControl* left  = &poweredMassPoints[0];
                PoweredMassControl* right = &poweredMassPoints[1];

                left.speed  = speed - wheelSteering;
                right.speed = speed + wheelSteering;

                doGenericPhysics(tagVehicle, tagPhysics, poweredMassPoints, massPointData);
            }
            else
            {
                doGenericPhysics(tagVehicle, tagPhysics, null, massPointData);
            }

            break;
        }
        case TagEnums.VehiclePhysicsType.alienScout:
        {
            // todo ghost has a lot of magic constants, fix them somehow..

            PoweredMassControl[maxPhysicsPoweredMassPoints] powered = void; // todo use static_vector?

            // todo water fog plane

            foreach(i ; 0 .. tagPhysics.poweredMassPoints.size)
            {
                powered[i].hover = poweredSeats[0].power; // todo seat power, correct?
                powered[i].speed = 0.0f;
                powered[i].turn = Mat3(1.0f);
            }

            Vec3 externalForce        = 0.0f;
            Vec3 externalAngularForce = 0.0f;

            if(rotation.up.z > -0.2f)
            {
                Transform transform = Transform(rotation.toMat3(), position);
                Vec3 rotatedVelocity = transpose(transform.mat3) * velocity;

                if(hover > 0.0f)
                {
                    float maxSpeed = tagVehicle.maximumForwardSpeed;
                    float accel    = tagVehicle.speedAcceleration;

                    if(flags.brakes)
                    {
                        maxSpeed *= 0.8f;
                    }

                    if(ticksOnGround && abs(aimAngle) >= toRadians(45.0f))
                    {
                        accel *= 1.0f - min(ticksOnGround * 0.05f, 0.98f);
                    }

                    Vec3 maxVelocity = maxSpeed * throttle;
                    Vec3 delta = maxVelocity - Vec3(rotatedVelocity.xy, 0.0f); // todo - do we just cut out the Z component?

                    delta = transform.mat3 * clampLength(delta, accel);
                    externalForce += delta * tagPhysics.mass * hover;

                }

                if(hover > 0.0f)
                {
                    float turnVelocity = dot(rotationalVelocity, rotation.up);

                    int direction = 0;

                    if     (aimAngle > 0.0f) direction = 1;
                    else if(aimAngle < 0.0f) direction = -1;

                    float value = direction * sqrt(6.981317419558763e-3 * abs(aimAngle)); // pi / 450

                    enum float maxTurnRateGhost = 3.49065870e-3f; // pi / 900

                    if(abs(value) >= 0.001f)
                    {
                        if(aimAngle / value < 2.0f)
                        {
                            value = aimAngle * 0.5f;
                        }
                    }

                    float rot   = clamp(value - turnVelocity, -maxTurnRateGhost, maxTurnRateGhost);
                    float force = rot * tagPhysics.zzMoment * hover;

                    externalAngularForce += force * rotation.up;
                }

                if(hover < 1.0f)
                {
                    Vec3 side = rotation.side();

                    Vec2 forwardFlat = rotation.forward.xy;
                    Vec2 sideFlat    = side.xy;

                    normalize(forwardFlat);
                    normalize(sideFlat);

                    Vec2 delta = 0.0f;

                    enum kSpeed = 1.5514037e-3f; // ??

                    if(rotation.up.z > 0.0f)
                    {
                        // todo this need to be implemented better..

                        Vec2 angular = Vec2(-dot(rotationalVelocity.xy, forwardFlat),
                                                dot(rotationalVelocity.xy, sideFlat));

                        angular *= 15.0f;

                        Vec2 value = -Vec2(dot(forwardFlat, rotation.up.xy), dot(sideFlat, rotation.up.xy)) - angular;

                        float x = throttle.x * value.y;
                        float y = throttle.y * value.x;

                        int directionX;
                        int directionY;

                        if     (x > 0.0f) directionX = 1;
                        else if(x < 0.0f) directionX = -1;

                        if     (y > 0.0f) directionY = 1;
                        else if(y < 0.0f) directionY = -1;

                        enum float kRotation = 3.8785093e-3f; // ??

                        value.x = abs(value.x) * directionY;
                        value.y = abs(value.y) * directionX;

                        float speedX = clamp(value.x + 1.0f, 0.3f, 2.5f);
                        float speedY = clamp(value.y + 1.0f, 0.3f, 2.5f);

                        float rot = (1.0f - rotation.up.z) * kRotation;

                        delta.x = (throttle.x * kSpeed * speedX) + rot * value.y;
                        delta.y = (-throttle.y * kSpeed * speedY) + rot * value.x;
                    }
                    else
                    {
                        // todo rotation
                    }

                    float percent = 1.0f - hover;

                    externalAngularForce += side * (delta.x * percent * tagPhysics.yyMoment);
                    externalAngularForce += rotation.forward * (delta.y * percent * tagPhysics.xxMoment);

                    // todo air rotation with throttle
                }

                if(flags.brakes)
                {
                    float percent = clamp(dot(rotation.forward, velocity) / tagVehicle.maximumForwardSpeed, 0.0f, 1.0f);

                    Vec3 side = rotation.side();

                    if(percent != 0.0f)
                    {
                        externalAngularForce += side * (percent * tagPhysics.yyMoment * hover * -5.8177639e-3f);
                        externalForce        += Vec3(0, 0, 1) * (percent * tagPhysics.mass * hover * 0.004f);
                    }

                    // todo air rotation for brakes
                }

                // todo seat power scaling
                // externalAngularForce *= seatPower
                // externalForce *= seatPower
            }


            // todo ghost stuff

            doGenericPhysics(tagVehicle, tagPhysics, powered, massPointData, externalForce, externalAngularForce);


            int poweredCount  = 0;
            int poweredActive = 0;

            foreach(i, ref massPoint ; tagPhysics.massPoints)
            {
                auto data = &massPointData[i];

                if(massPoint.poweredMassPoint != indexNone)
                {
                    poweredCount += 1;

                    if(data.flags.antigrav)
                    {
                        poweredActive += 1;
                    }
                }
            }

            float hoverPower = poweredCount ? float(poweredActive) / poweredCount : 0.0f;
            float surface    = max(rotation.up.z, 0.4f);

            hoverPower = clamp(hoverPower * surface, 0.0f, 1.0f);

            float delta = hoverPower - hover;

            if     (delta >  hoverDeltaGhost) hover += hoverDeltaGhost;
            else if(delta < -hoverDeltaGhost) hover -= hoverDeltaGhost;
            else                              hover = hoverPower;


            break;
        }
        case TagEnums.VehiclePhysicsType.alienFighter: // todo implement
        default: doGenericPhysics(tagVehicle, tagPhysics, null, massPointData); break;
        }

        // todo move body outside
        void setTickState()
        {
            ticksInAir = clampedIncrement(ticksInAir);

            foreach(i, ref tagMassPoint ; tagPhysics.massPoints)
            {
                auto data = &massPointData[i];

                if(data.flags.grounded)
                {
                    ticksInAir = 0;
                    ticksOnGround = clampedIncrement(ticksOnGround);
                    return;
                }
                else if(data.flags.antigrav)
                {
                    ticksInAir = 0;
                }
            }

            ticksOnGround = 0;
        }

        setTickState();

        if(flags.sleeping)
        {
            ticksToSleep = numTicksToSleep;
        }

    }
    else if(ticksToSleep)
    {
        ticksToSleep -= 1;

        velocity           *= fakeFriction;
        rotationalVelocity *= fakeFriction;

        Vec3 pos = position + velocity;
        Mat3 rot = Mat3.fromEuler(rotationalVelocity);

        rotation.forward = rot * rotation.forward;
        rotation.up      = rot * rotation.up;

        if(ticksToSleep == 0)
        {
            velocity           = Vec3(0);
            rotationalVelocity = Vec3(0);
        }

        position = pos;

        // todo update suspension
    }

    if(tagAnimations.vehicles)
    {
        // todo move suspension into not sleeping section

        Transform transform = Transform(rotation.toMat3(), position);

        foreach(i, ref suspension ; tagAnimations.vehicles.suspensionAnimations)
        {
            if(suspension.massPointIndex < 0)                          continue;
            if(suspension.massPointIndex > tagPhysics.massPoints.size) continue;

            auto massPoint = &tagPhysics.massPoints[suspension.massPointIndex];

            Vec3 massPosition = transform * massPoint.position;
            Vec3 normal = transform.mat3 * massPoint.up;

            float movement = suspension.fullExtensionGroundDepth - suspension.fullCompressionGroundDepth;
            float distance = suspension.fullCompressionGroundDepth - tagPhysics.centerOfMass.z;

            distance -= movement;

            Vec3 start    = normal * distance + massPosition;
            Vec3 velocity = normal * (movement * 2.0f);

            World.LineResult result = void;
            World.LineOptions options;

            options.structure = true;
            options.objects   = true;
            options.objectTypes.set(TagEnums.ObjectType.scenery); // todo type mask, double check correct

            world.collideLine(&this.object, start, velocity, options, result);

            suspensionPositions[i] += clamp((1.0f - result.percent) * 2.0f, 0.0f, 1.0f);
            suspensionPositions[i] = clamp(0.5f * suspensionPositions[i], 0.0f, 1.0f);

        }

        // todo fix animation and map disconnecting / connecting

    }

    static void modelSetPermutation(TagGbxmodel* model, Vehicle* vehicle, const(char)[] name, bool doset)
    {
        foreach(int i, ref region ; model.regions)
        {
            foreach(int j, ref permutation ; region.permutations)
            {
                if(iequals(name, permutation.name))
                {
                    vehicle.regionPermutationIndices[i] = doset ? j : 0;
                    break;
                }
            }
        }
    }

    bool shouldBlur = abs(speed) >= tagVehicle.blurSpeed;

    if(shouldBlur != flags.blur)
    {
        flags.blur = shouldBlur;
        modelSetPermutation(tagModel, &this, "~blur", shouldBlur);
    }

    return true;
}

bool implProcessOrientations(Orientation* orientations)
{
    auto tagVehicle    = Cache.get!TagVehicle(tagIndex);
    auto tagAnimations = Cache.get!TagModelAnimations(tagVehicle.animationGraph);

    if(tagAnimations.vehicles)
    {
        auto animations = &tagAnimations.vehicles.animations;

        if(animations.inUpperBound(TagEnums.VehicleAnimation.steering))
        {
            int index = (*animations)[TagEnums.VehicleAnimation.steering].animation;

            if(index != indexNone)
            {
                auto anim = &tagAnimations.animations[index];

                anim.decodeOverlayAim(*tagAnimations.vehicles.ptr, wheelSteering, 0.0f, orientations);
            }
        }

        if(animations.inUpperBound(TagEnums.VehicleAnimation.groundSpeed))
        {
            int index = (*animations)[TagEnums.VehicleAnimation.groundSpeed].animation;

            if(index != indexNone)
            {
                auto animation = &tagAnimations.animations[index];

                float percent = tagVehicle.wheelCircumference <= 0.0f
                    ? 0.0f
                    : wheelPosition / tagVehicle.wheelCircumference;

                int first = min(cast(int)(animation.frameCount * percent), animation.frameCount - 1);
                int second = (first + 1) % animation.frameCount;

                percent = fmod(animation.frameCount * percent, 1.0f);
                animation.decodeOverlayMix(first, second, percent, orientations);
            }
        }

        foreach(i, ref suspension ; tagAnimations.vehicles.suspensionAnimations)
        {
            // todo needs better implementation (animation None check + suspension may have more than 1 frame)
            auto animation = &tagAnimations.animations[suspension.animation];
            animation.decodeOverlayMix(0, 1, suspensionPositions[i], orientations);
        }
    }

    return true;
}

bool implUpdateImportFunctions()
{
    const tagVehicle = Cache.get!TagVehicle(tagIndex);

    const float maxForwardSpeed = abs(tagVehicle.maximumForwardSpeed);
    const float maxReverseSpeed = abs(tagVehicle.maximumReverseSpeed);

    const float maxLeftSlide  = abs(tagVehicle.maximumLeftSlide);
    const float maxRightSlide = abs(tagVehicle.maximumRightSlide);

    const float maxLeftTurn  = abs(tagVehicle.maximumLeftTurn);
    const float maxRightTurn = abs(tagVehicle.maximumRightTurn);

    const float absMaxSpeed = max(maxForwardSpeed, maxReverseSpeed);
    const float absMaxSlide = max(maxLeftSlide,    maxRightSlide);
    const float absMaxTurn  = max(maxLeftTurn,     maxRightTurn);

    foreach(i ; 0 .. TagConstants.Object.maxFunctions)
    {
        TagEnums.VehicleImport type;

        switch(i)
        {
        case 0: type = tagVehicle.aIn; break;
        case 1: type = tagVehicle.bIn; break;
        case 2: type = tagVehicle.cIn; break;
        case 3: type = tagVehicle.dIn; break;
        default: continue;
        }

        float value = 0.0f;

        switch(type)
        {
        case TagEnums.VehicleImport.none:
            continue;
        case TagEnums.VehicleImport.frontLeftTireVelocity:
        case TagEnums.VehicleImport.frontRightTireVelocity:
        case TagEnums.VehicleImport.backLeftTireVelocity:
        case TagEnums.VehicleImport.backRightTireVelocity:
        case TagEnums.VehicleImport.speedAbsolute:
            value = abs(speed) / absMaxSpeed;
            break;
        case TagEnums.VehicleImport.speedForward:
            if(speed > 0.0f) value = speed / maxForwardSpeed;
            else             value = 0.0f;
            break;
        case TagEnums.VehicleImport.speedBackward: value = abs(speed) / maxReverseSpeed;
            if(speed < 0.0f) value = abs(speed) / maxReverseSpeed;
            else             value = 0.0f;
            break;

        case TagEnums.VehicleImport.slideAbsolute: assert(0); break; // TODO
        case TagEnums.VehicleImport.slideLeft:     assert(0); break; // TODO
        case TagEnums.VehicleImport.slideRight:    assert(0); break; // TODO
        case TagEnums.VehicleImport.speedSlideMaximum: assert(0); break; // TODO

        case TagEnums.VehicleImport.turnAbsolute: value = abs(wheelSteering) / absMaxTurn;   break;
        case TagEnums.VehicleImport.turnLeft:     value = abs(wheelSteering) / maxLeftTurn;  break;
        case TagEnums.VehicleImport.turnRight:    value = abs(wheelSteering) / maxRightTurn; break;

        case TagEnums.VehicleImport.crouch: assert(0); break; // TODO
        case TagEnums.VehicleImport.jump:
            if(flags.brakes) value = 1.0f;
            else             value = 0.0f;
            break;
        case TagEnums.VehicleImport.walk:
            break;
        case TagEnums.VehicleImport.velocityAir:    value = length(velocity) / absMaxSpeed; break;
        case TagEnums.VehicleImport.velocityWater:  assert(0); break; // TODO
        case TagEnums.VehicleImport.velocityGround: assert(0); break;
        case TagEnums.VehicleImport.velocityForward:    value = dot(rotation.forward, velocity) / absMaxSpeed;      break;
        case TagEnums.VehicleImport.velocityLeft:
        case TagEnums.VehicleImport.velocityUp:         value = dot(rotation.up, velocity) / absMaxSpeed;           break;
        case TagEnums.VehicleImport.leftTreadPosition:  value = leftTreadPosition  / tagVehicle.wheelCircumference; break;
        case TagEnums.VehicleImport.rightTreadPosition: value = rightTreadPosition / tagVehicle.wheelCircumference; break;
        case TagEnums.VehicleImport.leftTreadVelocity:
            assert(0); // TODO
            break;
        case TagEnums.VehicleImport.rightTreadVelocity:
            assert(0); // TODO
            break;
        case TagEnums.VehicleImport.frontLeftTirePosition:
        case TagEnums.VehicleImport.frontRightTirePosition:
        case TagEnums.VehicleImport.backLeftTirePosition:
        case TagEnums.VehicleImport.backRightTirePosition:
            value = wheelPosition / tagVehicle.wheelCircumference;
            break;
        case TagEnums.VehicleImport.wingtipContrail:
            // TODO
            break;
        case TagEnums.VehicleImport.hover:
            value = hover;
            break;
        case TagEnums.VehicleImport.thrust:
            // TODO
            break;
        case TagEnums.VehicleImport.engineHack:
            float throttle = abs(dot(velocity, rotation.forward)) / absMaxSpeed;
            float speed    = abs(speed) / maxForwardSpeed;
            float airborne = clamp((ticksInAir * 0.2f + 1.0f) * 0.5f, 0.0f, 1.0f);

            value = throttle * (1.0f - airborne) + airborne * speed;
            break;
        case TagEnums.VehicleImport.wingtipContrailNew:
            // TODO
            break;
        default: value = 0.0f;
        }

        importFunctionValues[i] = clamp(value, 0.0f, 1.0f);

    }

    return true;
}

void doGenericPhysics(
    TagVehicle*                 tagVehicle,
    TagPhysics*                 tagPhysics,
    const(PoweredMassControl)[] poweredControls,
    MassPointData[]             massPointData,
    Vec3                        externalForce = Vec3(0.0f),
    Vec3                        externalAngularForce = Vec3(0.0f))
{
    static float calcNormal(float k0, float k1, float normal)
    {
        float kmin = min(k0, k1);
        float kmax = max(k0, k1);

        if(normal <= kmin) return 0.0f;
        if(normal >= kmax) return 1.0f;

        return (normal - kmin) / (kmax - kmin);
    }

    static void massPointFriction(ref Tag.MassPointBlock massPoint, ref Vec3 force, Vec3 forward, Vec3 up)
    {
        Vec3 direction;

        switch(massPoint.frictionType)
        {
        case TagEnums.PhysicsFrictionType.forward: direction = forward; break;
        case TagEnums.PhysicsFrictionType.up:      direction = up;      break;
        case TagEnums.PhysicsFrictionType.left:    direction = cross(up, forward); break;
        default: return;
        }

        Vec3 frictionForce = dot(force, direction) * direction;
        Vec3 extraForce    = force - frictionForce;

        frictionForce *= massPoint.frictionParallelScale;
        extraForce    *= massPoint.frictionPerpendicularScale;

        force = frictionForce + extraForce;
    }

    Transform transform = Transform(rotation.toMat3(), position);
    transform.position += transform.mat3 * -tagPhysics.centerOfMass;

    Vec3 force        = Vec3(0, 0, tagPhysics.mass * -(gameGravity * tagPhysics.gravityScale));
    Vec3 angularForce = Vec3(0);

    foreach(i, ref massPoint ; tagPhysics.massPoints)
    {
        auto data = &massPointData[i];

        auto poweredMassPoint = massPoint.poweredMassPoint != indexNone && poweredControls
            ? &tagPhysics.poweredMassPoints[massPoint.poweredMassPoint]
            : null;

        const(PoweredMassControl)* poweredData = poweredMassPoint
            ? &poweredControls[massPoint.poweredMassPoint]
            : null;

        data.scaledTotalVelocity = Vec3(0);
        data.responseForce       = Vec3(0);
        data.scaledForce         = Vec3(0);
        data.airFrictionForce    = Vec3(0);
        data.antigravForce       = Vec3(0);

        data.position = transform * massPoint.position;

        if(poweredData)
        {
            data.forward = poweredData.turn * transform.mat3 * massPoint.forward;
            data.up      = poweredData.turn * transform.mat3 * massPoint.up;
        }
        else
        {
            data.forward = transform.mat3 * massPoint.forward;
            data.up      = transform.mat3 * massPoint.up;
        }

        data.direction = data.position - position;
        data.totalVelocity = velocity + cross(rotationalVelocity, data.direction);

        World.MassPointResult result = void;
        GObjectTypeMask mask = GObjectTypeMask(TagEnums.ObjectType.scenery);

        bool hit = world.collideMassPoint(&this.object, data.position, massPoint.radius, mask, result);

        // todo fog cluster stuff

        if(hit && result.distance > 0.0f)
        {
            auto globals = Cache.inst.globals;

            float depth = tagPhysics.groundDepth;
            float damp = tagPhysics.groundDampFraction;
            float normalk1 = tagPhysics.groundNormalK1;
            float normalk0 = tagPhysics.groundNormalK0;
            float friction = tagPhysics.groundFriction;

            if(result.surface.materialIndex != indexNone)
            {
                // todo object collision material

                int id = result.sbsp.collisionMaterials[result.surface.materialIndex].materialType;

                if(id >= 0 && id < globals.materials.size)
                {
                    auto material = &globals.materials[id];

                    if(material.groundDepthScale            != 0.0f) depth    *= material.groundDepthScale;
                    if(material.groundDampFractionScale     != 0.0f) damp     *= material.groundDampFractionScale;
                    if(material.groundFrictionNormalK1Scale != 0.0f) normalk1 *= material.groundFrictionNormalK1Scale;
                    if(material.groundFrictionNormalK0Scale != 0.0f) normalk0 *= material.groundFrictionNormalK0Scale;
                    if(material.groundFrictionScale         != 0.0f && tagPhysics.mass < groundFrictionCutoffMass)
                        friction *= material.groundFrictionScale;
                }
            }

            float magnitude = dot(result.plane.normal, data.totalVelocity);
            float forceMagnitude = tagPhysics.mass * ((result.distance / depth) * gameGravity - magnitude * damp);
            float negativeMassFriction = -(massPoint.mass * friction);

            data.responseForce = result.plane.normal * forceMagnitude;
            data.scaledTotalVelocity = data.totalVelocity - (magnitude * result.plane.normal);
            data.scaledForce = data.scaledTotalVelocity * negativeMassFriction;

            if(poweredMassPoint && poweredMassPoint.flags.groundFriction)
            {
                if(poweredData.speed != 0.0f)
                {
                    float traction = calcNormal(normalk0, normalk1, result.plane.normal.z);
                    float surface = clamp(dot(result.plane.normal, data.up), 0.0f, 1.0f);

                    float poweredForce = negativeMassFriction * (sqr(traction) * sqr(surface));

                    Vec3 velocity = -poweredData.speed * data.forward;
                    Vec3 scaled = velocity - dot(velocity, result.plane.normal) * result.plane.normal;

                    data.scaledTotalVelocity += scaled;
                    data.scaledForce += scaled * poweredForce;

                    // todo powered mass point throttle
                }
            }

            massPointFriction(massPoint, data.scaledForce, data.forward, data.up);
        }

        if(false) // todo check distance to fog
        {
            // todo fog related friction

            if(poweredMassPoint && poweredMassPoint.flags.waterFriction)
            {
                // todo powered water friction
            }

            // todo water friction
        }

        if(poweredMassPoint && poweredMassPoint.flags.airFriction)
        {
            // todo powered air friction
        }
        else
        {
            data.airFrictionForce = data.totalVelocity * -(massPoint.mass * tagPhysics.airFriction);
        }

        massPointFriction(massPoint, data.airFrictionForce, data.forward, data.up);

        if(poweredMassPoint && poweredMassPoint.flags.airLift)
        {
            // todo air lift, is this even used?
        }

        data.flags.resting  = dot(data.totalVelocity, data.totalVelocity) < speedSquareSleepCutoff;
        data.flags.grounded = result.distance > 0.0f;
        data.flags.drowning = false; // todo water flag
        data.flags.antigrav = false;

        if(poweredMassPoint)
        {
            if(poweredMassPoint.flags.thrust)
            {
                // todo thrust
            }

            if(poweredMassPoint.flags.antigrav)
            {
                float gravityLength   = poweredMassPoint.antigravHeight + massPoint.radius;
                Vec3  poweredVelocity = Vec3(0, 0, -gravityLength);

                World.LineResult  r = void;
                World.LineOptions options;

                options.structure = true;
                options.objects   = true;

                // todo object / surface type bit mask
                if(world.collideLine(&this.object, data.position, poweredVelocity, options, r))
                {
                    gravityLength = gravityLength * r.percent - massPoint.radius;

                    float normal = calcNormal(poweredMassPoint.antigravNormalK0,
                        poweredMassPoint.antigravNormalK1, data.up.z);

                    float power = gravityLength > 0.0f
                        ? 1.0f - gravityLength / poweredMassPoint.antigravHeight
                        : 1.0f;


                    power = power * power * gameGravity;
                    power -= poweredMassPoint.antigravDampFraction * dot(data.totalVelocity, r.plane.normal);
                    power *= poweredData.hover * poweredMassPoint.antigravStrength * tagPhysics.mass * normal;

                    data.antigravForce += power * r.plane.normal;

                    data.flags.antigrav = true;

                    // todo anti gravity
                }
            }
        }


        Vec3 collectiveForce
            = data.responseForce
            + data.scaledForce
            // + data.fogRelatedForce // todo - fog related friction
            + data.airFrictionForce
            + data.antigravForce;

        angularForce += cross(data.direction, collectiveForce);
        force += collectiveForce;

        // todo spherical physics

    }

    force        += externalForce + vehicleCollisionForce;
    angularForce += externalAngularForce + vehicleCollisionAngularForce;

    vehicleCollisionForce        = Vec3(0.0f);
    vehicleCollisionAngularForce = Vec3(0.0f);

    Mat3 inertia = transform.mat3 * *cast(Mat3*)&tagPhysics.inertialMatrixAndInverse[1] * transpose(transform.mat3);

    Vec3 addedVelocity = force / tagPhysics.mass;
    Vec3 addedAngularVelocity = transpose(inertia) * angularForce;

    velocity += addedVelocity;
    rotationalVelocity += addedAngularVelocity;

    Vec3 endPosition = position + velocity;

    Vec3 forward;
    Vec3 up;

    // todo - requires rearranging
    // need endposition to be transformed by rotation at end as well as for each iteration.
    for(int i = 0; i < vehicleLinePhysicsIterations; ++i)
    {
        {
            Mat3 rot = Mat3.fromEuler(rotationalVelocity);

            forward = rot * rotation.forward;
            up      = rot * rotation.up;
        }

        Mat3 rotationMatrix = Mat3.fromPerpUnitVectors(forward, up);
        Vec3 centerOfMass   = rotationMatrix * -tagPhysics.centerOfMass + endPosition;

        if(tagPhysics.massPoints.size)
        {
            bool foundCollision = false;

            Vec3 bestVelocity;
            World.LineResult bestResult = void;

            foreach(j, ref massPoint ; tagPhysics.massPoints)
            {
                auto data = &massPointData[j];

                Vec3 pointPosition = rotationMatrix * massPoint.position + centerOfMass;
                Vec3 lastPointPosition = data.position;
                Vec3 pointVelocity = pointPosition - lastPointPosition;

                World.LineResult  result = void;
                World.LineOptions options;

                options.structure = true;
                options.objects   = true;
                options.objectTypes = GObjectTypeMask(TagEnums.ObjectType.scenery);

                if(world.collideLine(&this.object, lastPointPosition, pointVelocity, options, result))
                {
                    if(!foundCollision || result.percent < bestResult.percent)
                    {
                        foundCollision = true;
                        bestResult = result;
                        bestVelocity = pointVelocity;
                    }
                }
            }

            if(!foundCollision)
            {
                this.move(endPosition, forward, up);
                break;
            }

            float d = dot(bestVelocity, bestResult.plane.normal);

            // todo fix magic numbers
            if(d < 0.0f) d = 0.0078125f / abs(d);
            else         d = 0.03125f;

            d = max(bestResult.percent - d, 0.0f);

            float dd = dot(velocity, bestResult.plane.normal);

            if(dd < 0.0f)
            {
                velocity += (d - 1.0f) * dd * bestResult.plane.normal;
                endPosition = position + velocity;
            }

            rotationalVelocity *= d;
        }
    }

    int sleepingCount = 0;
    int groundedCount = 0;
    int drowningCount = 0;

    foreach(i, ref massPoint ; tagPhysics.massPoints)
    {
        auto data = &massPointData[i];

        if(data.flags.resting)   ++sleepingCount;
        if(data.flags.grounded)  ++groundedCount;
        if(data.flags.drowning)  ++drowningCount;
    }

    flags.sleeping =
        sleepingCount == tagPhysics.massPoints.size
        && groundedCount >= numJeepPointsOnGroundSleep
        && drowningCount == 0
        && lengthSqr(velocity) <= speedSquareSleepCutoff
        && lengthSqr(addedVelocity)        <= 3.08642e-7f
        && lengthSqr(rotationalVelocity)   <= 2.74156e-3f
        && lengthSqr(addedAngularVelocity) <= 3.04617e-6;

    flags.grounded = groundedCount != 0;

    if(tagVehicle.physics)
    {
        doVehiclePhysicsToObject(tagVehicle, tagPhysics);
    }
}

void doVehiclePhysicsToObject(TagVehicle* tagVehicle, TagPhysics* tagPhysics)
{
    Transform transform = Transform(rotation.toMat3(), position);
    transform.position += transform.mat3 * -tagPhysics.centerOfMass;

    GObjectTypeMask mask = TagEnums.ObjectType.vehicle;

    if(tagVehicle.collisionModel)
    {
        mask.set(TagEnums.ObjectType.biped);
    }

    GObject*[TagConstants.Vehicle.maxCollisionObjects] objects = void;

    int num = world.calculateNearbyObjects(World.ObjectSearchType.collideable, mask,
        location, bound, objects.ptr, objects.length);

    foreach(i ; 0 .. num)
    {
        switch(objects[i].type)
        {
        default: continue;
        case TagEnums.ObjectType.biped:
            // todo implement biped - vehicle collision
            break;
        case TagEnums.ObjectType.vehicle:
        {
            if(objects[i] == &this.object)
            {
                continue;
            }

            static struct Other
            {
                TagVehicle* tagVehicle;
                TagPhysics* tagPhysics;

                Vehicle* vehicle;
                Transform transform;
            }

            Other other = void;

            other.vehicle = cast(Vehicle*)objects[i];
            other.tagVehicle = Cache.get!TagVehicle(other.vehicle.tagIndex);
            other.tagPhysics = Cache.get!TagPhysics(other.tagVehicle.physics);

            if(!other.tagPhysics)                 continue;
            if(!other.tagPhysics.massPoints.size) continue;

            other.transform = Transform(other.vehicle.rotation.toMat3(), other.vehicle.position);
            other.transform.position += other.transform.mat3 * -other.tagPhysics.centerOfMass;

            float massAverage = sqrt(tagPhysics.mass * other.tagPhysics.mass);

            Vec3 totalForce        = 0.0f;
            Vec3 totalAngularForce = 0.0f;

            Vec3 otherTotalForce        = 0.0f;
            Vec3 otherTotalAngularForce = 0.0f;

            bool hit = false;

            foreach(j, ref massPoint ; tagPhysics.massPoints)
            {
                Vec3 pointPosition = transform * massPoint.position;

                foreach(k, ref otherMassPoint ; other.tagPhysics.massPoints)
                {
                    Vec3 otherPosition = other.transform * otherMassPoint.position;

                    float totalRadius = massPoint.radius + otherMassPoint.radius;

                    Vec3  normal = otherPosition - pointPosition;
                    float length = normalize(normal);

                    if(length == 0.0f)       continue;
                    if(length > totalRadius) continue;

                    float distance = 0.5f * (totalRadius - length);
                    float gravity = gameGravity * 5.0f;

                    float mass = massAverage * gravity * 2.0f * distance;

                    Vec3 force      = -mass * normal;
                    Vec3 otherForce = mass * normal;

                    Vec3 collisionPoint = pointPosition + normal * (massPoint.radius - distance);

                    Vec3 centerToCollision      = collisionPoint - position;
                    Vec3 otherCenterToCollision = collisionPoint - other.vehicle.position;

                    totalForce += force;
                    totalAngularForce += cross(centerToCollision, force);

                    otherTotalForce += otherForce;
                    otherTotalAngularForce += cross(otherCenterToCollision, otherForce);

                    // todo verify this is accurate

                    hit = true;
                }
            }

            if(hit)
            {
                vehicleCollisionForce        += totalForce;
                vehicleCollisionAngularForce += totalAngularForce;

                other.vehicle.vehicleCollisionForce        += otherTotalForce;
                other.vehicle.vehicleCollisionAngularForce += otherTotalAngularForce;

                other.vehicle.flags.sleeping = false;
            }

            break;
        }
        }
    }
}

void applyForce(Vec3 force)
{
    const tagVehicle = Cache.get!TagVehicle(tagIndex);

    if(!tagVehicle.physics)
    {
        return;
    }

    velocity += force;

    Vec3 perp = cross(Vec3(0, 0, 1), force);
    float length = normalize(perp);

    if(length != 0.0f)
    {
        rotationalVelocity += (length * PI) * perp;
    }

    flags.sleeping = false;

}

}
