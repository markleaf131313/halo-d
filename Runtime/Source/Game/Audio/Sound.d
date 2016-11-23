
module Game.Audio.Sound;

import OpenAL;
import Vorbis;

import Game.Audio.Adpcm;
import Game.Audio.Audio : Audio;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World : World;



struct Sound
{

@disable this(this);

struct Spatial
{
    enum Type
    {
        atListener,
        relativeToPlayers,
        relativeToWorldOrigin,
    }

    Type type;

    float volume;
    float scale;

    Vec3 position;
    Vec3 direction;
    Vec3 velocity;
    World.Location location;
}

DatumIndex selfIndex;
Audio* audio;

DatumIndex tagIndex;

uint    source  = AL_NONE;
uint[2] buffers = AL_NONE;

Spatial spatial;

float pitch;

int pitchRangeIndex;
int permutationIndex;

uint readOffset;

align(OggVorbis_File.alignof) void[OggVorbis_File.sizeof] oggFileBuffer = void;

@property OggVorbis_File* oggFile()
{
    return cast(OggVorbis_File*)oggFileBuffer;
}

~this()
{
    alDeleteSources(1, &source);
    alDeleteBuffers(buffers.length, buffers.ptr);
}

void update()
{
    const tagSound       = Cache.get!TagSound(tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[permutationIndex];

    if(source == AL_NONE)
    {
        switch(tagSound.compression)
        {
        case TagEnums.SoundCompression.xboxAdpcm:

            break;
        case TagEnums.SoundCompression.ogg:

            ov_callbacks callbacks = void;

            callbacks.close_func = null;
            callbacks.tell_func  = null;
            callbacks.seek_func  = null;
            callbacks.read_func  = &readOggCallback;

            ov_open_callbacks(&this, oggFile, null, 0, callbacks);

            break;
        default:
            audio.sounds.remove(selfIndex);
            return;
        }

        alGenSources(1, &source);
        alGenBuffers(buffers.length, buffers.ptr);

        fillBuffer(0);
        fillBuffer(1);

        alSourcePlay(source);
    }

    int processed;
    alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);

    bool removed;
    while(processed--)
    {
        uint buffer;
        alSourceUnqueueBuffers(source, 1, &buffer);

        if(!fillBuffer(buffer == buffers[0] ? 0 : 1))
        {
            break;
        }
    }

    int state;
    alGetSourcei(source, AL_SOURCE_STATE, &state);

    if(state != AL_PLAYING)
    {
        if(readOffset >= tagPermutation.samples.size)
        {
            audio.sounds.remove(selfIndex);
        }
        else
        {
            alSourcePlay(source);
        }
    }
}

bool fillBuffer(int i)
{
    const tagSound       = Cache.get!TagSound(tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[permutationIndex];

    if(readOffset >= tagPermutation.samples.size)
    {
        return false;
    }

    uint buffer = buffers[i];

    byte[8256] data = void;
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
        size_t encodedLength = compressedAdpcmSize(data.length, numChannels);
        encodedLength        = min(encodedLength, tagPermutation.samples.size - readOffset);
        length               = decodedAdpcmSize(encodedLength, numChannels);

        decodeAdpcm(sample[readOffset .. readOffset + encodedLength], numChannels, data[0 .. length]);
        readOffset += encodedLength;
        break;
    case TagEnums.SoundCompression.ogg:
        while(length < data.length)
        {
            int ret = ov_read(oggFile, data.ptr + length, cast(int)(data.length - length), 0, 2, 1, null);

            if(ret <= 0)
            {
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

    const tagSound       = Cache.get!TagSound(tagIndex);
    const tagPitchRange  = &tagSound.pitchRanges[pitchRangeIndex];
    const tagPermutation = &tagPitchRange.permutations[permutationIndex];

    size_t total = min(size * num, tagPermutation.samples.size - readOffset);

    const void* sample = audio.samples[tagPermutation.cacheBufferIndex];
    memcpy(data, sample + readOffset, total);

    readOffset += cast(int)total;

    return total;
}

private extern(C) static
size_t readOggCallback(void* ptr, size_t size, size_t num, void* data) nothrow
{
    return (cast(Sound*)data).readOgg(size, num, ptr);
}

}
