
module Game.Script.Runtime;

import Game.Script.Functions.Meta;
import Game.Script.Script;
import Game.Script.Thread;
import Game.Script.Value;

import Game.Cache;
import Game.Core;
import Game.Tags;


@nogc nothrow
private void stripLineComment(ref char[] str)
{
    for(char[] result = str; result.length; result = result[1 .. $])
    {
        if(result[0] == '\n' || result[0] == '\r')
        {
            str = result[1 .. $];
            break;
        }
    }

    str = null;
}

@nogc nothrow
private bool stripMultiLineComment(ref char[] str)
{
    for(char[] result = str; result.length >= 2; result = result[1 .. $])
    {
        if(result[0] == '*' && result[1] == ';')
        {
            str = result[2 .. $];
            return false;
        }
    }

    return true;
}

@nogc nothrow
private bool stripCommentAndWhitespace(ref char[] str)
{
    loop:
    for(char[] result = str; result.length; result = result[1 .. $])
    {
        switch(result[0])
        {
        case ' ':
        case '\t':
        case '\n':
        case '\r': continue;
        case ';':
            if(result.length >= 2 && result[1] == '*')
            {
                result = result[2 .. $];

                if(stripMultiLineComment(result))
                {
                    return true;
                }
            }
            else
            {
                stripLineComment(result);
            }
            break;
        default:
            str = result;
            return false;
        }
    }

    str = null;
    return false;
}

