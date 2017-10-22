
module Game.Script.Functions.Builtin;

import Game.Script.Runtime;
import Game.Script.Value;
import Game.Script.Script;
import Game.Script.Thread;

import Game.Script.Functions.Meta;

import Game.Cache;
import Game.Console;
import Game.Core;
import Game.Tags;


@nogc:

private enum hsBeginRandomMaxExpressions = 32;

@HsFunctionDef(0, "begin", null, HsType.passthrough, &hsBeginCompile)
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

@HsFunctionDef(1, "begin_random", null, HsType.passthrough, &hsBeginCompile)
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

        count = min(count, hsBeginRandomMaxExpressions);

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

            if(meta.index == hsFunctionIndexOf!hsBegin)
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

            if(meta.index == hsFunctionIndexOf!hsBeginRandom && num > hsBeginRandomMaxExpressions)
            {
                hsRuntime.setCompileError(root.offset,
                    "begin_random can take at most %d arguments.", hsBeginRandomMaxExpressions);
                return false;
            }

            break;
        }
    }

    return true;
}

@HsFunctionDef(7,  "+",   null, HsType.hsFloat, &hsArithmeticCompile)
@HsFunctionDef(8,  "-",   null, HsType.hsFloat, &hsArithmeticCompile)
@HsFunctionDef(9,  "*",   null, HsType.hsFloat, &hsArithmeticCompile)
@HsFunctionDef(10, "/",   null, HsType.hsFloat, &hsArithmeticCompile)
@HsFunctionDef(11, "min", null, HsType.hsFloat, &hsArithmeticCompile)
@HsFunctionDef(12, "max", null, HsType.hsFloat, &hsArithmeticCompile)
void hsArithmetic(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex threadIndex, bool initStack)
{
    HsThread* thread = &hsRuntime.threads[threadIndex];

    DatumIndex* expression = &thread.stackFrame.valueAt(0).index;
    float* parameterResult = &thread.stackFrame.valueAt(1).asFloat;
    float* result          = &thread.stackFrame.valueAt(2).asFloat;

    if(initStack)
    {
        HsSyntaxNode* node = &hsRuntime.syntaxNodes[thread.stackFrame.expression];

        thread.stackFrame.length = 16;

        thread.stackFrame.index = 0;
        *expression      = hsRuntime.syntaxNodes[node.value.index].nextExpression;
        *parameterResult = 0.0f;
        *result          = 0.0f;
    }
    else
    {
        if(thread.stackFrame.index == 0)
        {
            *result = *parameterResult;
        }
        else
        {
            switch(meta.index)
            {
            case hsFunctionIndexOf!"+":   *result += *parameterResult; break;
            case hsFunctionIndexOf!"-":   *result -= *parameterResult; break;
            case hsFunctionIndexOf!"*":   *result *= *parameterResult; break;
            case hsFunctionIndexOf!"/":   *result /= *parameterResult; break;
            case hsFunctionIndexOf!"min": *result = min(*result, *parameterResult); break;
            case hsFunctionIndexOf!"max": *result = max(*result, *parameterResult); break;
            default:
            }
        }

        thread.stackFrame.index += 1;
    }

    if(DatumIndex index = *expression)
    {
        *expression = hsRuntime.syntaxNodes[index].nextExpression;
        thread.evaluateSyntaxNode(index, &thread.stackFrame.valueAt(1));
    }
    else
    {
        thread.returnCurrentStack(thread.stackFrame.valueAt(2));
    }

}

bool hsArithmeticCompile(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex nodeIndex)
{
    HsSyntaxNode* root = &hsRuntime.syntaxNodes[nodeIndex];

    int count = 0;

    for(DatumIndex index = hsRuntime.syntaxNodes[root.value.index].nextExpression;
        index;
        index = hsRuntime.syntaxNodes[index].nextExpression)
    {
        count += 1;

        if(!hsRuntime.parseSyntaxNode(index, HsType.hsFloat))
        {
            return false;
        }
    }

    if(count < 2 || meta.index == hsFunctionIndexOf!"/" && count != 2)
    {
        hsRuntime.setCompileError(root.offset, "Function '%s' requires %s2 arguments.",
            meta.name, meta.index == hsFunctionIndexOf!"/" ? "" : "at least ");

        return false;
    }

    return true;
}

@HsFunctionDef(22, "inspect", null, HsType.hsVoid, &hsInspectCompile)
void hsInspect(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex threadIndex, bool initStack)
{
    HsThread* thread = &hsRuntime.threads[threadIndex];

    HsSyntaxNode* node = &hsRuntime.syntaxNodes[thread.stackFrame.expression];
    DatumIndex next = hsRuntime.syntaxNodes[node.value.index].nextExpression;

    if(initStack)
    {
        thread.stackFrame.length = 4;
        thread.evaluateSyntaxNode(next, &thread.stackFrame.valueAt(0));
        return;
    }

    HsSyntaxNode* paramNode = &hsRuntime.syntaxNodes[next];

    HsValue* value = &thread.stackFrame.valueAt(0);

    switch(paramNode.type)
    {
    case HsType.hsShort: Console.log("%d", value.asShort); break;
    case HsType.hsInt:   Console.log("%d", value.asInt);   break;
    case HsType.hsFloat: Console.log("%f", value.asFloat); break;
    default:             Console.log("Unsupported type to inspect (%s)", toString(paramNode.type));
    }

    thread.returnCurrentStack(HsValue());
}

bool hsInspectCompile(ref HsRuntime hsRuntime, ref immutable(HsFunctionMeta) meta, DatumIndex nodeIndex)
{
    // TODO validate number of parameters
    HsSyntaxNode* headNode = &hsRuntime.syntaxNodes[nodeIndex];
    HsSyntaxNode* node = &hsRuntime.syntaxNodes[headNode.value.index];

    if(hsRuntime.parseSyntaxNode(node.nextExpression, HsType.unparsed))
    {
        return true;
    }

    if(!hsRuntime.hasCompileError)
    {
        hsRuntime.setCompileError(headNode.offset, "Not a global variable reference, function call, or script.");
    }

    return false;
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

