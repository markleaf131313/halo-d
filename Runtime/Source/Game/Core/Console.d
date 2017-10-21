
module Game.Core.Console;

import ImGui;

import Game.Script;
import Game.Core.Containers;
import Game.Core.String;

private __gshared ConsoleImpl consoleImpl;

@nogc nothrow
ref ConsoleImpl Console()
{
    return consoleImpl;
}

private struct ConsoleImpl
{
    struct Line
    {
        char[1024] buffer;
    }

    char[128] inputBuffer;
    CircularArray!(Line, FixedArrayAllocator!128) lines;


    void log(Args...)(string pattern, auto ref Args args)
    {
        if(lines.full)
        {
            lines.popFront();
        }

        lines.addBack();

        Console.Line* line = &lines.back();

        snprintf(line.buffer, pattern, args);

    }

    void doUi(ref HsRuntime hsRuntime)
    {
        import std.string : fromStringz;

        if(igBegin("Console")) with (ImGuiInputTextFlags)
        {
            enum inputTextFlags = EnterReturnsTrue | CallbackCompletion | CallbackHistory;

            igBeginChild("TextRegion", Vec2(0, -igGetItemsLineHeightWithSpacing));
            foreach(ref line ; lines)
            {
                igTextUnformatted(line.buffer.ptr);
            }
            igEndChild();

            igPushItemWidth(-1.0f);
            if(igInputText("##ConsoleInput", inputBuffer.ptr, inputBuffer.length, inputTextFlags,
                (ImGuiTextEditCallbackData* data) => (cast(ConsoleImpl*)data.UserData).inputCallback(data), &this))
            {
                igSetKeyboardFocusHere();

                hsRuntime.runConsoleCommand(fromStringz(inputBuffer.ptr));

                inputBuffer[0] = '\0';
            }
            igPopItemWidth();

        }
        igEnd();
    }

    private int inputCallback(ImGuiTextEditCallbackData* data)
    {
        import std.algorithm : startsWith;
        import core.stdc.stdio : printf;
        import Game.Script.Functions.Meta : hsFunctionMetas, HsFunctionMeta;

        switch(data.EventFlag)
        {
        case ImGuiInputTextFlags.CallbackCompletion:

            char[] text = data.Buf[0 .. data.BufTextLen];

            FixedArray!(immutable(HsFunctionMeta)*, 32) metas;


            foreach(ref meta ; hsFunctionMetas)
            {
                if(meta.name && startsWith(meta.name, text))
                {
                    metas.addFalloff(&meta);
                }
            }

            if(metas.length == 1)
            {
                snprintf(data.Buf[0 .. data.BufSize], "%s", metas[0].name);
                data.BufTextLen = cast(int)metas[0].name.length;
                data.CursorPos = data.BufTextLen;
                data.BufDirty = true;
            }
            else
            {
                foreach(ref meta ; metas)
                {
                    Console.log(meta.name);
                }
            }

            break;
        default:
        }

        return 0;
    }
}
