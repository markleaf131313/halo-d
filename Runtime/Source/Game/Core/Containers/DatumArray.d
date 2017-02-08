
module Game.Core.Containers.DatumArray;

import std.conv   : emplace;
import std.traits : hasElaborateDestructor;

import Game.Core.Math   : min, max;
import Game.Core.Memory : mallocCast, free;
import Game.Core.Misc   : indexNone;

struct DatumIndex
{
    enum none = DatumIndex(cast(ushort)indexNone, indexNone);

    ushort i    = cast(ushort)indexNone;
    short  salt = indexNone;

    bool opCast(T : bool)() const
    {
        return this != none;
    }
}

struct DatumArray(T)
{

static assert(is(typeof(T.selfIndex) == DatumIndex) && T.selfIndex.offsetof == 0,
    "Type T does not meet requirements to be used with DatumArray \"" ~ this.stringof ~ "\"");

@disable this(this);

private int num;       // number of valid elements
private int max;       // maximum number of elements that can be held
private int length;    // the range between 0 and "max" where valid elements exist, essentially lastIndex + 1
private int nextIndex; // where to start searching when adding a new element

private T* elements;

~this()
{
    clear();
}

int opApply(scope int delegate(ref T) dg)
{
    foreach(ref element ; elements[0 .. length])
    {
        if(element.selfIndex.salt >= 0)
        {
            continue;
        }

        if(int result = dg(element))
        {
            return result;
        }
    }

    return 0;
}

int opApply(scope int delegate(int, ref T) dg)
{
    foreach(int i, ref element ; elements[0 .. length])
    {
        if(element.selfIndex.salt >= 0)
        {
            continue;
        }

        if(int result = dg(i, element))
        {
            return result;
        }
    }

    return 0;
}

int opApply(scope int delegate(DatumIndex, ref T) dg)
{
    foreach(ref element ; elements[0 .. length])
    {
        if(element.selfIndex.salt >= 0)
        {
            continue;
        }

        if(int result = dg(element.selfIndex, element))
        {
            return result;
        }
    }

    return 0;
}

void clear()
{
    if(elements)
    {
        static if(hasElaborateDestructor!T)
        {
            foreach(i, ref element ; elements[0 .. length])
            {
                if(element.selfIndex.salt & short.min)
                {
                    element.__xdtor();
                }
            }
        }

        free(elements);
    }

    num       = 0;
    max       = 0;
    length    = 0;
    nextIndex = 0;
    elements  = null;
}

void allocate(ushort numElements, short salt)
{
    clear();

    salt &= short.max;

    elements = mallocCast!T(numElements * T.sizeof);
    max      = numElements;

    foreach(ref element ; elements[0 .. max])
    {
        element.selfIndex.salt = salt;
    }
}

DatumIndex add()
{
    if(num >= max)
    {
        return DatumIndex.none;
    }

    int index;

    foreach(i ; 0 .. max)
    {
        index = (nextIndex + i) % max;

        if(elements[index].selfIndex.salt >= 0)
        {
            break;
        }
    }

    T* element = &elements[index];

    num += 1;
    nextIndex = index + 1;
    length    = .max(length, index + 1);

    DatumIndex result = { i: cast(ushort)index, salt: (element.selfIndex.salt + 1) | short.min };

    emplace(element); // NOTE: careful here, selfIndex gets overwritten as part of the initializer
    element.selfIndex = result;

    return result;
}

void remove(DatumIndex index)
{
    if(index == DatumIndex.none || index.i >= length)
    {
        return;
    }

    T* element = &elements[index.i];

    assert(element.selfIndex.salt == index.salt);

    if(element.selfIndex.salt == index.salt)
    {
        static if(hasElaborateDestructor!T)
        {
            element.__xdtor();
        }

        num -= 1;
        element.selfIndex.salt = index.salt & short.max;
        nextIndex              = min(nextIndex, index.i);

        if(length == index.i + 1)
        {
            while(length > 0 && (element.selfIndex.salt & short.min) == 0)
            {
                element -= 1;
                length  -= 1;
            }
        }
    }

}

ref inout(T) opIndex(DatumIndex index) inout
{
    return elements[index.i];
}

inout(T)* at(DatumIndex index) inout
{
    if(index.i < 0 || index.i >= length)
    {
        return null;
    }

    auto element = &elements[index.i];

    if(index != element.selfIndex)
    {
        return null;
    }

    return element;
}

}