
module Game.Core.Math.Vector;

import std.math;
import std.meta   : AliasSeq, allSatisfy;
import std.traits : isAssignable, isNumeric, isFloatingPoint, Unqual;
import std.conv   : to;

import Game.Core.Math.Algorithms;
import Game.Core.Meta;


pragma(inline, true) @nogc nothrow pure:


alias Vector2(T) = Vector!(2, T);
alias Vector3(T) = Vector!(3, T);
alias Vector4(T) = Vector!(4, T);

alias Vec2 = Vector2!float;
alias Vec3 = Vector3!float;
alias Vec4 = Vector4!float;

alias Vec2s = Vector2!short;

alias Vec2i = Vector2!int;
alias Vec3i = Vector3!int;
alias Vec4i = Vector4!int;


enum isVector(T) = is(T : Vector!S, S...);

struct Vector(int _S, _T) if(_S >= 2)
{
pragma(inline, true) @nogc nothrow pure:

    alias Type = _T;
    enum  size = _S;

    private enum isTypeAssignable(U) = isAssignable!(Type, U);

    union
    {
        private Type[size] values;

        struct
        {
            Type x;
            Type y;

            static if(size >= 3) Type z;
            static if(size >= 4) Type w;
        }
    }

    this(Type v)
    {
        values = v;
    }

    this(Args...)(Args args) if(args.length == size && allSatisfy!(isTypeAssignable, typeof(args)))
    {
        foreach(I, v ; args)
        {
            values[I] = v;
        }
    }

    this(V, Args...)(auto ref const(V) vec, Args args)
    if(isVector!V && vec.size + args.length == size && allSatisfy!(isTypeAssignable, AliasSeq!(V.Type, typeof(args))))
    {
        foreach(i ; staticIota!(vec.size))
        {
            values[i] = vec.values[i];
        }

        foreach(I, i ; staticIota!(vec.size, size))
        {
            values[i] = args[I];
        }
    }

    ref inout(Type) opIndex(int i) inout
    {
        return values[i];
    }

    ref auto opSlice()
    {
        return values;
    }

    bool opEquals()(auto ref const(Vector) a) const
    {
        return values[] == a.values[];
    }

    auto opBinary(string op, N)(N num) const
    if(isNumeric!N && op != "~")
    {
        Vector!(size, typeof(Type.init * N.init)) result = void;
        foreach(i ; staticIota!(size))
        {
            result.values[i] = mixin("values[i] " ~ op ~ " num");
        }
        return result;
    }

    auto opBinaryRight(string op, N)(N num) const
    if(isNumeric!N && op != "~")
    {
        Vector!(size, typeof(Type.init * N.init)) result = void;
        foreach(i ; staticIota!(size))
        {
            result.values[i] = mixin("num " ~ op ~ " values[i]");
        }
        return result;
    }

    ref Vector opOpAssign(string op, N)(N num)
    if(isNumeric!N && op != "~")
    {
        foreach(i ; staticIota!(size))
        {
            mixin("values[i] " ~ op ~ "= num;");
        }
        return this;
    }

    auto opBinary(string op, V)(auto ref const(V) vec) const
    if(isVector!V && V.size == size && op != "~")
    {
        Vector!(size, Unqual!(typeof(x * vec.x))) result = void;
        foreach(i ; staticIota!(size))
        {
            result.values[i] = mixin("values[i] " ~ op ~ " vec.values[i]");
        }
        return result;
    }

    auto opBinary(string op : "~", V)(auto ref const(V) vec) const
    if(isVector!V)
    {
        Vector!(size + V.size, Unqual!(typeof(x * vec.x))) result = void;
        foreach(i ; staticIota!(result.size))
        {
            static if(i < size) result.values[i] = values[i];
            else                result.values[i] = vec.values[i - size];
        }
        return result;
    }

    auto opBinary(string op : "~", N)(N num) const
    if(isNumeric!N)
    {
        Vector!(size + 1, Unqual!(typeof(x * num))) result = void;
        foreach(i ; staticIota!(size))
        {
            result.values[i] = values[i];
        }

        result.values[$ - 1] = num;

        return result;
    }

    auto opBinaryRight(string op : "~", N)(N num) const
    if(isNumeric!N)
    {
        Vector!(size + 1, Unqual!(typeof(x * num))) result = void;

        result.values[0] = num;

        foreach(i ; staticIota!(size))
        {
            result.values[i + 1] = values[i];
        }

        return result;
    }

    ref Vector opOpAssign(string op, V)(auto ref const(V) vec)
    if(isVector!V && V.size == size && op != "~")
    {
        foreach(i ; staticIota!(size))
        {
            mixin("values[i] " ~ op ~ "= vec.values[i];");
        }
        return this;
    }

