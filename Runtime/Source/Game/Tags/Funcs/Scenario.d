
module Game.Tags.Funcs.Scenario;

mixin template TagScenario()
{
@nogc nothrow:

import Game.Core : indexNone;

short findScript(const(char)[] name)
{
    import std.string : fromStringz;
    import Game.Core.String : iequals;

    foreach(i, ref script ; scripts)
    {
        if(iequals(name, script.name))
        {
            return cast(short)i;
        }
    }

    return indexNone;
}

}
