
module Game.Script.Thread;

import Game.Script.Runtime;
import Game.Script.Value;

import Game.Core;

struct HsThread
{

enum Type
{
    script,
    global,
    runtime,
}

struct StackFrame
{
@nogc:

    StackFrame* previous;
    DatumIndex  expression;
    HsValue*    result;
    short       length;

    void* data()
    {
        return cast(void*)&this + length.offsetof + length.sizeof;
    }
}

enum dormantTime = indexNone - 1;

DatumIndex selfIndex;

HsRuntime* hsRuntime;

Type type;
int scriptIndex;
int sleepUntil;
int previousSleepUntil;
HsValue result;
StackFrame* stackFrame;

void[1024] stack;

void run()
{
    assert(0); // TODO
}

}
