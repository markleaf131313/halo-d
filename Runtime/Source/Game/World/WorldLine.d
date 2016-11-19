
module Game.World.WorldLine;

import Game.World.Private.Misc;
import Game.World.World;

import Game.Core;
import Game.Tags;

struct WorldLine
{
@nogc:

    alias checkHit this;

    float percent;
    int   leafIndex;
    World.SurfaceResult surface;
    Array!(int, FixedArrayAllocator!256) leaves;

    this(World.SurfaceOptions options, bool storeLeaves, Vec3 position, Vec3 segment, Tag.Bsp* bsp, float p)
    {
        this.options     = options;
        this.storeLeaves = storeLeaves;
        this.position    = position;
        this.segment     = segment;
        this.bsp         = bsp;

        lineLastPlane = indexNone;
        lineLastLeaf  = indexNone;
        lineLastLeafState = LeafState.end;
        percent = clamp(p, 0.0f, 1.0f);

        hit = doNode3d(0, 0.0f, percent);
    }

    @property bool checkHit() const
    {
        return hit;
    }

private:

    enum LeafState
    {
        none,
        oneSided,
        twoSided,
        end,
    }

    bool storeLeaves;
    World.SurfaceOptions options;

    bool hit;

    LeafState lineLastLeafState;

    int lineLastPlane;
    int lineLastLeaf;

    Vec3 position;
    Vec3 segment;

    Tag.Bsp* bsp;

    bool doNode3d(int id, float start, float end)
    {
        assert(start <= end);

        while(id >= 0)
        {
            auto    node  = &bsp.bsp3dNodes[id];
            Plane3* plane = &bsp.planes[node.plane].plane;

            float d = plane.distanceToPoint(position);
            float v = dot(segment, plane.normal);

            float startDistance = d + v * start;
            float endDistance   = d + v * end;

            bool front = startDistance >= 0.0f || endDistance >= 0.0f;
            bool back  = startDistance <= 0.0f || endDistance <= 0.0f;

            if(!front || !back)
            {
                id = front ? node.frontChild : node.backChild;
            }
            else
            {
                bool facing = v < 0.0f;
                float distancePercent = -d / v;

                if(doNode3d(facing ? node.frontChild : node.backChild, start, distancePercent))
                {
                    return true;
                }

                if(distancePercent > percent)
                {
                    return false;
                }

                lineLastPlane = node.plane;

                return doNode3d(facing ? node.backChild : node.frontChild, distancePercent, end);
            }
        }

        LeafState ls            = LeafState.end;
        int       leafId        = indexNone;
        bool      doSurfaceTest = false;

        if(id != indexNone)
        {
            leafId = id & int.max;
            ls = bsp.leaves[leafId].flags.containsDoubleSidedSurfaces ? LeafState.twoSided : LeafState.oneSided;
        }

        int testId = indexNone;

        if(options.frontFacing
            && ls == LeafState.end
            && (lineLastLeafState == LeafState.oneSided || lineLastLeafState == LeafState.twoSided))
        {
            testId = lineLastLeaf;
        }
        else if(options.backFacing
            && lineLastLeafState == LeafState.end
            && (ls == LeafState.oneSided || ls == LeafState.twoSided))
        {
            testId = leafId;
        }
        else if(!options.ignoreTwoSided && lineLastLeafState == LeafState.twoSided && ls == LeafState.twoSided)
        {
            if(options.frontFacing) testId = lineLastLeaf;
            else                    testId = leafId;

            doSurfaceTest = true;
        }

        if(testId != indexNone)
        {
            int surfaceIndex = doLeaf(testId, start, doSurfaceTest);

            if(surfaceIndex != indexNone)
            {
                auto s = &bsp.surfaces[surfaceIndex];

                if(!(options.ignoreInvisible && s.flags.invisible) && !(options.ignoreBreakable && s.flags.breakable))
                {
                    this.percent   = start;
                    this.leafIndex = testId & int.max;
                    this.surface   = World.SurfaceResult(surfaceIndex, s);

                    return true;
                }
            }
        }

        // todo add clusters

        if(leafId != indexNone)
        {
            leaves.addUniqueFalloff(leafId);
        }

        lineLastLeaf = leafId;
        lineLastLeafState = ls;

        return false;
    }

    int doLeaf(int id, float start, bool testSurfaces)
    {
        auto leaf = &bsp.leaves[id];

        int first = leaf.firstBsp2dReference;
        int count = leaf.bsp2dReferenceCount;

        Vec3 intersect = position + segment * start;

        for(int i = first; i < (first + count); ++i)
        {
            auto reference = &bsp.bsp2dReferences[i];

            if((reference.plane & int.max) != lineLastPlane)
            {
                continue;
            }

            Plane3* plane = &bsp.planes[lineLastPlane].plane;
            Projector proj = Projector(plane.normal, reference.plane < 0);

            Vec2 pt = proj.project(intersect);

            int surface = doNode2d(reference.bsp2dNode, pt);

            if(!testSurfaces || pointInSurface(bsp, pt, surface, proj))
            {
                return surface;
            }
        }

        return indexNone;
    }

    int doNode2d(int id, Vec2 point)
    {
        while(id >= 0)
        {
            auto node = &bsp.bsp2dNodes[id];
            id = (node.plane.distanceToPoint(point) >= 0.0f) ? node.rightChild : node.leftChild;
        }

        if(id == indexNone)
        {
            return indexNone;
        }

        return id & int.max;
    }
}