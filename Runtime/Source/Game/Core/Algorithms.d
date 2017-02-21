
module Game.Core.Algorithms;

auto findFirst(alias pred, T, U)(T[] range, scope U needle)
{
    foreach(ref v ; range)
    {
        if(pred(v, needle))
        {
            return &v;
        }
    }

    return null;
}
