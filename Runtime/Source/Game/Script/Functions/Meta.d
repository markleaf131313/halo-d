
module Game.Script.Functions.Meta;

import Game.Script.Value;
import Game.Script.Runtime;
import Game.Script.Thread;

import Game.Core;


private enum numOfFunctions = 528;

private template ToHsType(Types...)
{
    import std.meta : AliasSeq;

    static if(Types.length <= 0)
    {
        alias ToHsType = AliasSeq!();
    }
    else static if(is(Types[0] == void))  alias ToHsType = AliasSeq!(HsType.hsVoid,  ToHsType!(Types[1 .. $]));
    else static if(is(Types[0] == bool))  alias ToHsType = AliasSeq!(HsType.hsBool,  ToHsType!(Types[1 .. $]));
    else static if(is(Types[0] == float)) alias ToHsType = AliasSeq!(HsType.hsFloat, ToHsType!(Types[1 .. $]));
    else static if(is(Types[0] == int))   alias ToHsType = AliasSeq!(HsType.hsInt,   ToHsType!(Types[1 .. $]));
    else static if(is(Types[0] == short)) alias ToHsType = AliasSeq!(HsType.hsShort, ToHsType!(Types[1 .. $]));
    else static assert(0, "Type is not associated with as HsType.");
}

template getHsFunctionIndex(alias func)
{
    import std.traits : hasUDA, getUDAs;

    static if(hasUDA!(func, HsFunctionDef))
    {
        static assert(getUDAs!(func, HsFunctionDef).length == 1);
        enum getHsFunctionIndex = getUDAs!(func, HsFunctionDef)[0].index;
    }
}

struct HsFunctionDef
{
    int    index;
    string name;
    string helpMessage;
    typeof(HsFunctionMeta.compileFunction) compileFunction;
}

struct HsFunctionMeta
{
    int index;
    HsType returnType;

    string name;
    bool function(ref HsRuntime, ref immutable(HsFunctionMeta), DatumIndex) @nogc compileFunction;
    void function(ref HsRuntime, ref immutable(HsFunctionMeta), DatumIndex, bool) @nogc runFunction;
    string help;
    string parametersHelp;

    HsType[] parameters;

}

@nogc
bool hsCompileGenericFunction(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex nodeIndex)
{
    assert(0);
}

pure nothrow
HsFunctionMeta makeFunctionMetaGeneric(alias func)(string name)
{
    import std.traits : ReturnType, Parameters;

    if(!__ctfe)
    {
        assert(0);
    }

    template buildParameters(Types...)
    {
        import std.conv : to;

        static if(Types.length > 1)
        {
            enum buildParameters = "values[$ - " ~ to!string(Types.length) ~ "].as!(" ~ Types[0].stringof ~ "), "
                ~ buildParameters!(Types[1 .. $]);
        }
        else static if(Types.length == 1)
        {
            enum buildParameters = "values[$ - 1].as!(" ~ Types[0].stringof ~ ")";
        }
        else
        {
            enum buildParameters = "";
        }
    }

    static void runFunc(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex threadIndex, bool initStack)
    {
        HsThread* thread = &hsRuntime.threads[threadIndex];

        if(HsValue* result = thread.evaluateCurrentStack(meta.parameters, initStack))
        {
            HsValue[] values = result[0 .. Parameters!func.length];

            static if(is(ReturnType!func == void))
            {
                HsValue resultValue;
                func(hsRuntime, meta, mixin(buildParameters!(Parameters!func[2 .. $])));
            }
            else
            {
                HsValue resultValue = func(hsRuntime, meta, mixin(buildParameters!(Parameters!func[2 .. $])));
            }

            thread.returnCurrentStack(resultValue);
        }

    }

    return HsFunctionMeta(indexNone, ToHsType!(ReturnType!func), name, &hsCompileGenericFunction, &runFunc,
        "TODO: Implement Help", "<TODO arguments>", [ToHsType!(Parameters!func[2 .. $])]);
}

private HsFunctionMeta[numOfFunctions] buildFunctionList()
{
    import std.meta : AliasSeq, Alias;
    import std.traits : getUDAs;

    import Game.Script.Functions.Builtin;


    HsFunctionMeta[numOfFunctions] result;

    foreach(mod ; AliasSeq!(Game.Script.Functions.Builtin))
    foreach(member ; __traits(allMembers, mod))
    {
        alias symbol = Alias!(__traits(getMember, mod, member));
        alias udas   = getUDAs!(symbol, HsFunctionDef);

        static if(udas.length)
        {
            static assert(udas.length == 1, "Need exactly one instance of HsFunctionDef for: " ~ member);

            HsFunctionDef def = udas[0];
            HsFunctionMeta* meta = &result[def.index];

            if(meta.name !is null)
            {
                assert(0, "HsFunctionDef index already used, only allowed one function per index.");
            }

            static if(is(typeof(&symbol) == typeof(HsFunctionMeta.runFunction)))
            {
                meta.index = def.index;
                meta.name = def.name;
                meta.compileFunction = def.compileFunction;

                meta.runFunction = &symbol;
            }
            else
            {
                *meta = makeFunctionMetaGeneric!symbol(def.name);
                meta.index = def.index;
            }

        }
    }

    return result;
}

immutable functions = buildFunctionList();

/*
[

    // 0: begin
    // 1: begin_random
    // 2: if
    // 3: cond
    // 4: set
    // 5: and
    // 6: or
    // 7: +
    // 8: -
    // 9: *
];
*/

