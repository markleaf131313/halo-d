
module Game.World.Effects.Particle;

import std.bitmanip : bitfields;

import Game.World.Objects;
import Game.World.World : World, SheepGObjectPtr;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Particle
{
@nogc nothrow:

struct Creation
{
    DatumIndex tagIndex;
    GObject* object;

    int nodeIndex        = indexNone;
    int localPlayerIndex = indexNone;

    bool isNodeFirstPerson;
    bool isThirdPersonOnly;
    bool isFirstPersonOnly;

    Vec3 offset;
    Vec3 direction;
    Vec3 velocity;

    float angle           = 0.0f;
    float angularVelocity = 0.0f;
    float radius;

    ColorArgb tint;
}

enum Stage
{
    initial,
    looping,
    ending,
    next,
}

struct Flags
{
    mixin(bitfields!(
        bool, "animateBackwards",   1,
        bool, "resting",            1,
        bool, "mirrorHorizontally", 1,
        bool, "mirrorVertically",   1,
        bool, "_bit4_x10",          1,
        bool, "_bit5_x20",          1,
        bool, "_bit6_x40",          1,
        bool, "_bit7_x80",          1,
        bool, "isThirdPerson",      1,
        bool, "isFirstPerson",      1,
        bool, "isNodeFirstPerson",  1,
        bool, "spriteInit",         1,
        uint, "", 20,
    ));
}

DatumIndex selfIndex;
World*     world;

Flags flags;
DatumIndex tagIndex;
SheepGObjectPtr object;

int nodeIndex;
int localPlayerIndex;

Stage stage;

float life;
float lifespan;

float animationTime;
float animationRate;

int sequenceIndex;
int spriteIndex;

World.Location location;

Vec3 position;
Vec3 direction;
Vec3 velocity;

float angle;
float angularVelocity;

float radius;
ColorArgb tint;

void updateLogic(float deltaTime)
{
    const tagParticle = Cache.get!TagParticle(tagIndex);

    float previousLife = life;

    life += deltaTime;

    if(life < lifespan || previousLife == 0.0f || tagParticle.finalSequenceCount)
    {
        if(updateAnimation(deltaTime))
        {
            updatePointPhysics(deltaTime);
        }
    }
    else
    {
        removeSelfWithDeathEffect();
    }
}

bool advanceSequence()
{
    const tagParticle = Cache.get!TagParticle(tagIndex);
    const tagBitmap   = Cache.get!TagBitmap(tagParticle.bitmap);

    sequenceIndex = indexNone;

    if(stage == Stage.init)
    {
        if(tagParticle.initialSequenceCount > 0)
        {
            sequenceIndex = tagParticle.firstSequenceIndex + randomValueFromZero(tagParticle.initialSequenceCount);
        }

        stage = Stage.looping;
    }

    if(sequenceIndex == indexNone && stage == Stage.looping)
    {
        stage = Stage.ending;
    }

    if(stage == Stage.looping)
    {
        if(life >= lifespan || tagParticle.loopingSequenceCount <= 0)
        {
            stage = Stage.ending;
        }
        else
        {
            sequenceIndex
                = tagParticle.firstSequenceIndex
                + tagParticle.initialSequenceCount
                + randomValueFromZero(tagParticle.loopingSequenceCount);
        }
    }

    if(sequenceIndex == indexNone && stage == Stage.ending)
    {
        if(tagParticle.finalSequenceCount > 0)
        {
            sequenceIndex
                = tagParticle.firstSequenceIndex
                + tagParticle.initialSequenceCount
                + tagParticle.loopingSequenceCount
                + randomValueFromZero(tagParticle.finalSequenceCount);
        }

        stage = Stage.next;
    }

    if(sequenceIndex != indexNone && tagBitmap.sequences.size != 0)
    {
        if(sequenceIndex >= 0)
        {
            sequenceIndex = min(sequenceIndex, tagBitmap.sequences.size - 1);
        }
        else
        {
            sequenceIndex = 0;
        }

        return true;
    }

    removeSelfWithDeathEffect();

    return false;
}

bool advanceSprite()
{
    const tagParticle = Cache.get!TagParticle(tagIndex);
    const tagBitmap   = Cache.get!TagBitmap(tagParticle.bitmap);

    if(flags.animateBackwards)
    {
        if(spriteIndex <= 0)
        {
            if(advanceSequence())
            {
                spriteIndex = tagBitmap.sequences[sequenceIndex].sprites.size - 1;
                return true;
            }

            return false;
        }
        else
        {
            spriteIndex -= 1;
            return true;
        }
    }

    if(spriteIndex + 1 >= tagBitmap.sequences[sequenceIndex].sprites.size)
    {
        if(advanceSequence())
        {
            spriteIndex = 0;
            return true;
        }

        return false;
    }
    else
    {
        spriteIndex += 1;
        return true;
    }
}

bool updateAnimation(float delta)
{
    const tagParticle = Cache.get!TagParticle(tagIndex);

    if(tagParticle.flags.animationStopsAtRest && flags.resting)
    {
        return true;
    }

    if(tagParticle.flags.animateOncePerFrame)
    {
        if(delta != 0.0f)
        {
            animationTime = 0.0f;
            return advanceSprite();
        }

        return true;
    }

    bool result = true;

    if(!flags.spriteInit)
    {
        flags.spriteInit = true;

        animationTime = 0.0f;
        result = advanceSprite();
    }

    while(result && delta > 0.0f)
    {
        if(animationRate - animationTime > delta)
        {
            animationTime += delta;
            break;
        }

        result = advanceSprite();
        delta -= animationRate;
    }

    return result;
}

bool updatePointPhysics(float deltaTime)
{
    if(flags.resting)
    {
        if(object && object.ptr is null)
        {
            world.particles.remove(selfIndex);
            return false;
        }

        return true;
    }

    const tagParticle     = Cache.get!TagParticle(tagIndex);
    const tagPointPhysics = Cache.get!TagPointPhysics(tagParticle.physics);

    bool canRest;

    if(object)
    {
        if(object.ptr is null && !flags._bit6_x40)
        {
            world.particles.remove(selfIndex);
            return false;
        }

        float radius = getRadiusAnimation();

        float mass     = tagPointPhysics.densityInWorldUnits * radius * radius * radius;
        float friction = tagPointPhysics.airFriction * radius * radius;

        float scale;

        if(mass == 0.0f)
        {
            if(friction != 0.0f) scale = 0.0f;
            else                 scale = 1.0f;
        }
        else
        {
            scale = clamp(1.0f - friction / mass * deltaTime, 0.0f, 1.0f);
        }

        velocity *= scale;
        position += velocity * deltaTime;

        canRest = true;

    }
    else
    {
        float radius = getRadiusAnimation();

        World.PointPhysicsResult pp = void;

        world.collidePointPhysics(tagPointPhysics, position, velocity, radius, deltaTime, pp);

        position = pp.position;
        velocity = pp.velocity;
        location = pp.location;

        if(pp.hitStructureOrObject)
        {

            if(tagParticle.collisionEffect || tagParticle.martyTradedHisKidsForThis)
            {
                float scale = clamp(length(velocity) - 0.5f, 0.0f, 1.0f);

                if(tagParticle.collisionEffect)
                {
                    createEffectOrSound(tagParticle.collisionEffect, scale);
                }

                if(tagParticle.martyTradedHisKidsForThis)
                {
                    assert(0); // TODO
                }
            }
        }

        if(    (pp.hitStructureOrObject && tagParticle.flags.diesOnContactWithStructure)
            || (pp.inAir                && tagParticle.flags.diesOnContactWithAir)
            || (pp.inWater              && tagParticle.flags.diesOnContactWithWater))
        {
            removeSelfWithDeathEffect();
            return false;
        }

        if(pp.hitStructureOrObject || pp.hitWater)
        {
            if(pp.plane.normal.z > 0.8f)
            {
                canRest = true;
            }

            animationRate += tagParticle.contactDeterioration;
        }
    }

    if(lengthSqr(velocity) < TagConstants.Particle.restingThreshold)
    {
        if(canRest)
        {
            if(tagParticle.flags.diesAtRest)
            {
                removeSelfWithDeathEffect();
                return false;
            }

            flags.resting = true;
        }
    }
    else
    {
        direction = velocity;
    }

    angle += angularVelocity * deltaTime;

    return true;
}

private
float getRadiusAnimation() const
{
    return radius * Cache.get!TagParticle(tagIndex).radiusAnimation.mix(life / lifespan);
}

private
void removeSelfWithDeathEffect()
{
    createEffectOrSound(Cache.get!TagParticle(tagIndex).deathEffect, 0.0f);
    world.particles.remove(selfIndex);
}

private
void createEffectOrSound(ref const TagRef tagRef, float scale)
{
    if(tagRef.index == DatumIndex.none)
    {
        return;
    }

    switch(tagRef.id)
    {
    case TagId.effect:
    {
        const tagEffect = Cache.get!TagEffect(tagRef);

        Vec3 velocityDirection = velocity;
        normalize(velocityDirection);

        World.EffectMarker[2] markers =
        [
            {
                name: "velocity",
                position: position,
                direction: velocityDirection,
            },
            {
                name: "gravity",
                position: position,
                direction: Vec3(0, 0, -1),
            },
        ];

        world.createEffect(tagRef.index, null, markers, velocity, scale, 0.0f);
        break;
    }
    case TagId.sound:
        // TODO(IMPLEMENT)
        break;
    default:
    }
}

}
