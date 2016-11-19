
module Game.Core.Math.Plane;

import Game.Core.Math.Vector;


pragma(inline, true) @nogc nothrow pure:


struct Plane2
{
pragma(inline, true) @nogc nothrow pure:

    Vec2  normal;
    float d;

    Plane2 opUnary(string op : "-")() const
    {
        return Plane2(-normal, -d);
    }

    float distanceToPoint(Vec2 point)
    {
        return dot(normal, point) - d;
    }
}

struct Plane3
{
pragma(inline, true) @nogc nothrow pure:

    Vec3  normal;
    float d;

    Plane3 opUnary(string op : "-")() const
    {
        return Plane3(-normal, -d);
    }

    float distanceToPoint(Vec3 point)
    {
        return dot(normal, point) - d;
    }
}