    Vector opUnary(string op)() const if(op == "-" || op == "+")
    {
        Vector result = void;
        result.values[] = mixin(op ~ "values[]");
        return result;
    }

    @property auto opDispatch(string op)() const
    {
        Vector!(op.length, Type) result = void;

        foreach(I, i ; staticIota!(op.length))
        {
            static      if(op[i] == 'x') result[I] = values[0];
            else static if(op[i] == 'y') result[I] = values[1];
            else static if(op[i] == 'z' && size >= 3) result[I] = values[2];
            else static if(op[i] == 'w' && size >= 4) result[I] = values[3];
            else static assert(false, "Unknown swizzle character '" ~ c ~ "' in operator '" ~ op ~ "'.");
        }

        return result;
    }

    @property void opDispatch(string op, V)(auto ref V vec) if(isVector!V && op.length <= size && op.length == vec.size)
    {
        foreach(i ; staticIota!(op.length))
        {
            foreach(j ; staticIota!(i + 1, op.length))
            {
                static if(op[i] == op[j])
                {
                    static assert("Duplicate swizzle parameter not allowed in assignment '" ~ op[i] ~ "' in '" ~ op ~ "'.");
                }
            }
        }

        foreach(i ; staticIota!(op.length))
        {
            mixin("this." ~ op[i]) = vec[i];
        }
    }
}

auto abs(T, int size)(auto ref const(Vector!(size, T)) a)
{
    template impl(int i)
    {
        static if(i == 0) enum impl = "std.math.abs(a[0])";
        else              enum impl = impl!(i - 1) ~ ", std.math.abs(a[" ~ to!string(i) ~ "])";
    }

    return mixin("Vector!(size, T)(" ~ impl!(size - 1) ~ ")");
}

auto mix(T, int size)(auto ref const(Vector!(size, T)) x, auto ref const(Vector!(size, T)) y, T a)
if(isFloatingPoint!T)
{
    return x * (1 - a) + y * a;
}

auto saturate(T, int size)(auto ref const(Vector!(size, T)) x)
{
    template impl(int i)
    {
        enum v = to!string(i);
        static if(i == 0) enum impl = "Game.Core.Math.Algorithms.saturate(x[0])";
        else              enum impl = impl!(i - 1) ~ ", Game.Core.Math.Algorithms.saturate(x[" ~ v ~ "])";
    }

    return mixin("Vector!(size, T)(" ~ impl!(size - 1) ~ ")");
}


auto lengthSqr(T, int size)(auto ref const(Vector!(size, T)) vec)
{
    return dot(vec, vec);
}

auto length(T, int size)(auto ref const(Vector!(size, T)) vec) if(isFloatingPoint!T)
{
    return sqrt(lengthSqr(vec));
}

auto dot(T, int size)(auto ref const(Vector!(size, T)) a, auto ref const(Vector!(size, T)) b)
{
    template impl(int i)
    {
        enum s = to!string(i);
        static if(i == 0) enum impl = "a[0] * b[0]";
        else              enum impl =  impl!(i - 1) ~ " + a[" ~ s ~ "] * b[" ~ s ~ "]";
    }

    return mixin(impl!(size - 1));
}

auto perpDot(V)(auto ref const(V) a, auto ref const(V) b) if(isVector!V && V.size == 2)
{
    return a.x * b.y - a.y * b.x;
}

auto cross(T)(auto ref const(Vector!(3, T)) a, auto ref const(Vector!(3, T)) b)
{
    return Vector3!T(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x);
}

auto clampLength(V, T = V.Type)(auto ref const(V) vec, T maxLength) if(isVector!V)
{
    auto len = length(vec);

    if(maxLength < len)
    {
        return vec * (maxLength / len);
    }

    return vec;
}

auto normalize(T, int size)(ref Vector!(size, T) vec) if(isFloatingPoint!T)
{
    auto len = length(vec);

    if(len < T(0.0001))
    {
        return 0;
    }

    vec /= len;

    return len;
}

Vector3!T rotate(T)(Vector!(3,T) vec, T angle, Vector!(3,T) axis)
{
    T s = sin(angle);
    T c = cos(angle);

    return (vec * c) + (cross(axis, vec) * s) + axis * (dot(vec, axis) * (T(1) - c));
}

Vector3!T anyPerpendicularTo(T)(Vector!(3,T) vec)
{
    Vector3!T a = abs(vec);

    if(a.x > a.y || a.x > a.z)
    {
        if(a.y > a.z) return Vector3!T(vec.y, -vec.x, 0);
        else          return Vector3!T(-vec.z, 0, vec.x);
    }
    else
    {
        return Vector3!T(0, vec.z, -vec.y);
    }
}