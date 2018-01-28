
module Game.Core.Misc;

enum indexNone = -1;

uint length32(T)(T[] array)
{
    return cast(uint)array.length;
}

template multichar(string op)
{
    static if(op.length == 2)
    {
        enum short multichar = (op[0] << 8) | op[1];
    }
    else static if(op.length == 4)
    {
        enum int multichar = (op[0] << 24) | (op[1] << 16) | (op[2] << 8) | op[3];
    }
    else
    {
        static assert(0, "Requires string input to be size of 4 or 2, not '" ~ op ~ "'.");
    }
}

struct SlaveComputeIdentifier
{
@nogc nothrow:

    void setPrevious(ref const(MasterComputeIdentifier) o)
    {
        id = o.id - 1;
    }

    bool assignEqual(ref const(MasterComputeIdentifier) o)
    {
        if(id != o.id)
        {
            id = o.id;
            return false;
        }

        return true;
    }

    private uint id;
}

struct MasterComputeIdentifier
{
@nogc nothrow:

    void advance()
    {
        id += 1;
    }

    private uint id;
}
