
module Game.Audio.Audio;

import std.datetime : StopWatch, Duration;

import OpenAL;

import Game.Audio.Sound;
import Game.Audio.Looping;

import Game.Cache;
import Game.Core;
import Game.Tags;


struct Audio
{

__gshared Audio* inst;

struct Listener
{
    bool active;

    Transform transform;
}

StopWatch stopWatch;
Duration  lastUpdateTime;

Listener[TagConstants.Player.maxLocalPlayers] listeners;
DatumArray!Sound sounds;

void initialize()
{
    sounds.allocate(128, multichar!"s!");
}

void update()
{
    foreach(ref sound ; sounds)
    {
        const tagSound       = Cache.get!TagSound(sound.tagIndex);
        const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
        const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

        if(sound.source == AL_NONE)
        {
            if(tagPermutation.cacheBufferIndex == indexNone)
            {
                sounds.remove(sound.selfIndex);
                continue;
            }

            alGenSources(1, &sound.source);

            alSourcei(sound.source, AL_BUFFER, tagPermutation.cacheBufferIndex);
            alSourcePlay(sound.source);
        }

        int state;
        alGetSourcei(sound.source, AL_SOURCE_STATE, &state);

        if(state != AL_PLAYING)
        {
            sounds.remove(sound.selfIndex);
        }

    }
}

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

DatumIndex play(DatumIndex tagSoundIndex, ref const Sound.Spatial spatial)
{
    auto tagSound = Cache.get!TagSound(tagSoundIndex);

    float skipModifier  = mix(tagSound.skipFractionModifier0, tagSound.skipFractionModifier1, spatial.scale);
    float pitchModifier = mix(tagSound.pitchModifier0,        tagSound.pitchModifier1,        spatial.scale);

    if(spatial.scale == 0.0f && tagSound.gainModifier == 0.0f || tagSound.skipFraction * skipModifier > randomPercent())
    {
        return DatumIndex.none;
    }

    if(tagSound.pitchRanges.size <= 0 || tagSound.pitchRanges[0].permutations.size <= 0)
    {
        return DatumIndex.none;
    }

    // TODO global value that enables/disables sound classes

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


}