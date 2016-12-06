
module Game.World.WorldBound;

import std.algorithm.searching : canFind;

import Game.World.Private.Misc;
import Game.World.World;

import Game.Core;
import Game.Tags;

struct WorldBound
{
@nogc nothrow:

    struct Result
    {
        @disable this(this);

        Array!(int, FixedArrayAllocator!256) leaves;
        Array!(int, FixedArrayAllocator!256) vertices;
        Array!(int, FixedArrayAllocator!256) edges;
        Array!(int, FixedArrayAllocator!256) surfaces;
    }

    Result result;

    this(Tag.Bsp* bsp, ref const(Sphere) sphere)
    {
        this.bsp = bsp;
        this.sphere = sphere;

        doNode3d(0);
    }

private:

    Sphere sphere;
    Circle circle;
    Projector projector;

    Tag.Bsp* bsp;

    Array!(int, FixedArrayAllocator!(TagConstants.Bsp.maxBsp3dDepth)) planes;

    void doNode3d(int id)
    {
        while(id >= 0)
        {
            auto    node  = &bsp.bsp3dNodes[id];
            Plane3* plane = &bsp.planes[node.plane].plane;

            float distance = plane.distanceToPoint(sphere.center);

            if(distance > sphere.radius)
            {
                id = node.frontChild;
            }
            else if(distance < -sphere.radius)
            {
                id = node.backChild;
            }
            else
            {
                if(!planes.addFalloff(node.plane & int.max))
                {
                    doNode3d(node.frontChild);
                    planes.pop();
                }

                if(!planes.addFalloff(node.plane | int.min))
                {
                    doNode3d(node.backChild);
                    planes.pop();
                }

                return;
            }
        }

        if(id == indexNone)
        {
            return;
        }

        id = id & int.max;

        result.leaves.addUniqueFalloff(id);

        auto leaf = &bsp.leaves[id];

        for(int i = leaf.firstBsp2dReference; i < (leaf.firstBsp2dReference + leaf.bsp2dReferenceCount); ++i)
        {
            auto node = &bsp.bsp2dReferences[i];

            if(!canFind(planes[], node.plane))
            {
                continue;
            }

            Plane3* plane = &bsp.planes[node.plane & int.max].plane;

            float distance = plane.distanceToPoint(sphere.center);
            Vec3 intersection = plane.normal * -distance + sphere.center;

            this.projector = Projector(plane.normal, node.plane < 0);

            this.circle.center = projector.project(intersection);
            this.circle.radius = sqrt(sqr(sphere.radius) - sqr(distance));

            doNode2d(node.bsp2dNode);
        }
    }

    void doNode2d(int id)
    {
        while(id >= 0)
        {
            auto node     = &bsp.bsp2dNodes[id];
            Plane2* plane = &node.plane;

            float distance = plane.distanceToPoint(circle.center);

            if     (distance >  circle.radius) id = node.rightChild;
            else if(distance < -circle.radius) id = node.leftChild;
            else
            {
                doNode2d(node.rightChild);
                id = node.leftChild;
            }
        }

        if(id != indexNone)
        {
            doSurface(id & int.max);
        }
    }

    void doSurface(int id)
    {
        bool edgeHit = false;

        forEachEdgeInBspSurface!(delegate(int e, int v0, int v1) @nogc pure
        {
            Vec3 a = bsp.vertices[v0].point;
            Vec3 b = bsp.vertices[v1].point;

            if(lengthSqr(a - sphere.center) <= sqr(sphere.radius))
            {
                // bit inefficient as SphereLineIntersects() essentially calculate the above as well

                edgeHit = true;
                result.vertices.addUniqueFalloff(v0);
            }

            if(sphere.intersectsLine2(a, b))
            {
                edgeHit = true;
                result.edges.addUniqueFalloff(e);
            }

            return true;

        })(bsp, id);

        if(edgeHit || pointInSurface(bsp, circle.center, id, projector))
        {
            result.surfaces.addUniqueFalloff(id);
        }
    }

}