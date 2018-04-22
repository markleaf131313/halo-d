
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

mixin template ScopedMarker(string name, int line = __LINE__)
{
    mixin("auto _beginScopedMarker_" ~ line.to!string ~ " = Profiler.beginScopedMarker(\"" ~ name ~ "\");");
}

struct Marker
{
    uint parentIndex  = indexNone;
    uint siblingIndex = indexNone;
    string   name;
    Duration startTime;
    Duration endTime;
    int      level;

    float totalTimeMs()
    {
        return float((endTime - startTime).total!"hnsecs") / dur!"msecs"(1).total!"hnsecs";
    }

    float startTimeMs(ref Frame frame)
    {
        return float((startTime - frame.startTime).total!"hnsecs") / dur!"msecs"(1).total!"hnsecs";
    }

    float percentStartOffset(ref Frame frame)
    {
        return startTimeMs(frame) / frame.totalTimeMs;
    }

    float percentTotal(ref Frame frame)
    {
        return totalTimeMs / frame.totalTimeMs;
    }
}

struct Frame
{
    Duration startTime;
    Duration endTime;

    FixedArray!(Marker, 1024) markers;

    uint currentMarkerIndex = indexNone;
    uint lastMarkerIndex    = indexNone;

    float totalTimeMs()
    {
        return float((endTime - startTime).total!"hnsecs") / dur!"msecs"(1).total!"hnsecs";
    }
}

bool recording = true;
bool desiredRecordingState = true;
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
    currentFrame.currentMarkerIndex = indexNone;
    currentFrame.lastMarkerIndex    = indexNone;
    currentFrame.startTime          = timer.peek();

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
            desiredRecordingState = false;
            return;
        }

        frames.popFront();
    }

    frames.addBack(currentFrame);
}

@nogc nothrow
auto beginScopedMarker(string name = __FUNCTION__)
{
    static struct Result
    {
    @nogc nothrow:

        @disable this(this);

        ~this()
        {
            Profiler.endScopedMarker();
        }
    }

    recording = desiredRecordingState;

    if(recording)
    {
        Frame* frame = &Profiler.currentFrame;

        if(frame.markers.full)
        {
            frame.currentMarkerIndex = indexNone;
        }
        else
        {
            uint markerIndex = frame.markers.add();

            Marker* marker = &frame.markers[$ - 1];
            marker.parentIndex = frame.currentMarkerIndex;
            marker.level = frame.currentMarkerIndex != indexNone ? frame.markers[frame.currentMarkerIndex].level + 1 : 0;
            marker.name = name;
            marker.startTime = timer.peek();

            if(frame.lastMarkerIndex != indexNone)
                frame.markers[frame.lastMarkerIndex].siblingIndex = markerIndex;

            frame.currentMarkerIndex = markerIndex;
        }
    }

    return Result();
}

@nogc nothrow
void endScopedMarker()
{
    if(!recording)
        return;

    Frame* frame = &Profiler.currentFrame;

    if(frame.currentMarkerIndex != indexNone)
    {
        frame.markers[frame.currentMarkerIndex].endTime = timer.peek();

        frame.lastMarkerIndex    = frame.currentMarkerIndex;
        frame.currentMarkerIndex = frame.markers[frame.currentMarkerIndex].parentIndex;
    }
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

    float width = igCalcItemWidth();
    igBeginChild("##timeline");
    frameMin = igGetCursorScreenPos();

    if(selectionStart != indexNone)
    {
        Frame* frame = &frames[selectionStart];

        foreach(uint i, ref marker ; frame.markers)
        {
            const float height = igGetFontSize() + 6;

            Vec2 start = frameMin;
            Vec2 size = Vec2(width * marker.percentTotal(*frame), height);

            start += Vec2(width * marker.percentStartOffset(*frame), marker.level * (height + 2));

            Vec4 clip = Vec4(start.x, start.y, start.x + size.x, start.y + size.y);

            igGetWindowDrawList.AddRectFilled(start, start + size, 0xFF444444);
            igGetWindowDrawList.AddRect(start, start + size, 0xFF222222);

            igGetWindowDrawList.AddText(igGetFont, igGetFontSize, start + Vec2(3, 3),
                igGetColorU32(ImGuiCol.Text), marker.name.ptr, null, 0.0f, &clip);

            igPushID(i);
            igSetCursorScreenPos(start);
            igInvisibleButton("##marker", size);
            if(igIsItemHovered())
            {
                igSetTooltip("%s\nTotal Time (ms): %f", marker.name.ptr, marker.totalTimeMs);
            }
            igPopID();
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

    if(igButton(Profiler.recording ? "Stop##recording" : "Resume##recording"))
        Profiler.desiredRecordingState = !Profiler.recording;

    igSameLine();

    igCheckbox("Stop When Full", &stopRecordingWhenFull);

    igPushItemWidth(-1.0f);
    plotGraph();
    // igPlotHistogram("##frames_graph", &getValue,
    //     null, Profiler.frames.empty ? 0 : cast(uint)Profiler.frames.length - 1,
    //     0, null, float.max, float.max, ImVec2(0, 400.0f));
    igPopItemWidth();
}

}