struct HsRuntime
{
@nogc:

DatumArray!HsThread threads;
DatumArrayBuffered!HsSyntaxNode syntaxNodes;

char[] originalSource;

const(char)[] errorMessage;
uint          errorOffset;
char[256]     errorBuffer;

void initialize()
{
    threads.allocate(256, multichar!"td");
}

void initializeScenario(const(TagScenario)* tagScenario)
{
    if(tagScenario.scriptSyntaxData.size == HsSyntaxNode.sizeof * 19_001 + 56)
    {
        HsSyntaxNode* buffer = cast(HsSyntaxNode*)(tagScenario.scriptSyntaxData.data + 56);
        syntaxNodes.setBuffer(buffer[0 .. 19_001]);
    }
    else
    {
        assert(0);
    }
}

void runConsoleCommand(char[] command)
{

    if(DatumIndex nodeIndex   = compileSource(command))
    if(DatumIndex threadIndex = createThread(HsThread.Type.runtime))
    {
        HsThread* thread = &threads[threadIndex];

        thread.evaluateSyntaxNode(nodeIndex, &thread.result);
        thread.run();

        threads.remove(threadIndex);
    }

}

DatumIndex createThread(HsThread.Type type, int scriptIndex = indexNone)
{
    if(DatumIndex index = threads.add())
    {
        HsThread* thread = &threads[index];

        thread.hsRuntime = &this;
        thread.type = type;
        thread.scriptIndex = scriptIndex;
        thread.stackFrame = cast(HsThread.StackFrame*)thread.stack.ptr;

        thread.stackFrame.result = &thread.result;

        if(scriptIndex != indexNone)
        {
            const tagScenario = Cache.inst.scenario;

            if(tagScenario.scripts[scriptIndex].scriptType == TagEnums.ScriptType.dormant)
            {
                thread.sleepUntil = HsThread.dormantTime;
            }
        }

        return index;
    }

    return DatumIndex();
}

short findFunctionIndex(const(char)[] name)
{
    foreach(i, ref meta ; hsFunctionMetas)
    {
        if(iequals(name, meta.name))
        {
            return cast(short)i;
        }
    }

    return indexNone;
}

DatumIndex compileSource(char[] source)
{
    clearCompilerError();

    originalSource = source;

    stripCommentAndWhitespace(source);

    if(DatumIndex index = createSyntaxNode(source))
    {
        DatumIndex headNodeIndex = syntaxNodes.add();
        DatumIndex nameNodeIndex = syntaxNodes.add();

        if(!headNodeIndex || !nameNodeIndex)
        {
            return DatumIndex.none;
        }

        HsSyntaxNode* headSyntaxNode = &syntaxNodes[headNodeIndex];
        HsSyntaxNode* nameSyntaxNode = &syntaxNodes[nameNodeIndex];

        headSyntaxNode.value.as!DatumIndex = nameNodeIndex;
        headSyntaxNode.offset = syntaxNodes[index].offset;

        nameSyntaxNode.flags.isPrimitive = true;
        nameSyntaxNode.functionIndex  = hsFunctionIndexOf!"inspect";
        nameSyntaxNode.type           = HsType.functionName;
        nameSyntaxNode.nextExpression = index;

        if(parseSyntaxNode(headNodeIndex, HsType.hsVoid))
        {
            return headNodeIndex;
        }

        if(hasCompileError())
        {
            import core.stdc.stdio : printf;
            printf("%s", errorMessage.ptr); // TODO print to console
        }
    }

    return DatumIndex.none;
}

private DatumIndex createSyntaxNode(ref char[] source)
{
    if(DatumIndex index = syntaxNodes.add())
    {
        HsSyntaxNode* syntaxNode = &syntaxNodes[index];

        if(source[0] == '(')
        {
            DatumIndex* nextExpression = &syntaxNode.value.index;
            syntaxNode.offset = cast(uint)(source.ptr - originalSource.ptr);

            source = source[1 .. $];

            while(!hasCompileError())
            {
                char[] prevSource = source;

                if(stripCommentAndWhitespace(source))
                {
                    setCompileError("Unterminated multiline comment.");
                    break;
                }

                if(prevSource != source)
                {
                    prevSource[0] = '\0';
                }

                if(source.length)
                {
                    if(source[0] == ')')
                    {
                        source[0] = '\0';
                        source = source[1 .. $];
                        break;
                    }

                    if(DatumIndex nextIndex = createSyntaxNode(source))
                    {
                        *nextExpression = nextIndex;
                        nextExpression = &syntaxNodes[nextIndex].nextExpression;
                    }
                }
                else
                {
                    setCompileError("A Left parenthesis is unmatched.");
                }
            }

            if(!hasCompileError() && nextExpression is &syntaxNode.nextExpression)
            {
                setCompileError(syntaxNode.offset, "Expression is empty.");
            }

        }
        else
        {
            syntaxNode.flags.isPrimitive = true;

            if(source.length && source[0] == '"')
            {
                source = source[1 .. $];
                syntaxNode.offset = cast(uint)(source.ptr - originalSource.ptr);

                while(source.length && source[0] != '"')
                {
                    source = source[1 .. $];
                }

                if(source.length == 0)
                {
                    setCompileError(syntaxNode.offset, "Unterminated quote for string constant.");
                }
                else
                {
                    source[0] = '\0';
                    source = source[1 .. $];
                }
            }
            else
            {
                syntaxNode.offset = cast(uint)(source.ptr - originalSource.ptr);

                loop:
                for(; source.length; source = source[1 .. $])
                {
                    switch(source[0])
                    {
                    case ')':
                    case ';':
                    case ' ':
                    case '\t':
                        break loop;
                    default:
                    }
                }
            }
        }

        return index;
    }

    return DatumIndex();
}

bool parseSyntaxNode(DatumIndex index, HsType type)
{
    HsSyntaxNode* syntaxNode = &syntaxNodes[index];

    if(syntaxNode.type == HsType.unparsed)
    {
        syntaxNode.type = type;

        if(syntaxNode.flags.isPrimitive)
        {
            syntaxNode.constantType = type;
            return compileSymbol(index);
        }
        else
        {
            return compileExpression(index);
        }
    }

    return true;
}

bool compileExpression(DatumIndex index)
{
    import std.string : fromStringz;

    HsSyntaxNode* headNode = &syntaxNodes[index];
    HsSyntaxNode* node     = &syntaxNodes[headNode.value.as!DatumIndex];

    if(node.flags.isPrimitive)
    {
        if(node.type == HsType.specialForm)
        {
            const(char)[] name = fromStringz(originalSource.ptr + node.offset);

            if     (iequals("global", name)) return compileGlobal(index);
            else if(iequals("script", name)) return compileScript(index);
            else                             setCompileError(node.offset, `Expected "script" or "global"`);
        }
        else
        {
            if(compileFunctionOrScript(index) == indexNone)
            {
                setCompileError(node.offset, "Not a valid function or script name.");
                return false;
            }

            if(headNode.flags.isScenarioScript)
            {
                auto tagScript = &Cache.inst.scenario.scripts[node.functionIndex];

                if(tagScript.scriptType != TagEnums.ScriptType.staticScript || tagScript.scriptType != TagEnums.ScriptType.stub)
                {
                    setCompileError(headNode.offset, "Not a static script.");
                    return false;
                }

                if(headNode.type == HsType.unparsed)
                {
                    headNode.type = cast(HsType)tagScript.returnType;
                }
                else if(!isConvertableTo(cast(HsType)tagScript.returnType, headNode.type))
                {
                    setCompileError(node.offset, "Expected a %s, but this script returns %s.",
                        enumName(headNode.type), enumName(cast(HsType)tagScript.returnType));
                    return false;
                }

                return true;
            }
            else
            {
                auto meta = &hsFunctionMetaAt(headNode.functionIndex);

                if(headNode.type != HsType.unparsed)
                {
                    if(!isConvertableTo(meta.returnType, headNode.type))
                    {
                        setCompileError(node.offset, "Expected a %s, but this function returns %s.",
                            enumName(node.type), enumName(meta.returnType));
                        return false;
                    }
                }

                // TODO check if blocking allowed
                // TODO check if variable assignment allowed

                if(headNode.type == HsType.unparsed && meta.returnType != HsType.passthrough)
                {
                    headNode.type = meta.returnType;
                }

                return meta.compileFunction(this, *meta, index);
            }
        }
    }
    else
    {
        setCompileError(node.offset, "Expected %s, but got an expression.",
            node.type == HsType.specialForm ? `"script" or "global"` : "a function name");
    }

    return false;
}

short compileFunctionOrScript(DatumIndex index)
{
    import std.string : fromStringz;

    HsSyntaxNode* headNode = &syntaxNodes[index];
    HsSyntaxNode* nameNode = &syntaxNodes[headNode.value.as!DatumIndex];

    if(nameNode.type == HsType.functionName)
    {
        return headNode.functionIndex = nameNode.functionIndex;
    }

    const(char)[] name = fromStringz(originalSource.ptr + nameNode.offset);

    nameNode.type = HsType.functionName;
    headNode.functionIndex = findFunctionIndex(name);

    if(headNode.functionIndex == indexNone)
    {
        // TODO handle if no scenario loaded
        headNode.functionIndex = Cache.inst.scenario.findScript(name);

        if(headNode.functionIndex != indexNone)
        {
            headNode.flags.isScenarioScript = true;
        }
    }

    return nameNode.functionIndex = headNode.functionIndex;
}

bool compileVariable(DatumIndex index)
{
    return false; // TODO find by name
}

bool compileSymbol(DatumIndex index)
{
    HsSyntaxNode* node = &syntaxNodes[index];

    if(node.type == HsType.specialForm)
    {
        setCompileError(node.offset, "Expected a script or variable definition.");
        return false;
    }

    if(node.type == HsType.hsVoid)
    {
        setCompileError(node.offset, "Value in this expression can never be used.");
        return false;
    }

    if(compileVariable(index))
    {
        return true;
    }

    if(node.type == HsType.unparsed || hasCompileError)
    {
        return false;
    }

    switch(node.type)
    {
    case HsType.hsFloat:
        import core.stdc.stdio : sscanf;

        char[] str = fromStringz(originalSource.ptr + node.offset);
        if(sscanf(str.ptr, "%f", &node.value.asFloat) != 1)
        {
            setCompileError(node.offset, "Failed to convert '%s' to float.", str);
            return false;
        }
        break;
    default: assert(0); // TODO
    }

    return true;
}

bool compileGlobal(DatumIndex index)
{
    assert(0); // TODO implement with script compiler, not used in console command line
}

bool compileScript(DatumIndex index)
{
    assert(0); // TODO implement with script compiler, not used in console command line
}

bool hasCompileError()
{
    return errorMessage !is null;
}

void setCompileError(Args...)(string message, auto ref Args args)
{
    setCompileError(indexNone, message, args);
}

void setCompileError(Args...)(size_t offset, string message, auto ref Args args)
{
    size_t length = snprintf(errorBuffer, message, args);

    errorMessage = errorBuffer[0 .. length];
    errorOffset  = cast(uint)offset;
}

private void clearCompilerError()
{
    errorMessage = null;
    errorOffset  = indexNone;
}

}
