
module Game.Tags.Funcs.Model;

mixin template TagGbxmodel()
{
    import Game.Core : Orientation, conjugate;

    void copyDefaultOrientation(Orientation* output) const
    {
        foreach(i, ref node ; nodes)
        {
            output[i].scale    = 1.0f;
            output[i].rotation = conjugate(node.defaultRotation);
            output[i].position = node.defaultTranslation;
        }
    }
}

mixin template GbxmodelRegionBlock()
{
    import Game.Tags : TagConstants;
    import Game.Core : indexNone;

    int findRandomizablePermutations(int desiredPermutation, ref int[TagConstants.Model.maxFindablePermutations] output)
    {
        int count = 0;

        foreach(i, ref permutation ; permutations)
        {
            if(!permutation.flags.cannotBeChosenRandomly)
            {
                int identifier = permutation.identifier;

                if(identifier == desiredPermutation
                    || (desiredPermutation == indexNone && identifier < TagConstants.Model.maxPermutations))
                {
                    if(count < output.length)
                    {
                        output[count] = i;
                        count += 1;
                    }
                }
            }
        }

        return count;
    }
}