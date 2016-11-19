
module Game.Core.Math.Shapes;

import Game.Core.Math.Algorithms;
import Game.Core.Math.Vector;

struct Sphere
{
@nogc pure nothrow:

    Vec3  center;
    float radius;

    bool intersects(ref const(Sphere) other) const
    {
        return lengthSqr(center - other.center) <= sqr(radius + other.radius);
    }

    bool intersectsLine(Vec3 position, Vec3 segment) const
    {
        Vec3 offsetCenter = center - position;
        float t = clamp(dot(offsetCenter, segment) / lengthSqr(segment), 0.0f, 1.0f);
        return lengthSqr((position + segment * t) - center) <= sqr(radius);
    }

    bool intersectsLine2(ref const Vec3 i, ref const Vec3 j) const
    {
        Vec3 f = i - center;

        float c = lengthSqr(f) - sqr(radius);

        // using quadratic equation
        // b^2 - 4*a*c
        // if this is negative there is no collision, can't take sqrt() of negative

        if(c <= 0.0f)
        {
            // intersecting first vertex
            // distance from point to point is less or equal to radius of sphere

            return true;
        }
        else
        {
            Vec3 d = j - i;

            float b = dot(d, f);

            if(b <= 0.0f)
            {
                float a = dot(d, d);

                if(b*b - a*c >= 0.0f)
                {
                    return true;
                }
            }
        }

        return false;
    }
}

struct Circle
{
    Vec2  center;
    float radius;
}

struct VerticalCapsule
{
    Vec3  bottomCenter;
    float height;
    float radius;
}