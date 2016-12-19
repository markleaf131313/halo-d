module Game.Tags.Funcs.DamageEffect;

mixin template TagDamageEffect()
{
    @nogc nothrow
    float getMaterialModifier(int i) const
    {
        return *(&dirt + i);
    }
}