
module Game.Core.Meta;

import std.meta;

template staticIota(int end)
{
    alias staticIota = staticIota!(0, end);
}

template staticIota(int start, int end)
{
    static if(start < end) alias staticIota = AliasSeq!(start, staticIota!(start + 1, end));
    else                   alias staticIota = AliasSeq!();
}

enum declaresMember(T, string name) = staticIndexOf!(name, __traits(allMembers, T)) != -1;
