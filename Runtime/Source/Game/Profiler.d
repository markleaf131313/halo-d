
module Game.Profiler;

import std.conv : to;
import std.datetime : dur, Duration, MonoTime;

import ImGui;

import Game.Core;

@nogc nothrow
ref ProfilerObject Profiler()
{
    __gshared ProfilerObject obj;
    return obj;
}

struct ProfilerObject
{

mixin template BeginScopedFrame(int line = __LINE__)
{
    mixin("auto _beginScopedFrame_" ~ line.to!string ~ " = Profiler.beginScopedFrame();");
}

struct Marker
{
    Marker*  parent;
    string   name;
    Duration startTime;
    Duration endTime;
    int      level;
}

struct Frame
{
    MonoTime startTime;
    MonoTime endTime;

    FixedArray!(Marker, 1024) markers;

    float totalTimeMs()
    {
        return float((endTime - startTime).total!"hnsecs") / dur!"msecs"(1).total!"hnsecs";
    }
}

bool recording = true;
bool stopRecordingWhenFull = true;

int selectionStart = indexNone;
int selectionEnd   = indexNone;

FixedCircularArray!(Frame, 128) frames;
Frame currentFrame;

auto beginScopedFrame()
{
    static struct Result
    {
        @disable this(this);

        ~this()
        {
            Profiler.endScopedFrame();
        }
    }

    currentFrame.markers.clear();
    currentFrame.startTime = MonoTime.currTime;

    return Result();
}

void endScopedFrame()
{
    if(!recording)
    {
        return;
    }

    currentFrame.endTime = MonoTime.currTime;

    if(frames.full)
    {
        if(stopRecordingWhenFull)
        {
            recording = false;
            return;
        }

        frames.popFront();
    }

    frames.addBack(currentFrame);
}

void plotGraph()
{
    ImGuiIO* io = igGetIO();
    ImGuiStyle* style = igGetStyle();

    Vec2 frameSize = Vec2(max(igCalcItemWidth(), frames.length * 10), 100.0f);
    Vec2 childSize = Vec2(igCalcItemWidth(), frameSize.y);

    igBeginChild("graph", childSize + Vec2(0, style.ScrollbarSize + style.ItemSpacing.y), false, ImGuiWindowFlags.HorizontalScrollbar);
    Vec2 frameMin = igGetCursorScreenPos();

    igInvisibleButton("##graphSelection", frameSize);

    if(igIsItemActive())
    {
        if(igIsMouseClicked(0))
        {
            float percent = clamp((io.MouseClickedPos[0].x - frameMin.x) / (frames.length * 10), 0.0f, 0.9999f);
            selectionStart = cast(int)(frames.length * percent);
            selectionEnd = selectionStart + 1;
        }
        else if(igIsMouseDragging(0))
        {
            float percent = clamp((io.MouseClickedPos[0].x - frameMin.x) / (frames.length * 10), 0.0f, 0.9999f);
            selectionStart = cast(int)(frames.length * percent);

            percent = clamp((io.MouseClickedPos[0].x + igGetMouseDragDelta().x - frameMin.x) / (frames.length * 10), 0.0f, 0.9999f);
            selectionEnd = cast(int)(frames.length * percent);

            if(selectionStart > selectionEnd)
            {
                int tmp = selectionStart;
                selectionStart = selectionEnd;
                selectionEnd = tmp;
            }

            selectionEnd += 1;
        }
    }

    igGetWindowDrawList.AddRectFilled(frameMin, frameMin + frameSize,
        igGetColorU32(ImGuiCol.FrameBg), style.FrameRounding);

    foreach(uint i, ref frame ; frames)
    {
        Vec2 size = Vec2(8, frameSize.y * saturate(frame.totalTimeMs / 100.0f));
        Vec2 start = frameMin + Vec2(i * 10, frameSize.y - size.y);

        igGetWindowDrawList.AddRectFilled(start, start + size, ImU32(-1));
    }

    if(selectionStart != indexNone)
    {
        Vec2 start = frameMin;
        Vec2 size  = Vec2(10 * (selectionEnd - selectionStart), 100);

        start.x += selectionStart * 10 - 1;

        igGetWindowDrawList.AddRectFilled(start, start + size, igGetColorU32(ImGuiCol.TextSelectedBg));
    }

    igEndChild();
}

void doUi()
{
    extern(C) static float getValue(void*, int i)
    {
        return Profiler.frames[i].totalTimeMs;
    }

    scope(exit)
        igEnd();

    if(!igBegin("Profiler") || Profiler.frames.length == 0)
        return;

    if(igButton("Stop"))
        Profiler.recording = false;

    igPushItemWidth(-1.0f);
    plotGraph();
    // igPlotHistogram("##frames_graph", &getValue,
    //     null, Profiler.frames.empty ? 0 : cast(uint)Profiler.frames.length - 1,
    //     0, null, float.max, float.max, ImVec2(0, 400.0f));
    igPopItemWidth();
}

}
