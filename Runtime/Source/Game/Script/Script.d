
module Game.Script.Script;

import std.bitmanip : bitfields;

import Game.Script.Value;

import Game.Core : DatumIndex, indexNone;

enum HsScriptType
{
    startup,
    dormant,
    continuous,
    declaration, // aka "static"
    stub,
}

struct HsFunction
{
    HsType returnType;
    string name;

    string info;
    string paramInfo;

    HsType[] paramTypes;
}

struct HsGlobal
{
    HsType type;
    HsValue value;

}

struct HsSyntaxNode
{

static assert(this.sizeof == 0x14);

struct Flags
{
    mixin(bitfields!(
        bool, "isPrimitive",              1,
        bool, "isScenarioScript",         1,
        bool, "isGlobalIndex",            1,
        bool, "manuallyGarbageCollected", 1,
        ushort, "", 12,
    ));
}

short selfSalt;

union
{
    HsType constantType;
    short  functionIndex;
}

HsType type;
Flags flags;

DatumIndex nextExpression;
uint offset = indexNone;
HsValue value;

}
