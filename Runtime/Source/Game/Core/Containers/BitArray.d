
module Game.Core.Containers.BitArray;

struct BitArray(int numBits)
{

static      if(numBits <= 8)  private ubyte  bits;
else static if(numBits <= 16) private ushort bits;
else static if(numBits <= 32) private uint   bits;
else                          private uint[(numBits + 31) / 32] bits;


bool opIndex(size_t index) const
{
    static if(numBits <= 32) return (bits >> index) & 1;
    else                     return (bits[index / 32] >> (index & 0x1F)) & 1;
}

void opIndexAssign(bool value, size_t index)
in
{
    assert(index < numBits);
}
body
{
    static if(numBits <= 32)
    {
        if(value) bits |= 1 << index;
        else      bits &= ~(1 << index);
    }
    else
    {
        if(value) bits[index / 32] |=  (1 << (index & 0x1F));
        else      bits[index / 32] &= ~(1 << (index & 0x1F));
    }
}

}