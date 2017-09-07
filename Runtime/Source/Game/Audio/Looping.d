
module Game.Audio.Looping;

import std.bitmanip : bitfields;
import std.datetime : Duration;

import Game.Audio.Audio;
import Game.Audio.Sound;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World;


struct LoopingSound
{

enum State
{
    start,
    looping,
    end,
}

DatumIndex selfIndex;
DatumIndex tagIndex;
Audio*     audio;

DatumIndex ownerIndex;
State state;

Sound.Spatial spatial;

bool completed;

DatumIndex[TagConstants.SoundLooping.maxTracks]     trackSounds;
Duration[TagConstants.SoundLooping.maxDetailSounds] detailStartTimes;

}

// Object Looping Sound /////////////////////////////////////////////////////////////////////////////////////////////////////

struct ObjectLoopingSound
{

enum State
{
    idle__,    // TODO verify
    stopped__, // TODO verify
    outdated,
}

struct Flags
{
    mixin(bitfields!(
        bool, "isBackgroundSound",     1, // TODO name doesnt seem right
        bool, "backgroundSoundPaused", 1,
        bool, "alternate",             1,
        ubyte, "",                     5,
    ));
}

DatumIndex selfIndex;
DatumIndex tagIndex;
Audio*     audio;

SheepGObjectPtr object;

Flags flags;
State state = State.outdated;

DatumIndex loopingSoundIndex;

float backgroundSoundScale;

int lastTickCounter = indexNone;
int scaleFunctionIndex = indexNone;

int nodeIndex = indexNone;
Vec3 position;
Vec3 forward;


void update()
{
    if(object)
    {
        if(GObject* object = object.ptr)
        {
            if(!object.flags.connectedToMap)
            {
                return;
            }
        }
        else
        {
            audio.objectLoopingSounds.remove(selfIndex);
            return;
        }
    }

    updateImpl();
}

private void updateImpl()
{
    const tagSoundLooping = Cache.get!TagSoundLooping(tagIndex);

    bool outdated = lastTickCounter == indexNone || lastTickCounter != audio.objectLoopingTickCounter - 1;

    bool scaleIsValid = false;
    float scale;

    if(flags.isBackgroundSound)
    {
        scaleIsValid = true;
        scale = backgroundSoundScale;
    }
    else if(scaleFunctionIndex != indexNone)
    {
        GObject* object = object.ptr;

        if(object.exportFunctionValidities[scaleFunctionIndex])
        {
            scaleIsValid = true;
            scale = object.exportFunctionValues[scaleFunctionIndex];
        }
    }
    else
    {
        scaleIsValid = true;
        scale        = 1.0f;
    }

    Sound.Spatial spatial = { scale: 1.0f }; // TODO, fill with real values

    if(scaleIsValid)
    {
        LoopingSound.State desired;

        if(state != State.idle__ && outdated)
        {
            desired = LoopingSound.State.start;
        }
        else
        {
            desired = LoopingSound.State.looping;
        }

        state = State.idle__;

        if(!updateLoopingSound(desired, spatial, float.nan))
        {
            if(flags.isBackgroundSound)
            {
                audio.objectLoopingSounds.remove(selfIndex);
                return;
            }
            else
            {
                state = State.stopped__;
            }
        }
    }
    else
    {
        if(!outdated && !updateLoopingSound(LoopingSound.State.end, spatial, float.nan)) // TODO
        {
            state = State.stopped__;
        }
        else
        {
            if(flags.isBackgroundSound)
            {
                audio.objectLoopingSounds.remove(selfIndex);
                return;
            }
            else
            {
                state = State.outdated;
            }
        }
    }

    lastTickCounter = audio.objectLoopingTickCounter;
}

private bool updateLoopingSound(LoopingSound.State desiredState, ref Sound.Spatial spatial, float fadeTime)
{
    const         tagSoundLooping = Cache.get!TagSoundLooping(tagIndex);
    LoopingSound* loopingSound    = audio.loopingSounds.at(loopingSoundIndex);

    bool newlyCreated = false;

    if(loopingSound is null)
    {
        if(desiredState == LoopingSound.State.end)
        {
            return true;
        }

        loopingSoundIndex = audio.createLoopingSound(tagIndex, selfIndex, float.nan);
        newlyCreated = true;

        if(loopingSoundIndex == DatumIndex.none)
        {
            return false;
        }

        loopingSound = &audio.loopingSounds[loopingSoundIndex];
    }

    loopingSound.spatial = spatial;

    if(tagSoundLooping.continuousDamageEffect)
    {
        // TODO(IMPLEMENT) continous damage effect
    }

    foreach(int i, ref tagTrack ; tagSoundLooping.tracks)
    {
        if(desiredState == LoopingSound.State.start)
        {
            if(tagTrack.start)
            {
                loopingSound.trackSounds[i] = audio.createSoundForLooping(tagTrack.start.index,
                    loopingSound.selfIndex, i, Sound.State.start);
            }
        }

        if(desiredState == LoopingSound.State.end || loopingSound.completed)
        {
            if(loopingSound.state == LoopingSound.State.end)
            {
                continue;
            }

            if(fadeTime == 0.0f)
            {
                if(loopingSound.trackSounds[i] && tagTrack.flags.fadeOutAtStop
                    || !tagTrack.end && !tagSoundLooping.flags.notALoop)
                {
                    // TODO(IMPLEMENT) fading
                }

                if(!tagTrack.end)
                {
                    continue;
                }

                DatumIndex tagSoundIndex = tagTrack.end.index;

                if(flags.alternate && tagTrack.alternateEnd)
                {
                    tagSoundIndex = tagTrack.alternateEnd.index;
                }

                if(tagTrack.flags.fadeOutAtStop)
                {
                    audio.createSoundForLooping(tagSoundIndex, loopingSound.selfIndex, i, Sound.State.end);
                }
                else
                {
                    if(DatumIndex soundIndex = loopingSound.trackSounds[i])
                    {
                        audio.sounds[soundIndex].setDesiredTag(tagSoundIndex);
                    }
                }
            }
            else
            {
                // TODO(IMPLEMENT) fading
            }
        }
        else
        {
            DatumIndex tagSoundIndex = tagTrack.loop.index;

            if(flags.alternate && tagTrack.alternateLoop)
            {
                tagSoundIndex = tagTrack.alternateLoop.index;
            }

            if(tagSoundIndex == DatumIndex.none)
            {
                continue;
            }

            if(!loopingSound.trackSounds[i] || desiredState == LoopingSound.State.start && tagTrack.flags.fadeInAtStart)
            {
                DatumIndex soundIndex = audio.createSoundForLooping(tagSoundIndex,
                    loopingSound.selfIndex, i, Sound.State.looping);

                if(soundIndex == DatumIndex.none)
                {
                    continue;
                }

                // TODO(IMPLEMENT) fading

                loopingSound.trackSounds[i] = soundIndex;
            }
            else
            {
                // TODO(IMPLEMENT) alternate loop

                if(!newlyCreated)
                {
                    audio.sounds[loopingSound.trackSounds[i]].setDesiredTag(tagSoundIndex);
                }
            }
        }
    }

    // TODO IMPLEMENT destruction

    loopingSound.state = desiredState;

    return true;
}

}
