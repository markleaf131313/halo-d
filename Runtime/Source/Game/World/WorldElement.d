
module Game.World.WorldElement;

import Game.World.Private.Misc;
import Game.World.World;
import Game.World.WorldBound;

import Game.Core;
import Game.Tags;


struct WorldElement
{
@nogc:

    struct Sphere
    {
        World.SurfaceResult surface;
        Vec3  center;
        float radius;
    }

    struct Cylinder
    {
        World.SurfaceResult surface;
        Vec3  position;
        Vec3  segment;
        float radius;
    }

    struct Extruded
    {
        World.SurfaceResult surface;
        Projector           proj;

        Plane3 plane;
        float  depth;

        int edgeCount;
        Vec2[TagConstants.Bsp.maxSurfaceEdges] vertices;

        bool pointInSurface(ref Vec3 point)
        {
            return pointInSurface(proj.project(point));
        }

        bool pointInSurface(Vec2 point)
        {
            for(int i = 0; i < (edgeCount - 1); ++i)
            {
                if(perpDot(vertices[i] - point, vertices[i + 1] - point) < 0.0f)
                {
                    return false;
                }
            }

            return perpDot(vertices[edgeCount - 1] - point, vertices[0] - point) >= 0.0f;
        }
    }

    Array!(Sphere,   FixedArrayAllocator!256) spheres;
    Array!(Cylinder, FixedArrayAllocator!256) cylinders;
    Array!(Extruded, FixedArrayAllocator!256) extrusions;

    void addTransformElements(Tag.Bsp* bsp, ref WorldBound.Result bound, ref const(VerticalCapsule) capsule, Transform* transform = null)
    {
        foreach(int i ; bound.vertices)
        {
            Sphere sphere = void;

            auto vertex  = &bsp.vertices[i];
            auto edge    = &bsp.edges[vertex.firstEdge];
            auto surface = &bsp.surfaces[edge.leftSurface];

            Vec3 pt = transform ? *transform * vertex.point : vertex.point;

            sphere.surface = World.SurfaceResult(edge.leftSurface, surface);
            sphere.radius  = capsule.radius;
            sphere.center  = pt;

            spheres.addFalloff(sphere);

            if(capsule.height > 0.0f)
            {
                sphere.center.z -= capsule.height;
                spheres.addFalloff(sphere);

                if(!cylinders.capcityReached())
                {
                    Cylinder cylinder = void;

                    cylinder.surface  = sphere.surface;
                    cylinder.position = pt;
                    cylinder.segment  = Vec3(0, 0, -capsule.height);
                    cylinder.radius   = capsule.radius;

                    cylinders.add(cylinder);
                }
            }
        }

        foreach(i ; bound.edges)
        {
            const edge = &bsp.edges[i];

            auto leftSurface  = &bsp.surfaces[edge.leftSurface];
            auto rightSurface = &bsp.surfaces[edge.rightSurface];

            if(leftSurface.plane == rightSurface.plane)
            {
                continue;
            }

            const start = &bsp.vertices[edge.startVertex];
            const end   = &bsp.vertices[edge.endVertex];

            Vec3 point   = start.point;
            Vec3 segment = end.point - start.point;

            bool leftInvert  = leftSurface.plane  < 0;
            bool rightInvert = rightSurface.plane < 0;

            int leftPlaneIndex  = leftSurface.plane  & int.max;
            int rightPlaneIndex = rightSurface.plane & int.max;

            Plane3* leftPlane  = &bsp.planes[leftPlaneIndex].plane;
            Plane3* rightPlane = &bsp.planes[rightPlaneIndex].plane;

            if(leftPlaneIndex != rightPlaneIndex)
            {
                float d = dot(segment, cross(leftPlane.normal, rightPlane.normal));

                if(leftInvert != rightInvert)
                {
                    if(d > 0.0001f)
                    {
                        continue;
                    }
                }
                else
                {
                    if(d < -0.0001f)
                    {
                        continue;
                    }
                }
            }

            auto surface = leftSurface;

            Vec3 v0 = transform ? *transform * start.point : start.point;
            Vec3 v1 = transform ? *transform * end.point   : end.point;

            Cylinder cylinder = void;

            cylinder.surface  = World.SurfaceResult(edge.leftSurface, surface);
            cylinder.radius   = capsule.radius;
            cylinder.position = v0;
            cylinder.segment  = v1 - v0;

            cylinders.addFalloff(cylinder);

            if(capsule.height > 0.0f)
            {
                if(!cylinders.capcityReached())
                {
                    cylinder.position.z -= capsule.height;
                    cylinders.add(cylinder);
                }

                // todo surface connection between edges
            }
        }


        foreach(i ; bound.surfaces)
        {
            auto surface = &bsp.surfaces[i];
            Plane3 plane = bsp.planes[surface.plane & int.max].plane;

            if(transform)
            {
                plane.normal = transform.mat3 * plane.normal;
                plane.d += dot(plane.normal, transform.position);
            }

            Extruded extruded = void;
            Projector proj = Projector(plane.normal, false);

            extruded.proj = proj;
            extruded.surface = World.SurfaceResult(i, surface);
            extruded.plane = plane;
            extruded.depth = capsule.radius;
            extruded.edgeCount = 0;

            forEachEdgeInBspSurface!(delegate(int e, int v0, int v1) @nogc pure
            {
                Vec3 pt = bsp.vertices[v0].point;

                extruded.vertices[extruded.edgeCount] = proj.project(transform ? *transform * pt : pt);
                extruded.edgeCount += 1;

                return true;
            })(bsp, i);

            if(capsule.height > 0.0f && plane.normal.z < 0.0f)
            {
                extruded.plane.d -= capsule.height * extruded.plane.normal.z;

                if(proj.yIndex == 2)
                {
                    for(int j = 0; j < extruded.edgeCount; ++j)
                    {
                        extruded.vertices[j].y -= capsule.height;
                    }
                }
            }

            if(!extrusions.capcityReached())
            {
                extrusions.add(extruded);
            }
        }
    }


}