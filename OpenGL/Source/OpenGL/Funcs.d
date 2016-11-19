
module OpenGL.Funcs;

import std.meta   : Alias;
import std.traits : Parameters, isFunctionPointer;

static import Ptrs = OpenGL.FuncPtrs;
import OpenGL.Types;

string generate()
{
    if(!__ctfe) return "";

    string result;

    foreach(name ; __traits(allMembers, Ptrs))
    {
        alias member = Alias!(__traits(getMember, Ptrs, name));

        static if(isFunctionPointer!member)
        {
            result ~= "\nauto " ~ name ~ "(Parameters!(Ptrs." ~ name ~ ") params) { return Ptrs." ~ name ~ "(params); }";
        }
    }

    return result;
}


@nogc export nothrow
{
    mixin(generate());
}