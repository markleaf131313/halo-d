
module Game.Tags.Util;

import Game.Tags.Types;
import Game.Tags.Generated.Tags;
import Game.Tags.Generated.Meta;

template TagIdToType(string id)
{
    import std.ascii : toUpper;
    mixin("alias TagIdToType = Tag" ~ toUpper(id[0]) ~ id[1 .. $] ~ ";");
}

auto InvokeByTag(alias invoker, Args...)(TagId id, ref Args args)
{
    template impl(types...)
    {
        static if(types.length == 1) enum impl = "";
        else
        {
            enum impl = "TagId." ~ types[0] ~ ": &invoker!" ~ TagIdToType!(types[0]).stringof ~ ", " ~ impl!(types[1 .. $]);
        }
    }

    enum map = mixin("[" ~ impl!(__traits(allMembers, TagId)) ~ "]");

    if(auto func = id in map)
    {
        return (*func)(args);
    }

    static if(is(typeof(return) Return) && is(Return.init))
    {
        return Return.init;
    }
}