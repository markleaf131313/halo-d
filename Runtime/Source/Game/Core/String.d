
module Game.Core.String;

@nogc nothrow pure
bool iequals(const(char)[] a, const(char)[] b)
{
    if(a.length != b.length)
    {
        return false;
    }

    while(true)
    {
        if(a.length == 0)
        {
            return true;
        }

        uint lhs = a[0] - 'A';
        uint rhs = b[0] - 'A';

        a = a[1 .. $];
        b = b[1 .. $];

        if(lhs <= ('Z' - 'A')) lhs += 'a' - 'A';
        if(rhs <= ('Z' - 'A')) rhs += 'a' - 'A';

        if(lhs == rhs)
        {
            continue;
        }

        return false;
    }
}

@nogc nothrow pure
int icmp(const(char)[] a, const(char)[] b)
{
    while(true)
    {
        if(a.length == 0) return b.length == 0 ? 0 : -1;
        if(b.length == 0) return 1;

        uint lhs = a[0] - 'A';
        uint rhs = b[0] - 'A';

        a = a[1 .. $];
        b = b[1 .. $];

        if(lhs <= ('Z' - 'A')) lhs += 'a' - 'A';
        if(rhs <= ('Z' - 'A')) rhs += 'a' - 'A';

        int diff = lhs - rhs;

        if(diff == 0)
        {
            continue;
        }

        return diff;
    }
}

@nogc nothrow
auto snprintf(Args...)(char[] output, string format, auto ref Args args)
{
    import core.stdc.stdio : snprintf;
    import std.traits : isSomeString;

    static ref auto adjust(T)(auto ref T value)
    {
        static if(isSomeString!T) return cast(const(typeof(value[0]))*)value.ptr;
        else                      return value;
    }

    // TODO move to separate module ?
    pragma(inline, true)
    static auto map(alias call, Args...)(auto ref Args args)
    {
        template Transform(Vrgs...)
        {
            import std.meta : AliasSeq;

            static if(Vrgs.length) alias Transform = AliasSeq!(typeof(call(Vrgs[0].init)), Transform!(Vrgs[1 .. $]));
            else                   alias Transform = AliasSeq!();
        }

        static struct Result
        {
            Transform!Args args;
        }

        Result result = void;

        foreach(i, v ; args)
        {
            result.args[i] = call(v);
        }

        return result;
    }

    return snprintf(output.ptr, output.length, format.ptr, map!adjust(args).tupleof);
}
