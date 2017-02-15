
module Game.Tags.Funcs.ScenarioStructureBsp;

mixin template TagScenarioStructureBsp()
{
@nogc nothrow:

    auto findLocation(Vec3 position) const
    {
        import Game.Core  : indexNone;
        import Game.World : World;

        World.Location result =
        {
            leaf: collisionBsp.findLeaf(position)
        };

        if(result.leaf != indexNone)
        {
            result.cluster = this.leaves[result.leaf].cluster;
        }

        return result;
    }

    void findLightmapMaterialFromSurface(int surface, ref int lightmapIndex, ref int materialIndex) const
    {
        // NOTE: differs from normal binary search
        //       returns last index used if the value is not found
        static int binarySearch(alias tri, T, V)(T[] range, V value)
        {
            int min = 0;
            int max = cast(int)range.length - 1;

            int result = 0;

            while(min <= max)
            {
                immutable middle = (max - min) / 2 + min;

                int direction = tri(range[middle], value);

                if     (direction < 0) result = max = middle - 1;
                else if(direction > 0) result = min = middle + 1;
                else                   return middle;
            }

            assert(result >= 0 && result <= range.length);

            return result;
        }

        lightmapIndex = binarySearch!((ref a, int surface)
            {
                if(surface < a.materials[0].surfaces) return -1;
                auto lastMaterial = &a.materials[$ - 1];
                if(surface >= lastMaterial.surfaces + lastMaterial.surfaceCount) return 1;
                return 0;
            }
        )(lightmaps[], surface);

        materialIndex = binarySearch!(
            (ref a, int surface)
            {
                if(surface < a.surfaces)                   return -1;
                if(surface >= a.surfaces + a.surfaceCount) return 1;
                return 0;
            }
        )(lightmaps[lightmapIndex].materials[], surface);

    }

    bool getSurfaceVertices(int lightmapIndex, int materialIndex, int surfaceIndex, ref TagBspVertex*[3] result) const
    {
        auto lightmap = &lightmaps[lightmapIndex];
        auto material = &lightmap.materials[materialIndex];
        auto surface  = &surfaces[surfaceIndex];

        if(material.vertexBuffers[0].type == 1)
        {
            assert(0, "Need to support compressed vertices"); // compressed vertices
        }
        else
        {
            if(material.vertexBuffers[0].type && material.vertexBuffers[0].type != 12)
            {
                return false;
            }

            TagBspVertex* vertices = material.uncompressedVertices.dataAs!TagBspVertex;

            result[0] = &vertices[surface.a];
            result[1] = &vertices[surface.b];
            result[2] = &vertices[surface.c];

            return true;
        }
    }

    bool getLightmapVertices(
        int                          lightmapIndex,
        int                          materialIndex,
        int                          surfaceIndex,
        ref TagBspLightmapVertex*[3] result) const
    {
        auto lightmap = &lightmaps[lightmapIndex];
        auto material = &lightmap.materials[materialIndex];
        auto surface  = &surfaces[surfaceIndex];

        if(material.vertexBuffers[0].type == 1)
        {
            assert(0, "Need to support compressed vertices"); // compressed vertices
        }
        else
        {
            if(material.vertexBuffers[0].type && material.vertexBuffers[0].type != 12)
            {
                return false;
            }

            TagBspVertex* vertices = material.uncompressedVertices.dataAs!TagBspVertex;
            TagBspLightmapVertex* lmVertices = cast(TagBspLightmapVertex*)&vertices[material.vertexBuffers[0].count];

            result[0] = &lmVertices[surface.a];
            result[1] = &lmVertices[surface.b];
            result[2] = &lmVertices[surface.c];

            return true;
        }
    }

}
