
module Game.Core.Math.Algorithms;

public import std.algorithm.comparison : min, max;

import std.traits : isFloatingPoint, isIntegral, isNumeric;
import std.math   : PI;

import Game.Core.Math.Orientation;
import Game.Core.Math.Vector;


pragma(inline, true) @nogc nothrow pure:


auto toRadians(T)(T degrees) if(isFloatingPoint!T)
{
    return degrees * (T(PI) / 180);
}

auto toDegrees(T)(T radians) if(isFloatingPoint!T)
{
    return radians * (180 / T(PI));
}

T clampedIncrement(T)(T value) if(isIntegral!T)
{
    return value == T.max ? value : cast(T)(value + 1);
}

T decrementToZero(T)(T value) if(isIntegral!T)
{
    return value > 0 ? value - 1 : value;
}

auto clamp(T)(auto ref const(T) value, auto ref const(T) min, auto ref const(T) max)
if(isNumeric!T)
{
    if(value < min) return min;
    if(value > max) return max;
    return value;
}

auto mix(T, U)(T x, T y, U a)
if(isNumeric!T && isFloatingPoint!U)
{
    return (1 - a) * x + a * y;
}

auto sqr(T)(auto ref const(T) a)
{
    return a * a;
}

T saturate(T)(T value) if(isFloatingPoint!T)
{
    return clamp!T(value, 0, 1);
}

// TODO rename possibly?
T barycentricInterpolate(T, U)(T v0, T v1, T v2, U uv) if(isVector!U && U.size == 2 && isFloatingPoint!(U.Type))
{
    return (v1 - v0) * uv.x + (v2 - v0) * uv.y + v0;
}