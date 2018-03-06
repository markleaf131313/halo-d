
module Game.Core.Containers.Array;

import std.conv : emplace;
import std.traits : hasElaborateDestructor, isNumeric;

import Game.Core.Containers.ArrayAllocators : FixedArrayAllocator;


alias FixedArray(T, int num) = Array!(T, FixedArrayAllocator!num);


struct Array(Element, Allocator)
{

static assert(!hasElaborateDestructor!Element, "Do not use complicated types for this array.");

private int size = 0;
private int max  = (Allocator.hasInlinedElements ? Allocator.inlinedSize : 0);
private Allocator.Def!Element allocator;

Element*  ptr()            { return allocator.allocation(); }
void      clear()          { size = 0; }
uint      length() const   { return size; }
void      resizeToMax()    { resize(max); }
bool      empty() const    { return size == 0; }
bool      capcityReached() const { return size >= max; }
uint      opDollar() const { return size; }
Element[] opSlice()        { return ptr[0 .. size]; }

ref Element opIndex(size_t i)
{
    assert(i >= 0 && i < size);
    return ptr[i];
}

static if(is(Element E : E*))
Element at(int index)
{
    return index >= 0 && index < size ? ptr[index] : null;
}

void resize(int newSize)
{
    if(newSize > max)
    {
        assert(0); // TODO implement for other allocators
    }

    if(newSize > size)
    {
        foreach(ref element ; ptr[size .. newSize])
        {
            emplace(&element);
        }
    }

    size = newSize;
}

uint add()(auto ref Element element)
{
    ptr[size] = element;
    size += 1;
    return size - 1;
}

void addOverthrowFull()(auto ref Element element)
{
    if(max <= 0)
    {
        return;
    }

    if(size >= max)
    {
        ptr[size - 1] = element;
    }
    else
    {
        add(element);
    }
}

bool addFalloff()(auto ref Element element)
{
    if(size >= max)
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
