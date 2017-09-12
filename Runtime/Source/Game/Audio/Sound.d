
module Game.Audio.Sound;

import core.time : Duration, seconds, msecs;

import OpenAL;
import Vorbis;

import Game.Audio.Adpcm;
import Game.Audio.Audio : Audio;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World : World;

struct SoundBuffer
{

Audio* audio;
DatumIndex soundIndex;

uint    source  = AL_NONE;
uint[3] buffers = AL_NONE;

uint    unqueuedBufferCount;
uint[3] unqueuedBuffers = AL_NONE;

bool bufferExhausted;
uint readOffset;

bool isOggInit;
align(OggVorbis_File.alignof) void[OggVorbis_File.sizeof] oggFileBuffer = void;

@nogc nothrow
~this()
{
    alDeleteSources(1, &source);
    alDeleteBuffers(buffers.length, buffers.ptr);
}

OggVorbis_File* oggFile()
{
    return cast(OggVorbis_File*)oggFileBuffer;
}

void initialize()
{
    alGenSources(1, &source);
    alGenBuffers(buffers.length, buffers.ptr);

    unqueuedBuffers = buffers;
    unqueuedBufferCount = buffers.length;
}

void overlapBuffer()
{
    auto  sound    = &audio.sounds[soundIndex];
    const tagSound = Cache.get!TagSound(sound.tagIndex);

    readOffset = 0;
    bufferExhausted = false;

    if(isOggInit)
    {
        ov_clear(oggFile);
        isOggInit = false;
    }

    switch(tagSound.compression)
    {
    case TagEnums.SoundCompression.ogg:
        ov_callbacks callbacks =
        {
            close_func: null,
            tell_func:  null,
            seek_func:  null,
            read_func:  &readOggCallback,
        };

        ov_open_callbacks(&this, oggFile, null, 0, callbacks);

        isOggInit = true;
        break;
    default:
    }
}

private void reset()
{
    soundIndex = DatumIndex.none;
    readOffset = 0;

    bufferExhausted = false;

    alSourceStop(source);

    unqueueProcessedBuffers();

    if(isOggInit)
    {
        ov_clear(oggFile);
    }
}

private void unqueueProcessedBuffers()
{
    int processed;

    alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);

    if(processed > 0)
    {
        alSourceUnqueueBuffers(source, processed, &unqueuedBuffers[unqueuedBufferCount]);
        unqueuedBufferCount += processed;
    }
}

