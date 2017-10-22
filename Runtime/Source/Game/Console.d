
module Game.Console;

import ImGui;

import Game.Script;
import Game.Core;

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
    CircularArray!(char[128], FixedArrayAllocator!64) history;
    int historyIndex = indexNone;


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
        import core.stdc.string : strncpy;

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

                char[] commandText = fromStringz(inputBuffer.ptr);

                historyIndex = indexNone;

                if(history.full)
                {
                    history.popBack;
                }

                history.addFront();
                strncpy(history.front.ptr, inputBuffer.ptr, history.front.length);

                hsRuntime.runConsoleCommand(commandText);

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
            size_t startIndex = 0;

            foreach_reverse(i, c ; text)
            {
                if(c == '(' || c == ' ' || c == '\t')
                {
                    startIndex = i + 1;
                    text = text[startIndex .. $];
                    break;
                }
            }

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
                snprintf(data.Buf[startIndex .. data.BufSize], "%s", metas[0].name);
                data.BufTextLen = cast(int)(startIndex + metas[0].name.length);

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
        case ImGuiInputTextFlags.CallbackHistory:
            if(!history.empty)
            {
                if     (data.EventKey == ImGuiKey.UpArrow)   historyIndex += 1;
                else if(data.EventKey == ImGuiKey.DownArrow) historyIndex -= 1;

                historyIndex = clamp(historyIndex, 0, cast(int)history.length - 1);

                data.BufTextLen = data.CursorPos = snprintf(data.Buf[0 .. data.BufSize], "%s", history[historyIndex][]);
                data.BufDirty = true;
            }
            break;
        default:
        }

        return 0;
    }
}
