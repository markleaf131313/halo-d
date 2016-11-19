
module Game.Core.Containers.Array;

import std.traits : hasElaborateDestructor, isNumeric;


struct Array(Element, Allocator)
{

private int size = 0;
private int max  = (Allocator.hasInlinedElements ? Allocator.inlinedSize : 0);
private Allocator.Def!Element allocator;

pragma(inline, true)
@property Element* ptr()
{
    return allocator.allocation();
}

static if(hasElaborateDestructor!Element)
{
    static assert(false, "Do not use complicated types for this array.");
}

pragma(inline, true)
ref Element opIndex(int i)
{
    assert(i >= 0 && i < size);
    return ptr[i];
}

Element[] opSlice()
{
    return ptr[0 .. size];
}

static if(is(Element E : E*))
pragma(inline, true)
Element at(int index)
{
    return index >= 0 && index < size ? ptr[index] : null;
}

@property bool isEmpty() const
{
    return size == 0;
}

bool capcityReached() const
{
    return size == max;
}

void add()(auto ref Element element)
{
    ptr[size] = element;
    size += 1;
}

bool addFalloff()(auto ref Element element)
{
    if(size == max)
    {
        return true;
    }

    ptr[size] = element;
    size += 1;

    return false;
}

// todo rename "falloff" to stable instead ?
bool addUniqueFalloff()(auto ref Element element)
{
    import std.algorithm.searching : canFind;

    if(size == max)
    {
        return true;
    }

    if(canFind(this[], element))
    {
        return true;
    }

    ptr[size] = element;
    size += 1;

    return false;
}

Element pop()
{
    assert(size > 0);
    return ptr[size -= 1];
}

}