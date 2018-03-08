
module Game.Profiler;

import std.conv : to;
import std.datetime : dur, Duration, MonoTime;
import std.datetime.stopwatch : StopWatch;

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

mixin template ScopedFrame(int line = __LINE__)
{
    mixin("auto _beginScopedFrame_" ~ line.to!string ~ " = Profiler.beginScopedFrame();");
}

mixin template ScopedMarker(int line = __LINE__)
{
    mixin("auto _beginScopedMarker_" ~ line.to!string ~ " = Profiler.beginScopedMarker();");
}

struct Marker
{
    Marker*  parent;
    Marker*  sibling;
    string   name;
    Duration startTime;
    Duration endTime;
    int      level;
}

struct Frame
{
    Duration startTime;
    Duration endTime;

    FixedArray!(Marker, 1024) markers;
    Marker* currentMarker;
    Marker* lastMarker;

    float totalTimeMs()
    {
        return float((endTime - startTime).total!"hnsecs") / dur!"msecs"(1).total!"hnsecs";
    }
}

bool recording = true;
bool stopRecordingWhenFull = true;

int selectionStart = indexNone;
int selectionEnd   = indexNone;

StopWatch timer;

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

    if(!timer.running)
        timer.start();

    currentFrame.markers.clear();
    currentFrame.currentMarker = null;
    currentFrame.lastMarker = null;
    currentFrame.startTime = timer.peek();

    return Result();
}

void endScopedFrame()
{
    if(!recording)
    {
        return;
    }

    currentFrame.endTime = timer.peek();

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

auto beginScopedMarker(string name = __FUNCTION__)
{
    static struct Result
    {
        @disable this(this);

        ~this()
        {
            Profiler.endScopedMarker();
        }
    }

    if(recording)
    {
        Frame* frame = &Profiler.currentFrame;

        if(frame.markers.full)
            assert(0);

        frame.markers.add();

        Marker* marker = &frame.markers[$ - 1];
        marker.parent = frame.currentMarker;
        marker.level = frame.currentMarker ? frame.currentMarker.level + 1 : 0;
        marker.name = name;
        marker.startTime = timer.peek();

        if(frame.lastMarker)
            frame.lastMarker.sibling = marker;

        frame.currentMarker = marker;
    }

    return Result();
}

void endScopedMarker()
{
    if(!recording)
        return;

    Frame* frame = &Profiler.currentFrame;

    frame.currentMarker.endTime = timer.peek();

    frame.lastMarker    = frame.currentMarker;
    frame.currentMarker = frame.currentMarker.parent;
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

    igBeginChild("##timeline");

    if(selectionStart != indexNone)
    {
        Frame* frame = &frames[selectionStart];

        for(Marker* marker = frame.markers.ptr; marker; marker = marker.sibling)
        {
            igButton(marker.name.ptr);
        }
    }

    igEndChild();
}

void doUi()
{
    scope(exit)
        igEnd();

    if(!igBegin("Profiler"))
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
