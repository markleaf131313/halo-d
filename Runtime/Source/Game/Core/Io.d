
module Game.Core.Io;

import std.stdio;


void rawRead(T)(ref File file, T* data)
{
    file.rawRead(data[0 .. 1]);
}