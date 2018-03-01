
module Game.Profiler;

import std.conv : to;
import std.datetime : dur, Duration, MonoTime;

import Game.Core;

@nogc nothrow
ref ProfilerObject Profiler()
{
    __gshared ProfilerObject obj;
    return obj;
}

struct ProfilerObject
{
@nogc nothrow:

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
    FixedCircularArray!(Frame, 128) frames;

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

        if(recording)
        {
            if(frames.full)
            {
                if(stopRecordingWhenFull)
                {
                    recording = false;
                    return Result();
                }

                frames.popFront();
            }

            frames.addBackEmplace();
            frames.back.startTime = MonoTime.currTime;
        }

        return Result();
    }

    void endScopedFrame()
    {
        if(!recording)
        {
            return;
        }

        frames.back.endTime = MonoTime.currTime;
    }

}
