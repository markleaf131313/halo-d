
module Game.World.Effects.Effect;

import std.bitmanip : bitfields;
import std.typecons : Tuple;

import Game.World.Effects.Particle;

import Game.World.FirstPerson : FirstPerson;
import Game.World.Objects : GObject;
import Game.World.World   : World, SheepGObjectPtr;

import Game.Audio;
import Game.Cache;
import Game.Core;
import Game.Tags;

struct Effect
{
@nogc nothrow:

struct Location
{
    @disable this(this);

    bool isFirstPerson;
    int nodeIndex;
    Location* next;
    Transform transform;

    @nogc nothrow ~this()
    {
        destroyFree(next);
    }
}

struct ObjectFunctionIndices
{
    int primaryScale;
    int secondaryScale;
    int changeColor;
}

struct Flags
{
    // TODO(REFACTOR) names of these flags needs to be corrected.
    mixin(bitfields!(
        bool, "eventInitialized", 1,
        bool, "_bit1_x02",        1, // exists even if deactivation ?
        bool, "_bit2_x04",        1,
        bool, "_bit3_x08",        1, // set when terminated and bit1_x02 is set
        bool, "deactivated",      1,
        bool, "_bit5_x20",        1,
        bool, "nonviolent",       1,
        ushort, "", 9,
    ));
}

DatumIndex selfIndex;
World* world;

Flags      flags;
DatumIndex tagIndex;

World.Location location;

int primaryScaleIndex   = indexNone;
int secondaryScaleIndex = indexNone;
int changeColorIndex    = indexNone;

ColorRgb color = ColorRgb(1.0f, 1.0f, 1.0f);
Vec3     velocity;

SheepGObjectPtr parent;         // object this effect is attached to
SheepGObjectPtr creationObject; // object that caused the creation of this effect

float scaleA;
float scaleB;

int localPlayerIndex = indexNone;
int eventIndex;

float time;
float eventDelayTime;
float lastTimePercent; // value of (time / eventDelayTime) from the last time particles were created

Location*[TagConstants.Effect.maxLocations] eventLocations;
ubyte[TagConstants.Effect.maxParticlesPerEvent] particleCounts;

~this()
{
    foreach(location ; eventLocations)
    {
        destroyFree(location);
    }
}

void createLocations(
    scope int delegate(const(char)[], Tuple!(int, Transform)[]) @nogc nothrow findMarker,
    bool isFirstPerson)
{
    const tagEffect = Cache.get!TagEffect(tagIndex);

    foreach(i, ref tagLocation ; tagEffect.locations)
    {
        Tuple!(int, Transform)[TagConstants.Model.maxLocationsPerMarker] markers = void;

        int count = findMarker(tagLocation.markerName, markers);

        foreach(ref marker ; markers[0 .. count])
        {
            Location* location = mallocCast!Location(Location.sizeof);

            location.next     = eventLocations[i];
            eventLocations[i] = location;

            location.isFirstPerson = isFirstPerson;
            location.nodeIndex     = marker[0];
            location.transform     = marker[1];
        }
    }
}

void updateEvents(float deltaTime)
{
    const TagEffect* tagEffect = Cache.get!TagEffect(tagIndex);

    if(parent)
    {
        if(GObject* object = parent.ptr)
        {
            const GObject* absoluteObject = object.getAbsoluteParent();

            location = World.Location();

            if(absoluteObject.flags.connectedToMap)
            {
                location = absoluteObject.location;
                velocity = absoluteObject.velocity;
            }

            if(flags._bit1_x02)
            {
                // TODO(IMPLEMENT) sets scales a/b and a bunch of other stuff
            }
        }
        else
        {
            world.effects.remove(selfIndex);
            return;
        }
    }

    if(location.cluster == indexNone)
    {
        world.effects.remove(selfIndex);
        return;
    }

    bool isActive = false;

    if(tagEffect.flags.unknownCompileTimeFlag2)
    {
        // TODO(IMPLEMENT) uses different bitarray for checking of cluster is active
        isActive = true;
    }
    else
    {
        // TODO(IMPLEMENT) check cluster is active
        isActive = true;
    }

    if(isActive)
    {
        flags.deactivated = false;
    }
    else if(!flags.deactivated)
    {
        if(!flags._bit1_x02)
        {
            world.effects.remove(selfIndex);
            return;
        }

        flags.deactivated = true;
    }

    for(int i = 0; deltaTime >= 0.0f; ++i)
    {
        if(flags._bit3_x08 || i >= 8)
        {
            break;
        }

        bool  eventTriggered;
        float diff = eventDelayTime - time;

        if(diff > deltaTime)
        {
            eventTriggered = false;

            time += deltaTime;
            deltaTime = -float.max;
        }
        else
        {
            eventTriggered = true;

            time = eventDelayTime;
            deltaTime -= diff;
        }

        if(flags.eventInitialized)
        {
            if(!flags.deactivated)
            {
                createParticles();
            }

            if(eventTriggered)
            {
                int nextEventIndex = eventIndex + 1;

                if(flags._bit1_x02 && eventIndex == tagEffect.loopStopEvent && tagEffect.loopStartEvent != indexNone)
                {
                    nextEventIndex = tagEffect.loopStartEvent;
                }

                for( ; nextEventIndex < tagEffect.events.size; ++nextEventIndex)
                {
                    // TODO(IMPLEMENT, RANDOM, EFFECT) secondary random seed, used based on tagEffect flag
                    if(randomPercent() >= tagEffect.events[nextEventIndex].skipFraction)
                    {
                        break;
                    }
                }

                if(nextEventIndex < tagEffect.events.size)
                {
                    setEventIndex(nextEventIndex);
                }
                else if(flags._bit1_x02)
                {
                    flags._bit3_x08 = true;
                    return;
                }
                else
                {
                    world.effects.remove(selfIndex);
                    return;
                }
            }
        }
        else if(eventTriggered)
        {
            auto tagEvent = &tagEffect.events[eventIndex];

            flags.eventInitialized = true;

            time            = 0.0f;
            eventDelayTime  = randomValue(tagEvent.durationBounds);
            lastTimePercent = -1.0f;

            foreach(j, ref tagParticle ; tagEvent.particles)
            {
                float count = randomScaledValue!"count"(tagParticle, tagParticle.count.lower, tagParticle.count.upper);
                particleCounts[j] = cast(ubyte)min(count, ubyte.max);
            }

            if(!flags.deactivated)
            {
                createParts();
            }
        }
    }
}

void setEventIndex(int index)
{
    const tagEffect = Cache.get!TagEffect(tagIndex);

    if(index >= 0 && index < tagEffect.events.size)
    {
        flags.eventInitialized = false;
        eventIndex = index;
        time = 0.0f;
        eventDelayTime = randomValue(tagEffect.events[index].delayBounds);
    }
}

private
void createParts()
{
    const TagEffect* tagEffect = Cache.get!TagEffect(tagIndex);
    const tagEvent = &tagEffect.events[eventIndex];

    foreach(i, ref tagPart ; tagEvent.parts)
    {
        foreach(ref Location location;
            rangeOfLocations(tagPart.location, TagEnums.CreationPerspective.independentOfCameraMode))
        {
            Transform transform;

            if(location.nodeIndex == indexNone)
            {
                transform = location.transform;
            }
            else
            {
                transform = getLocationTransform(location) * location.transform;
            }

            if(tagPart.flags.faceDownRegardlessOfLocationDecals)
            {
                transform.mat3 = Mat3(
                    1,  0,  0,
                    0, -1,  0,
                    0,  0, -1);
            }

            if(!canCreateIn(tagPart.createIn))
            {
                continue;
            }

            float typeSpecificScale = 1.0f;

            if(tagPart.aScalesValues.typeSpecificScale) typeSpecificScale *= scaleA;
            if(tagPart.bScalesValues.typeSpecificScale) typeSpecificScale *= scaleB;

            createSinglePart(tagPart, location, transform, typeSpecificScale);
        }
    }
}

private
void createSinglePart(
    ref const Tag.EffectPartBlock tagPart,
    ref Location                  partLocation,
    Transform                     transform,
    float                         effectScale)
{
    switch(tagPart.type.id)
    {
    case TagId.damageEffect:
    {
        GObject.DamageOptions options =
        {
            // TODO world location
            tagIndex:  tagPart.type.index,
            scale:     effectScale,
            location:  location,
            center:    transform.position,
            position:  transform.position,
            direction: transform.forward,
        };

        if(GObject* object = parent.ptr)
        {
            // TODO instigator for damage options
        }

        world.dealAreaDamage(options);
        break;
    }
    case TagId.decal:
    {
        // TODO implement creation
        break;
    }
    case TagId.particleSystem:
    {
        // TODO implement creation
        break;
    }
    case TagId.light:
    {
        // TODO implement creation
        break;
    }
    case TagId.sound:
    {
        if(parent)
        {
            Audio.inst.play(tagPart.type.index, parent.ptr, partLocation.nodeIndex,
                partLocation.transform.position, partLocation.transform.forward, effectScale);
        }
        else
        {
            Audio.inst.play(tagPart.type.index, transform.position, transform.forward, Vec3(0), location);
        }
        break;
    }
    case TagId.object:
    {
        // TODO implement creation
        break;
    }
    default:
    }
}

private
void createParticles()
{
    const TagEffect* tagEffect = Cache.get!TagEffect(tagIndex);
    const tagEvent = &tagEffect.events[eventIndex];

    float percent = 1.0f;

    if(eventDelayTime > 0.0f)
    {
        percent = time / eventDelayTime;
    }

    foreach(i, ref tagParticle ; tagEvent.particles)
    {
        if(tagParticle.location == indexNone || tagParticle.location >= tagEffect.locations.size)
        {
            continue;
        }

        if(flags.nonviolent)
        {
            if(tagParticle.createInMode == TagEnums.ParticleCreateMode.violentModeOnly)
            {
                continue;
            }
        }
        else if(tagParticle.createInMode == TagEnums.ParticleCreateMode.nonviolentModeOnly)
        {
            continue;
        }

        ubyte particleCount = particleCounts[i];

        int lastCount = cast(int)(particleCount * distribution(tagParticle.distributionFunction, lastTimePercent));
        int count     = cast(int)(particleCount * distribution(tagParticle.distributionFunction, percent));
        int amount    = count - lastCount;

        if(amount <= 0)
        {
            continue;
        }

        foreach(ref location ; rangeOfLocations(tagParticle.location, tagParticle.create))
        {
            createParticlesAtLocation(tagParticle, location, amount);
        }
    }

    lastTimePercent = percent;
}

private
void createParticlesAtLocation(ref const Tag.EffectParticlesBlock tagParticle, ref Location location, int count)
{
    if(location.nodeIndex != indexNone && location.isFirstPerson && FirstPerson.inst(localPlayerIndex).weapon is null)
    {
        return;
    }

    while(count--)
    {
        float distributionRadius = randomScaledValue!"distributionRadius"(tagParticle, tagParticle.distributionRadius);

        Particle.Creation data;

        float speed    = randomScaledValue!"velocity"(tagParticle, tagParticle.velocity);
        data.offset    = randomUnitVector() * distributionRadius + location.transform * tagParticle.relativeOffset;
        data.direction = randomDirection(tagParticle, tagParticle.relativeDirectionUnitVector);
        data.velocity  = data.direction * speed;


        if(location.nodeIndex != indexNone)
        {
            Transform* transform
                = location.isFirstPerson
                ? &FirstPerson.inst(localPlayerIndex).transforms[location.nodeIndex]
                : &parent.ptr.transforms[location.nodeIndex];

            data.offset    = *transform * data.offset;
            data.direction = transform.mat3 * data.direction;
            data.velocity  = transform.mat3 * (transform.scale * data.velocity);
        }

        if(!canCreateIn(tagParticle.createIn)) // TODO(IMPLEMENT) pass a position to this function
        {
            continue;
        }

        data.tagIndex = tagParticle.particleType.index;

        if(tagParticle.flags.stayAttachedToMarker)
        {
            data.object    = parent.ptr;
            data.nodeIndex = location.nodeIndex;
        }
        else
        {
            data.velocity += velocity * gameFramesPerSecond;
        }

        data.localPlayerIndex = localPlayerIndex;

        data.radius          = randomScaledValue!"particleRadius"(tagParticle, tagParticle.radius);
        data.angularVelocity = randomScaledValue!"angularVelocity"(tagParticle, tagParticle.angularVelocity);

        if(tagParticle.flags.randomInitialAngle)
        {
            data.angle = 2 * PI * randomPercent();
        }

        float colorMixPercent = 1.0f;

        if(tagParticle.aScalesValues.tint || tagParticle.bScalesValues.tint)
        {
            if(tagParticle.aScalesValues.tint) colorMixPercent *= scaleA;
            if(tagParticle.bScalesValues.tint) colorMixPercent *= scaleB;
        }
        else
        {
            colorMixPercent = randomPercent();
        }

        data.tint.rgb = mixColor(tagParticle.tintLowerBound.rgb, tagParticle.tintUpperBound.rgb,
            colorMixPercent, tagParticle.flags.interpolateTintAsHsv, tagParticle.flags.AcrossTheLongHuePath);

        data.tint.a = mix(tagParticle.tintLowerBound.a, tagParticle.tintUpperBound.a, colorMixPercent);

        if(tagParticle.flags.tintFromObjectColor)
        {
            data.tint.rgb = data.tint.rgb * color;
        }

        if(location.nodeIndex == indexNone) data.isNodeFirstPerson = false;
        else                                data.isNodeFirstPerson = location.isFirstPerson;

        data.isFirstPersonOnly = tagParticle.create == TagEnums.CreationPerspective.onlyInFirstPerson;
        data.isThirdPersonOnly = tagParticle.create == TagEnums.CreationPerspective.onlyInThirdPerson;

        world.createParticle(data);
    }
}

private
float randomScaledValue(string member, Block)(ref const Block block, TagBounds!float bounds)
{
    return randomScaledValue!member(block, bounds.lower, bounds.upper);
}

private
float randomScaledValue(string member, Block)(ref const Block block, float lower, float upper)
{
    float delta = upper - lower;

    if(mixin("block.aScalesValues." ~ member))           lower *= scaleA;
    if(mixin("block.bScalesValues." ~ member))           lower *= scaleB;
    if(mixin("block.aScalesValues." ~ member ~ "Delta")) delta *= scaleA;
    if(mixin("block.bScalesValues." ~ member ~ "Delta")) delta *= scaleB;

    return lower + delta * randomPercent();
}

private
ref Transform getLocationTransform(ref Location location)
{
    if(location.isFirstPerson)
    {
        return FirstPerson.inst(localPlayerIndex).transforms[location.nodeIndex];
    }

    return parent.ptr.transforms[location.nodeIndex];
}

private
auto rangeOfLocations(int locationIndex, TagEnums.CreationPerspective perspective)
{
    static struct Result
    {
    @nogc nothrow:

        private Effect* effect;
        private Location* start;
        private TagEnums.CreationPerspective perspective;

        this(Effect* effect, Location* start, TagEnums.CreationPerspective perspective)
        {
            this.effect      = effect;
            this.start       = start;
            this.perspective = perspective;

            if(start && !frontIsValid())
            {
                popFront();
            }
        }

        private bool frontIsValid()
        {
            if(start)
            {
                switch(perspective)
                {
                case TagEnums.CreationPerspective.inFirstPersonIfPossible:
                    if(effect.localPlayerIndex != indexNone) // TODO(IMPLEMENT) check player camera is in first person
                    {
                        return start.nodeIndex != indexNone && start.isFirstPerson;
                    }
                    goto default;
                case TagEnums.CreationPerspective.onlyInFirstPerson:
                    return start.nodeIndex != indexNone && start.isFirstPerson;
                default:
                    return start.nodeIndex == indexNone || !start.isFirstPerson;
                }
            }

            return false;
        }

        @property bool empty()
        {
            return start is null;
        }

        @property ref Location front()
        {
            return *start;
        }

        void popFront()
        {
            if(start is null)
            {
                return;
            }

            do
            {
                start = start.next;
            } while(start && !frontIsValid());
        }

    }

    return Result(&this, eventLocations[locationIndex], perspective);
}

private static
float distribution(TagEnums.DistributionFunction func, float input)
{
    if(input == -1.0f) // hack special case
    {
        return 0.0f;
    }

    switch(func) with(TagEnums.DistributionFunction)
    {
    case start:             return 1.0f;
    case end:               return input == 1.0f ? 1.0f : 0.0f;
    case buildup:           return input * input;
    case falloff:           return (2.0f - input) * input;
    case buildupAndFalloff: return (3.0f - (input + input)) * input * input;
    default:                return input;
    }
}

private
bool canCreateIn(TagEnums.EnvironmentType type) // TODO(IMPLEMENT) pass a position to this function
{
    switch(type) with(TagEnums.EnvironmentType)
    {
    case waterOnly:
        // TODO(IMPLEMENT) check cluster is water
        break;
    case airOnly:
        // TODO(IMPLEMENT) check cluster is air
        // if(not air) { return false; }
        break;
    case anyEnvironment: return true;
    default:             return false;
    }

    return true;
}

private
Vec3 randomDirection(Block)(ref const Block block, Vec3 direction)
{
    float coneAngle = block.velocityConeAngle;

    if(block.aScalesValues.velocityConeAngle) coneAngle *= scaleA;
    if(block.bScalesValues.velocityConeAngle) coneAngle *= scaleB;

    return rotate(direction, coneAngle, randomUnitVector());
}

}
