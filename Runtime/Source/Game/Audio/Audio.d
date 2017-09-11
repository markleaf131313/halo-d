
module Game.Audio.Audio;

import std.datetime.stopwatch : StopWatch, Duration, msecs;

import OpenAL;
import Vorbis;

import Game.Audio.Sound;
import Game.Audio.Looping;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World;


struct Audio
{

__gshared Audio* inst;

struct Listener
{
    bool active;

    Transform transform;
}

StopWatch stopWatch;
Duration  currentTime;

int      objectLoopingTickCounter;
Duration lastObjectLoopingUpdateTime;

Listener[TagConstants.Player.maxLocalPlayers] listeners;
SoundBuffer[32] soundBuffers;

DatumArray!Sound              sounds;
DatumArray!LoopingSound       loopingSounds;
DatumArray!ObjectLoopingSound objectLoopingSounds;

int lastSample;
void*[2048] samples; // TODO use padding in TagData instead?

void initialize()
{
    stopWatch.reset();
    stopWatch.start();

    sounds.allocate(128, multichar!"s!");
    loopingSounds.allocate(128, multichar!"lp");
    objectLoopingSounds.allocate(32, multichar!"ol");

    foreach(ref soundBuffer ; soundBuffers)
    {
        soundBuffer.audio = &this;
        soundBuffer.initialize();
    }
}

int addSampleData(void* ptr)
{
    int result = lastSample++;
    samples[result] = ptr;
    return result;
}

float getVolume(TagEnums.SoundClass soundClass)
{
    return 1.0; // TODO implement volume controls
}

int findSoundBufferForSound(DatumIndex index)
{
    if(!index)
    {
        return indexNone;
    }

    auto sound = &sounds[index];

    if(sound.soundBufferIndex != indexNone)
    {
        return sound.soundBufferIndex;
    }

    foreach(int i, ref soundBuffer ; soundBuffers)
    {
        if(soundBuffer.soundIndex)
        {
            if(soundBuffer.soundIndex == index)
            {
                return i;
            }

            continue; // TODO check if same parent
        }

        // TODO check requirements, mono, compressed, etc...

        return i;
    }

    return indexNone;
}

void update(Vec3 position)
{
    listeners[0].active = true;
    listeners[0].transform.position = position;

    currentTime = stopWatch.peek(); // TODO only check every 33 ms?

    foreach(ref sound ; sounds)
    {
        sound.update();
    }

    foreach(int i, ref soundBuffer ; soundBuffers)
    {
        soundBuffer.update(i);
    }

}

void updateObjectLoopingSounds()
{
    if(stopWatch.peek() - lastObjectLoopingUpdateTime >= gameFrameTimeMsecs)
    {
        foreach(ref objectLooping ; objectLoopingSounds)
        {
            objectLooping.update();
        }

        objectLoopingTickCounter += 1;
        lastObjectLoopingUpdateTime = stopWatch.peek();
    }
    else
    {
        // TODO other stuff, check garbage collection, etc...
    }
}

DatumIndex playDebug(DatumIndex tagSoundIndex, int pitch, int permutation)
{
    if(DatumIndex index = play(tagSoundIndex))
    {
        Sound* sound = &sounds[index];

        sound.pitchRangeIndex  = pitch;
        sound.permutationIndex = permutation;

        return index;
    }

    return DatumIndex.none;
}

@nogc nothrow
DatumIndex play(DatumIndex tagSoundIndex)
{
    if(tagSoundIndex == DatumIndex.none)
    {
        return DatumIndex.none;
    }

    Sound.Spatial data =
    {
        type:   Sound.Spatial.Type.atListener,
        volume: 1.0f,
        scale:  1.0f
    };

    return play(tagSoundIndex, data);
}

@nogc nothrow
DatumIndex play(DatumIndex tagSoundIndex, Vec3 position, Vec3 direction, Vec3 velocity, World.Location location)
{
    Sound.Spatial spatial =
    {
        type:      Sound.Spatial.Type.relativeToPlayers,
        position:  position,
        direction: direction,
        velocity:  velocity,
        location:  location,
    };

    return play(tagSoundIndex, spatial);
}

@nogc nothrow
DatumIndex play(DatumIndex tagSoundIndex, GObject* object, int nodeIndex, Vec3 position, Vec3 forward, float scale)
{
    // TODO implement properly
    return play(tagSoundIndex);
}

@nogc nothrow
DatumIndex play(DatumIndex tagSoundIndex, ref const Sound.Spatial spatial)
{
    auto tagSound = Cache.get!TagSound(tagSoundIndex);

    float skipModifier  = mix(tagSound.skipFractionModifier0, tagSound.skipFractionModifier1, spatial.scale);
    float pitchModifier = mix(tagSound.pitchModifier0,        tagSound.pitchModifier1,        spatial.scale);

    if(spatial.scale == 0.0f && tagSound.gainModifier == 0.0f || tagSound.skipFraction * skipModifier > randomPercent())
    {
        return DatumIndex.none;
    }

    if(!tagSound.isValid())
    {
        return DatumIndex.none;
    }

    int listenerIndex = findClosestListener(spatial, tagSound.getMaximumDistance());

    if(listenerIndex == indexNone)
    {
        return DatumIndex.none;
    }

    // TODO sound promotion

    DatumIndex soundIndex = sounds.add();

    if(soundIndex == DatumIndex.none)
    {
        return DatumIndex.none;
    }

    Sound* sound = &sounds[soundIndex];

    sound.audio    = &this;
    sound.tagIndex = tagSoundIndex;
    sound.spatial  = spatial;

    sound.pitch            = randomValue(tagSound.randomPitchBounds) * pitchModifier;
    sound.pitchRangeIndex  = tagSound.selectPitchRange(sound.pitch);
    sound.permutationIndex = tagSound.selectPermutation(sound.pitchRangeIndex);

    // TODO set game time delay

    return soundIndex;
}

package
DatumIndex createSoundForLooping(DatumIndex tagIndex, DatumIndex loopingSoundIndex, int trackIndex, Sound.State state)
{
    auto          tagSound     = Cache.get!TagSound(tagIndex);
    LoopingSound* loopingSound = &loopingSounds[loopingSoundIndex];

    if(!tagSound.isValid())
    {
        return DatumIndex.none;
    }

    int listenerIndex = findClosestListener(loopingSound.spatial, tagSound.getMaximumDistance());

    if(listenerIndex == indexNone)
    {
        return DatumIndex.none;
    }

    if(DatumIndex index = sounds.add())
    {
        float pitchModifier = mix(tagSound.pitchModifier0, tagSound.pitchModifier1, loopingSound.spatial.scale);

        Sound* sound = &sounds[index];

        sound.audio    = &this;
        sound.tagIndex = tagIndex;

        sound.state = state;

        sound.ownerIndex = loopingSoundIndex;
        sound.trackIndex = trackIndex;

        sound.pitch            = randomValue(tagSound.randomPitchBounds) * pitchModifier;
        sound.pitchRangeIndex  = tagSound.selectPitchRange(sound.pitch);
        sound.permutationIndex = tagSound.selectPermutation(sound.pitchRangeIndex);


        return index;
    }

    return DatumIndex.none;
}

DatumIndex createLoopingSound(DatumIndex tagIndex, DatumIndex ownerIndex, float scale)
{
    if(DatumIndex index = loopingSounds.add())
    {
        const tagSoundLooping = Cache.get!TagSoundLooping(tagIndex);
        LoopingSound* loopingSound = &loopingSounds[index];

        loopingSound.tagIndex   = tagIndex;
        loopingSound.audio      = &this;
        loopingSound.ownerIndex = ownerIndex;

        foreach(int i, ref tagDetail ; tagSoundLooping.detailSounds)
        {
            float period       = randomValue(tagDetail.randomPeriodBounds);
            float scaledPeriod = mix(tagSoundLooping.detailSoundPeriod0, tagSoundLooping.detailSoundPeriod1, scale);

            loopingSound.detailStartTimes[i] = currentTime + msecs(cast(long)(period * scaledPeriod * 1000.0f));
        }

        return index;
    }

    return DatumIndex.none;
}

@nogc nothrow
DatumIndex createObjectLoopingSound(DatumIndex tagIndex, ref GObject object, const(char)[] markerName, int functionIndex)
{
    if(tagIndex == DatumIndex.none)
    {
        return DatumIndex.none;
    }

    if(DatumIndex index = objectLoopingSounds.add())
    {
        ObjectLoopingSound* objectLooping = &objectLoopingSounds[index];

        objectLooping.audio    = &this;
        objectLooping.tagIndex = tagIndex;
        objectLooping.object   = object.selfPtr;
        objectLooping.scaleFunctionIndex = functionIndex;

        auto markerTransform = object.findMarkerTransform(markerName);

        objectLooping.nodeIndex = markerTransform.node;
        objectLooping.forward   = markerTransform.local.forward;
        objectLooping.position  = markerTransform.local.position;

        return index;
    }

    return DatumIndex.none;
}

@nogc nothrow
DatumIndex createObjectLoopingSound(DatumIndex tagIndex)
{
    if(tagIndex == DatumIndex.none)
    {
        return DatumIndex.none;
    }

    if(DatumIndex index = objectLoopingSounds.add())
    {
        ObjectLoopingSound* objectLooping = &objectLoopingSounds[index];

        objectLooping.audio    = &this;
        objectLooping.tagIndex = tagIndex;

        objectLooping.flags.isBackgroundSound = true;

        return index;
    }

    return DatumIndex.none;
}

@nogc nothrow
void deleteSound(DatumIndex index)
{
    if(!index)
    {
        return;
    }

    auto sound = &sounds[index];

    // assert(0); // TODO implement

    if(sound.state != Sound.State.linear)
    {
        // TODO looping sound invalidate index in loopingSound, if current track
    }

    sounds.remove(index);
}

@nogc nothrow
int findClosestListener(ref const Sound.Spatial spatial, float maximumDistance)
{

    switch(spatial.type)
    {
    default:
    case Sound.Spatial.Type.atListener:
        return 0;
    case Sound.Spatial.Type.relativeToPlayers:

        float distance      = float.max;
        int   listenerIndex = indexNone;

        foreach(int i, ref listener ; listeners)
        {
            if(!listener.active)
            {
                continue;
            }

            float d = distanceToListener(spatial, i);

            if(d < distance)
            {
                distance      = d;
                listenerIndex = i;
            }
        }

        if(listenerIndex != indexNone)
        {
            // TODO bsp related, line collision test...
        }

        if(distance <= maximumDistance)
        {
            return listenerIndex;
        }

        // TODO some other check

        return indexNone;
    case Sound.Spatial.Type.relativeToWorldOrigin:

        if(distanceToListener(spatial, indexNone) <= maximumDistance)
        {
            return 0;
        }
        else
        {
            return indexNone;
        }
    }

}

@nogc nothrow
float distanceToListener(ref const Sound.Spatial spatial, int listenerIndex)
in
{
    assert(spatial.type != Sound.Spatial.Type.relativeToPlayers || listenerIndex != indexNone);
}
body
{
    switch(spatial.type)
    {
    default:
    case Sound.Spatial.Type.atListener:
        return 0.0f;
    case Sound.Spatial.Type.relativeToPlayers:
        return length(spatial.position - listeners[listenerIndex].transform.position);
    case Sound.Spatial.Type.relativeToWorldOrigin:
        return length(spatial.position);
    }
}

void updateCallbacksOnReload()
{
    foreach(ref soundBuffer ; soundBuffers)
    {
        soundBuffer.updateOggCallbacks();
    }
}

}
