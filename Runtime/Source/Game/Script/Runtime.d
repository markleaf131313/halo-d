
module Game.Script.Runtime;

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
@nogc nothrow:

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

DatumIndex createThread(HsThread.Type type, int scriptIndex = indexNone)
{
    if(DatumIndex index = threads.add())
    {
        HsThread* thread = &threads[index];

        thread.type = type;
        thread.scriptIndex = scriptIndex;

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

short findFunction(const(char)[] name)
{
    assert(0); // TODO implement
}

void compileSource(char[] source)
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
            return;
        }

        HsSyntaxNode* headSyntaxNode = &syntaxNodes[headNodeIndex];
        HsSyntaxNode* nameSyntaxNode = &syntaxNodes[nameNodeIndex];

        headSyntaxNode.value.as!DatumIndex = nameNodeIndex;
        headSyntaxNode.offset = syntaxNodes[index].offset;

        nameSyntaxNode.flags.isPrimitive = true;
        nameSyntaxNode.nextExpression = index;
        nameSyntaxNode.type = HsType.functionName;
    }

    assert(0);
}

private DatumIndex createSyntaxNode(ref char[] source)
{
    if(DatumIndex index = syntaxNodes.add())
    {
        HsSyntaxNode* syntaxNode = &syntaxNodes[index];

        if(source[0] == '(')
        {
            DatumIndex* nextExpression = &syntaxNode.nextExpression;
            syntaxNode.offset = cast(uint)(source.ptr - originalSource.ptr);

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
        auto name = fromStringz(originalSource.ptr + node.offset);

        if(node.type == HsType.specialForm)
        {
            if     (iequals("global", name)) return compileGlobal(index);
            else if(iequals("script", name)) return compileScriptFunction(index);
            else                             setCompileError(node.offset, `Expected "script" or "global"`);
        }
        else
        {
            if(compileFunctionOrScript(index) == indexNone)
            {
                setCompileError(node.offset, "Not a valid function or script name.");
                return false;
            }

            if(node.flags.isScenarioScript)
            {
                auto tagScript = &Cache.inst.scenario.scripts[node.functionIndex];

                if(tagScript.scriptType != TagEnums.ScriptType.staticScript || tagScript.scriptType != TagEnums.ScriptType.stub)
                {
                    setCompileError(node.offset, "Not a static script.");
                    return false;
                }

                if(node.type == HsType.unparsed)
                {
                    node.type = cast(HsType)tagScript.returnType;
                }
                else if(!isConvertableTo(cast(HsType)tagScript.returnType, node.type))
                {
                    setCompileError(node.offset, "Expected a %s, but this script returns %s.",
                        enumName(node.type), enumName(cast(HsType)tagScript.returnType));
                    return false;
                }

                return true;
            }
            else
            {
                assert(0); // TODO
            }

            assert(0); // TODO
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

    headNode.functionIndex = findFunction(name);

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

bool compileSymbol(DatumIndex index)
{
    assert(0); // TODO implement with script compiler, not used in console command line
}

bool compileGlobal(DatumIndex index)
{
    assert(0); // TODO implement with script compiler, not used in console command line
}

bool compileScriptFunction(DatumIndex index)
{
    assert(0);
}

private bool hasCompileError()
{
    return errorMessage !is null;
}

private void setCompileError(Args...)(string message, Args args)
{
    setCompileError(indexNone, message, args);
}

private void setCompileError(Args...)(size_t offset, string message, Args args)
{
    import core.stdc.stdio : snprintf;

    static ref auto adjust(T)(ref T value)
    {
        static if(is(T == string))
        {
            return cast(const(char)*)value.ptr;
        }
        else
        {
            return value;
        }
    }

    template Map(string call, int count)
    {
        import std.conv : to;

        static if(count > 1)
        {
            enum Map = Map!(call, count - 1) ~ ", " ~ call ~ "(args[" ~ to!string(count - 1) ~ "])";
        }
        else static if(count == 1)
        {
            enum Map = ", " ~ call ~ "(args[0])";
        }
        else
        {
            enum Map = "";
        }
    }

    size_t length = mixin("snprintf(errorBuffer.ptr, errorBuffer.length, message.ptr" ~ Map!("adjust", Args.length) ~ ")");

    errorMessage = errorBuffer[0 .. length];
    errorOffset  = cast(uint)offset;
}

private void clearCompilerError()
{
    errorMessage = null;
    errorOffset  = indexNone;
}

void run()
{

}

}