void update(int index)
{
    if(!soundIndex)
    {
        return;
    }

    auto  sound          = &audio.sounds[soundIndex];
    const tagSound       = Cache.get!TagSound(sound.tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

    if(sound.getGain() <= 0.0f && sound.fadeEndGain <= 0.0f)
    {
        audio.deleteSound(soundIndex);
        reset();
        return;
    }

    if(sound.state == Sound.State.linear)
    {
        updateLinearSound(index);
    }
    else
    {
        updateLoopingSound(index);
    }

}

private void updateLinearSound(int index)
{
    auto  sound          = &audio.sounds[soundIndex];
    const tagSound       = Cache.get!TagSound(sound.tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

    if(sound.soundBufferIndex == indexNone)
    {
        switch(tagSound.compression)
        {
        case TagEnums.SoundCompression.ogg:
            ov_callbacks callbacks =
            {
                close_func: null,
                tell_func:  null,
                seek_func:  null,
                read_func:  &readOggCallback,
            };

            ov_open_callbacks(&this, oggFile, null, 0, callbacks);

            isOggInit = true;
            break;
        default:
        }

        fillBuffers();
        sound.soundBufferIndex = index;
    }
    else
    {
        unqueueProcessedBuffers();
        fillBuffers();
    }

    int sourceState;
    alGetSourcei(source, AL_SOURCE_STATE, &sourceState);

    if(sourceState != AL_PLAYING)
    {
        // TODO better way to determine done playing
        //      ogg's readOffset can be "done" but still have data it needs to play
        if(readOffset >= tagPermutation.samples.size)
        {
            audio.deleteSound(soundIndex);
            reset();
        }
        else
        {
            alSourcePlay(source);
        }
    }
}

private void updateLoopingSound(int index)
{
    auto  sound          = &audio.sounds[soundIndex];
    auto  tagSound       = Cache.get!TagSound(sound.tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

    auto loopingSound = &audio.loopingSounds[sound.ownerIndex];
    const tagLooping  = Cache.get!TagSoundLooping(loopingSound.tagIndex);
    const tagTrack    = &tagLooping.tracks[sound.trackIndex];

    float minDistance = tagSound.getMinimumDistance();
    float volume = audio.getVolume(tagSound.soundClass);

    float pitch = mix(tagSound.pitchModifier0, tagSound.pitchModifier1, loopingSound.spatial.scale);

    if(sound.soundBufferIndex == indexNone)
    {
        switch(tagSound.compression)
        {
        case TagEnums.SoundCompression.ogg:
            ov_callbacks callbacks =
            {
                close_func: null,
                tell_func:  null,
                seek_func:  null,
                read_func:  &readOggCallback,
            };

            ov_open_callbacks(&this, oggFile, null, 0, callbacks);

            isOggInit = true;
            break;
        default:
        }

        fillBuffers();
        sound.soundBufferIndex = index;
    }
    else
    {
        // TODO music destroy sound if setting is zero

        if(sound.state == Sound.State.looping && !sound.isFadingOut())
        {
            if(tagSound.selectPitchRange(pitch, sound.pitchRangeIndex) != sound.pitchRangeIndex)
            {
                if(loopingSound.trackSounds[sound.trackIndex] == sound.selfIndex)
                {
                    if(auto newSound = audio.createSoundForLooping(sound.tagIndex, sound.ownerIndex, sound.trackIndex, Sound.State.looping))
                    {
                        sound.fadeOut(500.msecs, true);
                        audio.sounds[newSound].fadeIn(500.msecs, true);

                        loopingSound.trackSounds[sound.trackIndex] = newSound;
                    }
                }
            }
        }

        if(sound.state != Sound.State.end && sound.state != Sound.State.start || !tagTrack.flags.fadeInAtStart)
        {
            if(bufferExhausted || sound.desiredTagIndex && tagPermutation.nextPermutationIndex == indexNone)
            {
                if(sound.desiredTagIndex && tagPermutation.nextPermutationIndex == indexNone)
                {
                    if(bufferExhausted)
                    {
                        sound.switchSoundTag(pitch);
                    }
                }
                else
                {
                    int nextPermutationIndex = tagSound.selectPermutation(sound.pitchRangeIndex, sound.permutationIndex);

                    if(nextPermutationIndex != indexNone)
                    {
                        sound.permutationIndex = nextPermutationIndex;
                        overlapBuffer();
                    }
                    else
                    {
                        // TODO
                    }
                }
            }
        }

        unqueueProcessedBuffers();
        fillBuffers();
    }

    alSourcef(source, AL_PITCH, pitch * tagPitchRange.naturalPitchModifier);
    alSourcef(source, AL_GAIN, sound.getGain() * volume);

    int sourceState;
    alGetSourcei(source, AL_SOURCE_STATE, &sourceState);

    if(sourceState != AL_PLAYING)
    {
        alSourcePlay(source);
    }
}

private bool fillBuffers()
{
    auto  sound          = &audio.sounds[soundIndex];
    const tagSound       = Cache.get!TagSound(sound.tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

    if(unqueuedBufferCount <= 0)
    {
        return false;
    }

    foreach_reverse(uint buffer ; unqueuedBuffers[0 .. unqueuedBufferCount])
    {
        byte[2048] data = void;
        ptrdiff_t length;

        int  numChannels = 2;
        uint encoding    = AL_FORMAT_STEREO16;

        if(tagSound.encoding == TagEnums.SoundEncoding.mono)
        {
            numChannels = 1;
            encoding    = AL_FORMAT_MONO16;
        }

        const void* sample = audio.samples[tagPermutation.cacheBufferIndex];

        switch(tagSound.compression)
        {
        case TagEnums.SoundCompression.xboxAdpcm:

            if(readOffset >= tagPermutation.samples.size)
            {
                bufferExhausted = true;
                return false;
            }

            size_t encodedLength = compressedAdpcmSize(data.length, numChannels);
            encodedLength        = min(encodedLength, tagPermutation.samples.size - readOffset);
            length               = decodedAdpcmSize(encodedLength, numChannels);

            decodeAdpcm(sample[readOffset .. readOffset + encodedLength], numChannels, data[0 .. length]);
            readOffset += encodedLength;
            break;
        case TagEnums.SoundCompression.ogg:
            while(length < data.length)
            {
                auto ret = ov_read(oggFile, data.ptr + length, cast(int)(data.length - length), 0, 2, 1, null);

                if(ret <= 0)
                {
                    bufferExhausted = true;
                    break;
                }

                length += ret;
            }
            break;
        default: return false;
        }

        if(length <= 0)
        {
            return false;
        }

        int freq = tagSound.sampleRate == TagEnums.SoundSampleRate._44khz ? 44100 : 22050;

        alBufferData(buffer, encoding, data.ptr, cast(int)length, freq);
        alSourceQueueBuffers(source, 1, &buffer);

        unqueuedBufferCount -= 1;

    }

    return true;
}

void updateOggCallbacks()
{
    if(oggFile.callbacks.read_func)
    {
        oggFile.callbacks.read_func = &readOggCallback;
    }
}

private size_t readOgg(size_t size, size_t num, void* data) nothrow
{
    import core.stdc.string : memcpy;

    const sound          = &Audio.inst.sounds[soundIndex];
    const tagSound       = Cache.get!TagSound(sound.tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[sound.pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[sound.permutationIndex];

    size_t total = min(size * num, tagPermutation.samples.size - readOffset);

    const void* sample = audio.samples[tagPermutation.cacheBufferIndex];
    memcpy(data, sample + readOffset, total);

    readOffset += cast(int)total;

    return total;
}

private extern(C) static
size_t readOggCallback(void* ptr, size_t size, size_t num, void* data) nothrow
{
    return (cast(SoundBuffer*)data).readOgg(size, num, ptr);
}

}

// Sound ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct Sound
{

@disable this(this);

enum State
{
    linear,
    start,
    looping,
    end,
}

struct Spatial
{
    enum Type
    {
        atListener,
        relativeToPlayers,
        relativeToWorldOrigin,
    }

    Type type;

    float volume = 1.0f;
    float scale  = 1.0f;

    Vec3 position;
    Vec3 direction;
    Vec3 velocity;
    World.Location location;
}

DatumIndex selfIndex;
DatumIndex tagIndex;
Audio* audio;

State state;

DatumIndex ownerIndex;
int soundBufferIndex = indexNone;

Spatial spatial;

DatumIndex desiredTagIndex;

float pitch;

int pitchRangeIndex;
int permutationIndex;
int trackIndex;


bool fadeNonLinearly;
float fadeStartGain;
float fadeEndGain;
Duration fadeStartTime;
Duration fadeEndTime;

void update()
{
    const tagSound       = Cache.get!TagSound(tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[permutationIndex];

    // TODO start of sound time

    if(soundBufferIndex == indexNone)
    {
        int index = audio.findSoundBufferForSound(selfIndex);

        if(index != indexNone)
        {
            auto soundBuffer = &audio.soundBuffers[index];

            if(soundBuffer.soundIndex)
            {
                audio.deleteSound(soundBuffer.soundIndex);
            }

            soundBuffer.soundIndex = selfIndex;
            // TODO start of sound time
        }
    }

    // ----------------------------------------------------------------------------
    // if(source == AL_NONE)
    // {
    //     switch(tagSound.compression)
    //     {
    //     case TagEnums.SoundCompression.xboxAdpcm:

    //         break;
    //     case TagEnums.SoundCompression.ogg:

    //         ov_callbacks callbacks = void;

    //         callbacks.close_func = null;
    //         callbacks.tell_func  = null;
    //         callbacks.seek_func  = null;
    //         callbacks.read_func  = &readOggCallback;

    //         ov_open_callbacks(&this, oggFile, null, 0, callbacks);

    //         break;
    //     default:
    //         audio.sounds.remove(selfIndex);
    //         return;
    //     }

    //     alGenSources(1, &source);
    //     alGenBuffers(buffers.length, buffers.ptr);

    //     // alSourcef(source, AL_MAX_DISTANCE, tagSound.getMaximumDistance());

    //     fillBuffer(0);
    //     fillBuffer(1);

    //     alSourcePlay(source);
    // }

    // if(state != State.linear)
    // {

    // }
    // else
    // {
    //     if(spatial.type != Spatial.Type.atListener)
    //     {
    //         alSource3f(source, AL_POSITION, spatial.position.x, spatial.position.y, spatial.position.z);
    //     }

    //     int processed;
    //     alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);

    //     while(processed--)
    //     {
    //         uint buffer;
    //         alSourceUnqueueBuffers(source, 1, &buffer);

    //         if(!fillBuffer(buffer == buffers[0] ? 0 : 1))
    //         {
    //             break;
    //         }
    //     }

    //     int sourceState;
    //     alGetSourcei(source, AL_SOURCE_STATE, &sourceState);

    //     if(sourceState != AL_PLAYING)
    //     {
    //         // TODO better way to determine done playing
    //         //      ogg's readOffset can be "done" but still have data it needs to play
    //         if(readOffset >= tagPermutation.samples.size)
    //         {
    //             audio.sounds.remove(selfIndex);
    //         }
    //         else
    //         {
    //             alSourcePlay(source);
    //         }
    //     }
    // }
}

float getGain()
{
    if(fadeStartTime >= fadeEndTime)
    {
        return 1.0f;
    }

    float diffDesired = float((fadeEndTime       - fadeStartTime).total!"msecs");
    float diffCurrent = float((audio.currentTime - fadeStartTime).total!"msecs");

    float percent = saturate(diffCurrent / diffDesired);

    if(fadeNonLinearly)
    {
        if(fadeEndGain <= fadeStartGain)
        {
            percent = 1.0f - pow(1.0f - percent, 1.0f / 2.5f);
        }
        else
        {
            percent = pow(percent, 1.0f / 2.5f);
        }
    }

    if(percent >= 1.0f)
    {
        percent = 1.0f;

        fadeStartTime = Duration();
        fadeEndTime   = Duration();
    }

    return mix(fadeStartGain, fadeEndGain, percent);
}

bool isFadingOut()
{
    return fadeStartTime < fadeEndTime && fadeEndGain <= 0.0f;
}

void fadeIn(Duration duration, bool useNonLinearFading = false)
{
    float currentGain = getGain();

    if(fadeStartTime == fadeEndTime) fadeStartGain = 0.0f;
    else                             fadeStartGain = currentGain;

    fadeEndGain = 1.0f;

    fadeStartTime = audio.currentTime;
    fadeEndTime   = fadeStartTime + duration;

    fadeNonLinearly = useNonLinearFading;
}

void fadeOut(Duration duration, bool useNonLinearFading = false)
{
    float currentGain = getGain();

    fadeStartGain = currentGain;
    fadeEndGain = 0.0f;

    fadeStartTime = audio.currentTime;
    fadeEndTime   = fadeStartTime + duration;

    fadeNonLinearly = useNonLinearFading;
}

void setDesiredTag(DatumIndex index)
{
    if(tagIndex != index)
    {
        desiredTagIndex = index;
    }
}

void switchSoundTag(float temp)
{
    tagIndex = desiredTagIndex;
    desiredTagIndex = DatumIndex.none;

    auto tagSound = Cache.get!TagSound(tagIndex);

    // TODO pitch randomizer
    pitchRangeIndex = tagSound.selectPitchRange(temp);
    permutationIndex = tagSound.selectPermutation(pitchRangeIndex);


}


}
