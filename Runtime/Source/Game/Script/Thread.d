
module Game.Script.Thread;

import Game.Script.Functions.Meta;
import Game.Script.Runtime;
import Game.Script.Script;
import Game.Script.Value;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct HsThread
{
@nogc:

enum Type
{
    script,
    global,
    runtime,
}

struct Flags
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        bool, "stackNeedsInit", 1,
        ushort, "", 15
    ));
}

struct StackFrame
{
@nogc:

    StackFrame* previous;
    HsValue*    result;
    DatumIndex  expression;
    short       length;
    short       index;

    void* data()
    {
        return cast(void*)&this + index.offsetof + index.sizeof;
    }

    ref HsValue valueAt(int index)
    {
        return *cast(HsValue*)(data + index * HsValue.sizeof);
    }

    StackFrame* nextStackFrame()
    {
        return cast(StackFrame*)(data + length);
    }
}

enum dormantTime = indexNone - 1;

DatumIndex selfIndex;

HsRuntime* hsRuntime;

Flags flags;
Type type;
int scriptIndex;
int sleepUntil;
int previousSleepUntil;
HsValue result;
StackFrame* stackFrame;

void[1024] stack;

void run()
{
    // TODO temporary implementation
    // TODO sleeping

    if(stackFrame is stack.ptr && type == Type.script)
    {
        TagScenario* tagScenario = Cache.inst.scenario;
        const tagScript = &tagScenario.scripts[scriptIndex];

        evaluateSyntaxNode(*cast(DatumIndex*)&tagScript.rootExpressionIndex, &result);
    }

    while(stackFrame !is stack.ptr)
    {
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[stackFrame.expression];

        bool initStack = flags.stackNeedsInit;
        flags.stackNeedsInit = false;

        if(node.flags.isScenarioScript)
        {
            assert(0); // TODO
        }
        else
        {
            auto meta = &hsFunctionMetaAt(node.functionIndex);
            meta.runFunction(*hsRuntime, *meta, selfIndex, initStack);
        }
    }

    // TODO kill thread ?
}

private void pushStack(DatumIndex nodeIndex, HsValue* result)
{
    StackFrame* prevStackFrame = stackFrame;

    prevStackFrame.result = result;

    stackFrame = stackFrame.nextStackFrame;
    *stackFrame = StackFrame(prevStackFrame, null, nodeIndex);
    flags.stackNeedsInit = true;
}

void evaluateSyntaxNode(DatumIndex nodeIndex, HsValue* result)
{
    HsSyntaxNode* node = &hsRuntime.syntaxNodes[nodeIndex];

    if(node.flags.isPrimitive)
    {
        if(node.flags.isGlobalIndex)
        {
            if(node.value.as!short < 0)
            {
                assert(0); // TODO
            }
            else
            {
                assert(0); // TODO
            }
        }
        else
        {
            *result = convertTo(node.constantType, node.type, node.value);
        }
    }
    else
    {
        pushStack(nodeIndex, result);
    }
}

HsValue* evaluateCurrentStack(const(HsType[]) parameters, bool stackNeedsInit)
{

    if(stackNeedsInit)
    {
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[stackFrame.expression];

        stackFrame.index      = 0;
        stackFrame.length     = cast(short)(parameters.length * 4 + 4);
        stackFrame.valueAt(0) = node.value;
    }

    if(stackFrame.index < parameters.length)
    {
        DatumIndex nodeIndex = stackFrame.valueAt(0).as!DatumIndex;
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[nodeIndex];

        if(node.type == parameters[stackFrame.index])
        {
            evaluateSyntaxNode(nodeIndex, &stackFrame.valueAt(1 + stackFrame.index));

            stackFrame.valueAt(0).index = node.nextExpression;
            stackFrame.index += 1;

            return null;
        }

        assert(0, "Type mismatch.");
    }

    return &stackFrame.valueAt(1);
}

void returnCurrentStack(HsValue value)
{
    HsSyntaxNode* node = &hsRuntime.syntaxNodes[stackFrame.expression];

    HsType type;

    if(node.flags.isScenarioScript)
    {
        type = cast(HsType)Cache.inst.scenario.scripts[node.functionIndex].returnType;
    }
    else
    {
        type = hsFunctionMetas[node.functionIndex].returnType;
    }

    *stackFrame.previous.result = convertTo(node.type, type, value);
    stackFrame = stackFrame.previous;
}

}
