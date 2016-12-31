module OpenGL.Loader;

import std.meta   : Alias;
import std.traits : isFunctionPointer;

import OpenGL.FuncPtrs;
import OpenGL.Types;
import OpenGL.Enums;


alias Loader = void* delegate(const(char)*);


export bool gladLoadGL(Loader load)
{
    static import Ptrs = OpenGL.FuncPtrs;

    foreach(name ; __traits(allMembers, Ptrs))
    {
        alias member = Alias!(__traits(getMember, Ptrs, name));

        static if(isFunctionPointer!member)
        {
            member = cast(typeof(member))load(name);
            assert(member, name ~ " is null, could not optain function pointer.");
        }
    }


    return true;
}

