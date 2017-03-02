
module Game.Core.Random;

import std.random : Xorshift, unpredictableSeed;

import Game.Core.Math : Vec3, normalize, cross, rotate;
import Game.Tags : TagBounds;

private __gshared Xorshift engine;

shared static this()
{
    engine = Xorshift(unpredictableSeed);
}

@nogc nothrow
int randomValue(int min = int.min, int max = int.max)
{
    engine.popFront();
    return cast(int)((ulong(engine.front) * (ulong(max) - ulong(min))) >>> 32) + min;
}

@nogc nothrow
int randomValueFromZero(int maxIndex)
{
    return randomValue(0, maxIndex);
}

@nogc nothrow
short randomValue(TagBounds!short bounds)
{
    return cast(short)randomValue(bounds.lower, bounds.upper);
}

@nogc nothrow
float randomValue(TagBounds!float bounds)
{
    return (bounds.upper - bounds.lower) * randomPercent() + bounds.lower;
}

@nogc nothrow
float randomPercent()
{
    enum large = 2 ^^ 22;
    return randomValue(0, large) / float(large - 1);
}
@nogc nothrow
float randomNoise(float noise)
{
    return (noise + noise) * randomPercent() - noise;
}

@nogc nothrow
Vec3 randomUnitVector()
{
    static int rand()
    {
        return randomValue(short.min, short.max);
    }

    Vec3 result = Vec3(rand(), rand(), rand());

    if(normalize(result) == 0.0f)
    {
        return Vec3(1, 0, 0);
    }

    return result;
}

@nogc nothrow
Vec3 randomRotatedVector(Vec3 direction, TagBounds!float angleBounds)
{
    Vec3 axis = cross(randomUnitVector(), direction);

    if(normalize(axis) != 0.0f)
    {
        direction = rotate(direction, randomValue(angleBounds), axis);
    }

    return direction;
}
