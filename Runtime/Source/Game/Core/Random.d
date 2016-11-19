
module Game.Core.Random;

import std.random;

import Game.Core.Math : Vec3, normalize;
import Game.Tags : TagBounds;

int randomValue(T : int)(int min = int.min, int max = int.max)
{
    return uniform!"[]"(min, max);
}

short randomValue(TagBounds!short bounds)
{
    return uniform!"[]"(bounds.lower, bounds.upper);
}

float randomValue(TagBounds!float bounds)
{
    return (bounds.upper - bounds.lower) * randomPercent() + bounds.lower;
}

float randomPercent()
{
    enum large = 2 ^^ 22;
    return randomValue!int(0, large) / float(large);
}

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