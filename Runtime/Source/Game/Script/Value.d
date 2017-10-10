
module Game.Script.Value;

import Game.Core;

private immutable HsValue function(HsValue) @nogc nothrow [HsType.max + 1][HsType.max + 1] conversionTable;

shared static this()
{

    conversionTable[HsType.hsVoid][HsType.hsBool .. HsType.max] = function(HsValue v) { return HsValue(0); };

    conversionTable[HsType.hsShort][HsType.hsInt]   = function(HsValue v) { return HsValue(cast(short)v.as!int); };
    conversionTable[HsType.hsShort][HsType.hsFloat] = function(HsValue v) { return HsValue(cast(short)v.as!float); };

    conversionTable[HsType.hsInt][HsType.hsShort] = function(HsValue v) { return HsValue(int(v.as!short)); };
    conversionTable[HsType.hsInt][HsType.hsFloat] = function(HsValue v) { return HsValue(cast(int)v.as!float); };

    conversionTable[HsType.hsFloat][HsType.hsShort] = function(HsValue v) { return HsValue(float(v.as!short)); };
    conversionTable[HsType.hsFloat][HsType.hsInt]   = function(HsValue v) { return HsValue(float(v.as!int)); };

}

enum HsType : short
{
    unparsed,
    specialForm,
    functionName,
    passthrough,

    hsVoid,
    hsBool,
    hsFloat,
    hsShort,
    hsInt,
    string,
    script,

    triggerVolume,
    cutsceneFlag,
    cutsceneCameraPoint,
    cutsceneTitle,
    cutsceneRecording,
    deviceGroup,
    ai,
    aiCommandList,
    startingProfile,
    conversation,

    navpoint,
    hudMessage,

    objectList,

    sound,
    effect,
    damage,
    loopingSound,
    animationGraph,
    actorVariant,
    damageEffect,
    objectDefinition,

    gameDifficulty,
    team,
    aiDefaultState,
    actorType,
    hudCorner,

    object,
    unit,
    vehicle,
    weapon,
    device,
    scenery,

    objectName,
    unitName,
    vehicleName,
    weaponName,
    deviceName,
    sceneryName,

    invalid = indexNone,
}

@nogc nothrow pure
HsType toHsType(const(char)[] text)
{
    switch(text)
    {
    case "unparsed":      return HsType.unparsed;
    case "special_form":  return HsType.specialForm;
    case "function_name": return HsType.functionName;
    case "passthrough":   return HsType.passthrough;

    case "void":   return HsType.hsVoid;
    case "bool":   return HsType.hsBool;
    case "float":  return HsType.hsFloat;
    case "short":  return HsType.hsShort;
    case "int":    return HsType.hsInt;
    case "string": return HsType.string;
    case "script": return HsType.script;

    case "trigger_volume":        return HsType.triggerVolume;
    case "cutscene_flag":         return HsType.cutsceneFlag;
    case "cutscene_camera_point": return HsType.cutsceneCameraPoint;
    case "cutscene_title":        return HsType.cutsceneTitle;
    case "cutscene_recording":    return HsType.cutsceneRecording;
    case "device_group":          return HsType.deviceGroup;
    case "ai":                    return HsType.ai;
    case "ai_command_list":       return HsType.aiCommandList;
    case "starting_profile":      return HsType.startingProfile;
    case "conversation":          return HsType.conversation;

    case "navpoint":    return HsType.navpoint;
    case "hud_message": return HsType.hudMessage;

    case "object_list": return HsType.objectList;

    case "sound":             return HsType.sound;
    case "effect":            return HsType.effect;
    case "damage":            return HsType.damage;
    case "looping_sound":     return HsType.loopingSound;
    case "animation_graph":   return HsType.animationGraph;
    case "actor_variant":     return HsType.actorVariant;
    case "damage_effect":     return HsType.damageEffect;
    case "object_definition": return HsType.objectDefinition;

    case "game_difficulty":  return HsType.gameDifficulty;
    case "team":             return HsType.team;
    case "ai_default_state": return HsType.aiDefaultState;
    case "actor_type":       return HsType.actorType;
    case "hud_corner":       return HsType.hudCorner;

    case "object":  return HsType.object;
    case "unit":    return HsType.unit;
    case "vehicle": return HsType.vehicle;
    case "weapon":  return HsType.weapon;
    case "device":  return HsType.device;
    case "scenery": return HsType.scenery;

    case "object_name":  return HsType.objectName;
    case "unit_name":    return HsType.unitName;
    case "vehicle_name": return HsType.vehicleName;
    case "weapon_name":  return HsType.weaponName;
    case "device_name":  return HsType.deviceName;
    case "scenery_name": return HsType.sceneryName;

    default: return HsType.invalid;
    }
}

@nogc nothrow pure
bool isObjectIndex(HsType type)
{
    return type >= HsType.object && type <= HsType.scenery;
}

@nogc nothrow pure
bool isObjectName(HsType type)
{
    return type >= HsType.objectName && type <= HsType.sceneryName;
}

@nogc nothrow
bool isConvertableTo(HsType fromType, HsType toType)
{
    static immutable conversion =
    [
        0xFFFF, // object
        0x0003, // unit
        0x0002, // vehicle
        0x0004, // weapon
        0x0040, // device
        0x0080, // scenery
    ];

    if(fromType == HsType.passthrough || fromType == toType)
    {
        return true;
    }

    if (toType.isObjectIndex)
    {
        int toIndex = toType - HsType.object;
        int fromIndex;

        if     (fromType.isObjectName)  fromIndex = fromType - HsType.objectName;
        else if(fromType.isObjectIndex) fromIndex = fromType - HsType.object;
        else                            return false;

        return (conversion[fromIndex] & conversion[toIndex]) == conversion[fromIndex];
    }
    else if(toType.isObjectName)
    {
        int toIndex = toType - HsType.objectName;

        if(fromType.isObjectName)
        {
            int fromIndex = fromType - HsType.objectName;
            return (conversion[fromIndex] & conversion[toIndex]) == conversion[fromIndex];
        }

        return false;
    }

    return conversionTable[toType][fromType] !is null;
}

@nogc nothrow
HsValue convertTo(HsType fromType, HsType toType, HsValue value)
{
    if(fromType != toType && fromType != HsType.passthrough && !toType.isObjectName)
    {
        if(toType.isObjectIndex)
        {
            if(fromType.isObjectName)
            {
                assert(0, "TODO implement object_name to object conversion"); // TODO
            }
        }
        else
        {
            return conversionTable[toType][fromType](value);
        }
    }

    return value;
}

//-//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct HsValue
{
@nogc nothrow:

static assert(this.sizeof == 4);

union
{
    uint       bits = uint.max;
    short      asShort;
    int        asInt;
    float      asFloat;
    DatumIndex index;
}


this(short value)      { asShort = value; }
this(int   value)      { asInt   = value; }
this(float value)      { asFloat = value; }
this(DatumIndex index) { this.index = index; }

ref inout(T) as(T)() inout
{
    static assert(T.sizeof <= this.sizeof);
    return *cast(inout(T)*)&this;
}

}



