
module Game.Tags.Util;

import std.traits : EnumMembers;

import Game.Tags.Types;
import Game.Tags.Generated.Tags;
import Game.Tags.Generated.Meta;

import TagEnums = Game.Tags.Generated.Enums;

import Game.Core;

@nogc nothrow
float evalTagFunctionWithTime(TagEnums.Function type, float input)
{
    switch(type) with(TagEnums)
    {
    case Function.one:  return 1.0f;
    case Function.zero: return 0.0f;
    case Function.cosine:                     break; // TODO implement these
    case Function.cosineVariablePeriod:       break;
    case Function.diagonalWave:               break;
    case Function.diagonalWaveVariablePeriod: break;
    case Function.slide:                      break;
    case Function.slideVariablePeriod:        break;
    case Function.noise:                      break;
    case Function.jitter:                     break;
    case Function.wander:                     break;
    case Function.spark:                      break;
    default:
    }

    return 0.0f;
}

@nogc nothrow
float evalTagMapToFunction(TagEnums.MapToFunction type, float input)
{
    input = clamp(input, 0.0f, 1.0f);

    switch(type) with(TagEnums)
    {
    case MapToFunction.linear:     return input;
    case MapToFunction.early:      break; // TODO implement these
    case MapToFunction.veryEarly:  break;
    case MapToFunction.late:       break;
    case MapToFunction.veryLate:   break;
    case MapToFunction.cosine:     break;
    default:
    }

    return input;
}

private template TagIdToType(string id)
{
    import std.ascii : toUpper;
    mixin("alias TagIdToType = Tag" ~ toUpper(id[0]) ~ id[1 .. $] ~ ";");
}

auto InvokeByTag(alias invoker, Args...)(TagId id, auto ref Args args)
{

    switch(id)
    {
        foreach(i, member ; EnumMembers!TagId)
        {
            static if(is(typeof(return) Return))
            {
                case member: mixin("return invoker!(TagIdToType!(EnumMembers!TagId[i].stringof))(args);");
            }
            else
            {
                case member: mixin("invoker!(TagIdToType!(EnumMembers!TagId[i].stringof))(args); break;");
            }
        }
    default:
    }

    static if(is(typeof(return) Return) && is(Return.init))
    {
        return Return.init;
    }
}