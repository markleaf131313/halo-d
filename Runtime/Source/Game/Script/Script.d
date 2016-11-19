
module Game.Script.Script;

import std.bitmanip : bitfields;

import Game.Script.Value;

import Game.Core.Containers : DatumIndex;

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

DatumIndex selfIndex;

union
{
    HsType constantType;
    short  index;
}

HsType type;

mixin(bitfields!(
    bool, "isScriptIndex",        1,
    bool, "dontGarbageCollected", 1,
    ushort, "", 14,
));

DatumIndex nextExpression;
int offset;
HsValue value;


}