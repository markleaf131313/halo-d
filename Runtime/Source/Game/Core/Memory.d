
module Game.Core.Memory;

import std.conv : emplace;
import std.traits : hasElaborateDestructor;

import core.stdc.stdlib : stdMalloc = malloc;
public import core.stdc.stdlib : free;


@nogc nothrow
T* mallocCast(T)(size_t size)
{
    return cast(T*)stdMalloc(size);
}

@nogc nothrow
T* mallocEmplace(T, Args...)(Args args) if(is(T == struct))
{
    T* ptr = malloc!T(T.sizeof);

    if(ptr is null)
    {
        return null;
    }

    return emplace(ptr, args);;
}

void destroyFree(T)(T* object)
{
    if(object !is null)
    {
        static if(hasElaborateDestructor!T)
        {
            object.__xdtor();
        }

        free(object);
    }
}

static if((void*).sizeof == 4)
{
    alias ExactPointer32(T) = T*;
}
else
{
    struct ExactPointer32(T)
    {
        private uint ptrValue;

        alias ptr this;

        @nogc nothrow
        inout(T)* ptr() inout
        {
            return cast(T*)ptrValue;
        }

        @nogc nothrow
        void ptr(const(T)* p)
        in
        {
            assert(cast(size_t)p <= 0xFFFF_FFFF); // assert(GC.addrOf(cast(void*)p) is null &&  TODO, too many problems right with it
        }
        body
        {
            ptrValue = cast(uint)p;
        }
    }
}