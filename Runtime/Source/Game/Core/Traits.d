
module Game.Core.Traits;

import std.traits : AliasSeq, EnumMembers;

template EnumNamesAliasSeq(T) if(is(T == enum))
{
    alias EnumNamesAliasSeq = EnumNamesAliasSeqImpl!(EnumMembers!T);
}

private template EnumNamesAliasSeqImpl(T...)
{
    static if(T.length == 1)
    {
        alias EnumNamesAliasSeqImpl = AliasSeq!(T[0].stringof);
    }
    else static if(T.length > 0)
    {
        alias EnumNamesAliasSeqImpl = AliasSeq!(
            T[0].stringof,
            EnumNamesAliasSeqImpl!(T[1 .. $/2]),
            EnumNamesAliasSeqImpl!(T[$/2 .. $]));
    }
    else
    {
        alias EnumNamesAliasSeqImpl = AliasSeq!();
    }
}

template enumNamesArray(T) if(is(T == enum))
{
    enum enumNamesArray = [ EnumNamesAliasSeq!T ];
}

@nogc nothrow pure string enumName(T)(T value)
{
    switch(value)
    {
        foreach(i, member ; EnumMembers!T)
        {
            case member: return EnumMembers!T[i].stringof;
        }
    default:
    }

    return "Invalid " ~ T.stringof;
}
