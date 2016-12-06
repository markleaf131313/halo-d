
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

