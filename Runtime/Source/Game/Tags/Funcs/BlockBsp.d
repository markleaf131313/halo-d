
module Game.Tags.Funcs.BlockBsp;

mixin template Bsp()
{
@nogc nothrow:

    int findLeaf(const Vec3 position) const
    {
        import Game.Core : indexNone;

        int id = 0;

        while(id >= 0)
        {
            auto node  = &this.bsp3dNodes[id];
            auto plane = &this.planes[node.plane].plane;

            float d = plane.distanceToPoint(position);

            if(d >= 0.0f) id = node.frontChild;
            else          id = node.backChild;
        }

        return id == indexNone ? indexNone : (id & int.max);
    }

}