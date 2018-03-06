
module Game.Core.Containers.CircularArray;

import std.math : nextPow2, isPowerOf2;
import std.conv : emplace;
import std.traits : hasElaborateDestructor;

import Game.Core.Containers.ArrayAllocators;

alias FixedCircularArray(T, int num) = CircularArray!(T, FixedArrayAllocator!num);

struct CircularArray(Element, Allocator)
{

static assert(isPowerOf2(Allocator.inlinedSize));
static assert(!hasElaborateDestructor!Element, "Do not use complicated types for this array.");

private uint headIndex;
private uint tailIndex;
private uint mask = nextPow2(Allocator.inlinedSize) - 1;
private Allocator.Def!Element allocator;

private inout(Element)* ptr() inout          { return allocator.allocation(); }

ref inout(Element) opIndex(uint index) inout { return ptr[(headIndex + index) & mask]; }
uint nextIndex(uint index) const             { return (index + 1) & mask; }
uint prevIndex(uint index) const             { return (index - 1) & mask; }
bool empty() const                           { return headIndex == tailIndex; }
bool full() const                            { return headIndex == nextIndex(tailIndex); }
void clear()                                 { headIndex = tailIndex = 0; }

size_t length() const { return (headIndex <= tailIndex) ? tailIndex - headIndex : mask - headIndex + tailIndex + 1; }

ref inout(Element) front() inout { return ptr[headIndex]; }
ref inout(Element) back()  inout { return ptr[prevIndex(tailIndex)]; }

void addFront()(auto ref Element element)
{
    if(!full())
    {
        headIndex = prevIndex(headIndex);
        ptr[headIndex] = element;
    }
}

void addFrontEmplace()
{
    if(!full())
    {
        headIndex = prevIndex(headIndex);
        emplace(ptr + headIndex);
    }
}

void addFront()
{
    if(!full())
    {
        headIndex = prevIndex(headIndex);
    }
}

void popFront()
{
    if(!empty())
    {
        headIndex = nextIndex(headIndex);
    }
}

void addBack()(auto ref Element element)
{
    if(!full())
    {
        ptr[tailIndex] = element;
        tailIndex = nextIndex(tailIndex);
    }
}

void addBack()
{
    if(!full())
    {
        tailIndex = nextIndex(tailIndex);
    }
}

void addBackEmplace()
{
    if(!full())
    {
        emplace(ptr + tailIndex);
        tailIndex = nextIndex(tailIndex);
    }
}

void popBack()
{
    if(!empty())
    {
        tailIndex = prevIndex(tailIndex);
    }
}

int opApply(scope int delegate(ref Element) dg)
{
    for(uint i = headIndex; i != tailIndex; i = nextIndex(i))
    {
        if(int result = dg(ptr[i]))
        {
            return result;
        }
    }

    return 0;
}

int opApply(scope int delegate(uint, ref Element) dg)
{
    for(uint i = headIndex; i != tailIndex; i = nextIndex(i))
    {
        if(int result = dg(i, ptr[i]))
        {
            return result;
        }
    }

    return 0;
}

}
