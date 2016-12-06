
module Game.World.Private.Misc;


import Game.Core;
import Game.Tags;

struct Projector
{
@nogc pure nothrow:

    private byte index;

    this(Vec3 normal, bool inverted)
    {
        Vec3 n = abs(normal);

        if(n.z < n.x || n.z < n.y)
        {
            if(n.y < n.x) index = 0; // x dominate
            else          index = 1; // y dominate
        }
        else
        {
            index = 2; // z dominate
        }

        if((normal[index] < 0.0f) ^ !!inverted)
        {
            index += 3;
        }
    }

    pragma(inline, true)
    @property int xIndex()
    {
        immutable int[6] indices = [ 1, 2, 0, 2, 0, 1 ];
        return indices[index];
    }

    pragma(inline, true)
    @property int yIndex()
    {
        immutable int[6] indices = [ 2, 0, 1, 1, 2, 0 ];
        return indices[index];
    }

    pragma(inline, true)
    Vec2 project(Vec3 pt)
    {
        return Vec2(pt[xIndex], pt[yIndex]);
    }
}

// todo this needs optimizing
bool forEachEdgeInBspSurface(alias callback, Args...)(Tag.Bsp* bsp, int surface) pure
{
    auto s = &bsp.surfaces[surface];
    int next = s.firstEdge;

    do
    {
        auto e = &bsp.edges[next];

        int v0;
        int v1;
        int cur = next;

        if(e.rightSurface == surface)
        {
            v0 = e.endVertex;
            v1 = e.startVertex;
            next = e.reverseEdge;
        }
        else
        {
            v0 = e.startVertex;
            v1 = e.endVertex;
            next = e.forwardEdge;
        }

        if(!callback(cur, v0, v1))
        {
            return false;
        }

    } while(next != s.firstEdge);

    return true;
}

@nogc nothrow
bool pointInSurface(Tag.Bsp* bsp, Vec2 pt, int surface, Projector proj)
{
    return forEachEdgeInBspSurface!(delegate(int e, int v0, int v1) @nogc nothrow pure
    {
        Vec2 e0 = proj.project(bsp.vertices[v0].point) - pt;
        Vec2 e1 = proj.project(bsp.vertices[v1].point) - pt;

        return perpDot(e0, e1) >= 0.0f;
    })(bsp, surface);
}

@nogc nothrow
bool calculateCoordInTriangle(Vec3 point, Vec3 v0, Vec3 v1, Vec3 v2, ref Vec2 result)
{
    Vec3 originToPoint = point - v0;
    Vec3 originToV1    = v1 - v0;
    Vec3 originToV2    = v2 - v0;

    Vec3 normal = cross(originToV1, originToV2);

    if(lengthSqr(normal) * 0.0001f <= sqr(dot(originToPoint, normal)))
    {
        return false;
    }

    Projector proj = Projector(normal, false);

    Vec2 projPt = proj.project(originToPoint);
    Vec2 projV1 = proj.project(originToV1);
    Vec2 projV2 = proj.project(originToV2);

    float pd0 = perpDot(projV1, projPt);
    float pd1 = perpDot(projPt, projV2);
    float pd2 = perpDot(projV1, projV2);

    if(pd0 < 0.0f || pd1 < 0.0f || pd0 + pd1 > pd2)
    {
        return false;
    }

    result.x = pd1 / pd2;
    result.y = pd0 / pd2;

    return true;
}