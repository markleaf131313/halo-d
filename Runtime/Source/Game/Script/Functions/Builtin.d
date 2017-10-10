
module Game.Script.Functions.Builtin;

import Game.Script.Runtime;
import Game.Script.Value;
import Game.Script.Script;
import Game.Script.Thread;

import Game.Script.Functions.Meta;

import Game.Cache;
import Game.Core;
import Game.Tags;


@nogc:

enum beginRandomMaxExpressions = 32;

@HsFunctionDef(0, "begin", null, &hsBeginCompile)
void hsBegin(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex threadIndex, bool initStack)
{
    HsThread* thread = &hsRuntime.threads[threadIndex];

    if(initStack)
    {
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[thread.stackFrame.expression];

        thread.stackFrame.length = 8;

        thread.stackFrame.valueAt(0).asInt = 0;
        thread.stackFrame.valueAt(1).index = node.value.index;
    }

    if(DatumIndex next = thread.stackFrame.valueAt(1).index)
    {
        thread.evaluateSyntaxNode(next, &thread.stackFrame.valueAt(0));
        thread.stackFrame.valueAt(1).index = hsRuntime.syntaxNodes[next].nextExpression;
    }
    else
    {
        thread.returnCurrentStack(thread.stackFrame.valueAt(0));
    }
}

@HsFunctionDef(1, "begin_random", null, &hsBeginCompile)
void hsBeginRandom(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex threadIndex, bool initStack)
{
    HsThread* thread = &hsRuntime.threads[threadIndex];

    if(initStack)
    {
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[thread.stackFrame.expression];

        int count = 0;

        for(DatumIndex index = node.value.index; index; index = hsRuntime.syntaxNodes[index].nextExpression)
        {
            count += 1;
        }

        count = min(count, beginRandomMaxExpressions);

        thread.stackFrame.valueAt(0).asInt = 0;
        thread.stackFrame.valueAt(1).asInt = count;
        thread.stackFrame.valueAt(2) = node.value;
        thread.stackFrame.valueAt(3).asInt = 0;
    }

    int startIndex = randomValueFromZero(thread.stackFrame.valueAt(1).asInt);
    int count = thread.stackFrame.valueAt(1).asInt;

    for(int i = 0; i < count; ++i)
    {
        int index = (i + startIndex) % count;

        if(thread.stackFrame.valueAt(0).bits & (1 << index))
        {
            continue;
        }

        thread.stackFrame.valueAt(0).bits |= 1 << index;

        DatumIndex nodeIndex = hsRuntime.syntaxNodes[thread.stackFrame.expression].value.index;

        for(int j = 0; j < index; ++j)
        {
            nodeIndex = hsRuntime.syntaxNodes[nodeIndex].nextExpression;
        }

        thread.evaluateSyntaxNode(nodeIndex, &thread.stackFrame.valueAt(3));

        if(i != count - 1)
        {
            return;
        }
    }

    thread.returnCurrentStack(thread.stackFrame.valueAt(3));
}

bool hsBeginCompile(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex nodeIndex)
{
    HsSyntaxNode* root = &hsRuntime.syntaxNodes[nodeIndex];
    HsSyntaxNode* node = &hsRuntime.syntaxNodes[root.value.as!DatumIndex];

    bool valid = true;
    int  num   = 0;

    while(valid)
    {
        if(node.nextExpression)
        {
            DatumIndex index = node.nextExpression;
            node = &hsRuntime.syntaxNodes[node.nextExpression];

            if(meta.index == getHsFunctionIndex!hsBegin)
            {
                valid = hsRuntime.parseSyntaxNode(index, node.nextExpression ? HsType.hsVoid : root.type);

                if(valid && !node.nextExpression && root.type == HsType.unparsed)
                {
                    root.type = node.type;
                }
            }
            else
            {
                valid = hsRuntime.parseSyntaxNode(index, root.type);

                if(valid && root.type == HsType.unparsed)
                {
                    root.type = node.type;
                }
            }

            num += 1;
        }
        else
        {
            if(num <= 0)
            {
                hsRuntime.setCompileError(root.offset, "Statement block must contain at least one expression.");
                return false;
            }

            if(meta.index == getHsFunctionIndex!hsBeginRandom && num > beginRandomMaxExpressions)
            {
                hsRuntime.setCompileError(root.offset,
                    "begin_random can take at most %d arguments.", beginRandomMaxExpressions);
                return false;
            }

            break;
        }
    }

    return true;
}

@HsFunctionDef(38, "object_create")
void hsObjectCreate(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, short nameIndex)
{
    if(nameIndex >= 0 && nameIndex < TagConstants.Scenario.maxNamedObjects)
    {
        TagScenario* tagScenario = Cache.inst.scenario;

        assert(0); // TODO
    }
}

