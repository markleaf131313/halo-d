
module Game.Tags.Funcs.Projectile;

mixin template TagProjectile()
{
@nogc nothrow:

    float getDamageRangePerVelocity(float range) const
    {
        import Game.Core.Math : sqr;

        if(initialVelocity != finalVelocity && range != 0.0f)
        {
            return (sqr(initialVelocity) - sqr(finalVelocity)) / (range + range);
        }

        return 0.0f;
    }

}
