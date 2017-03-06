
module Game.Debug;

import Game.Core;

@nogc nothrow
ref DebugData Debug()
{
    __gshared DebugData data;
    return data;
}

struct DebugData
{
@nogc nothrow:

    struct Line
    {
        Vec3 start;
        uint color0 = ~0;

        Vec3 end;
        uint color1 = ~0;
    }

    Array!(Line, FixedArrayAllocator!4096) lines;

    void addLine(Vec3 start, Vec3 end)
    {
        lines.addFalloff(Line(start, ~0, end));
    }

}
