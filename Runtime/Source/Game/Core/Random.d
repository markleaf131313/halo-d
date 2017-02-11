
module Game.Core.Random;

import std.random;

import Game.Core.Math : Vec3, normalize, cross, rotate;
import Game.Tags : TagBounds;

// TODO this engine is kind of wrong
//      it can't generate within bounds of [int.min, int.max]
//      like is used in randomValue!int()
private __gshared MinstdRand engine = MinstdRand(13);

@nogc nothrow
int randomValue(T : int)(int min = int.min, int max = int.max)
{
    // TODO if uniform is nothrow then
    // return uniform!"[]"(min, max);
    engine.popFront();
    return cast(int)(long(engine.front) % ((1L + max) - min) + min);
}

@nogc nothrow
short randomValue(TagBounds!short bounds)
{
    return cast(short)randomValue!int(bounds.lower, bounds.upper);
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
    return randomValue!int(0, large) / float(large);
}

@nogc nothrow
Vec3 randomUnitVector()
{
    static int rand() { return randomValue!int(short.min + 1, short.max); }

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