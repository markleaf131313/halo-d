
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

mixin template exactPointer32(T, string name)
{
    static if((void*).sizeof == 4)
    {
        mixin("T* " ~ name ~ ";");
    }
    else
    {
        import core.memory : GC;

        private uint valuePtr__;

        mixin("@property @nogc nothrow inout(T)* " ~name~ "() inout { return cast(inout(T)*)valuePtr__; }");
        mixin("@property @nogc nothrow void " ~name~ "(const(T)* p)" ~
            "in   { assert(cast(ulong)p <= 0xFFFF_FFFF); }" ~ // assert(GC.addrOf(cast(void*)p) is null &&  TODO, too many problems right with it
            "body { valuePtr__ = cast(uint)p; }");
    }
}