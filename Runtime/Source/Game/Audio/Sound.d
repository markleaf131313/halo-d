
module Game.Audio.Sound;

import OpenAL;

import Game.Audio.Audio : Audio;

import Game.Core;
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

uint source = AL_NONE;

Spatial spatial;

float pitch;

int pitchRangeIndex;
int permutationIndex;

~this()
{
    if(source != AL_NONE)
    {
        alDeleteSources(1, &source);
    }
}

}
