
module Game.Audio.Adpcm;

import std.traits : isIntegral;

import Game.Core;

@nogc nothrow:

private struct ReadBuffer
{
@nogc nothrow:

    const(void)* ptr;
    size_t length;

    this(const(void)[] buffer)
    {
        ptr    = buffer.ptr;
        length = buffer.length;
    }

    T read(T)() if(isIntegral!T)
    {
        T result = *cast(T*)ptr;

        if(length >= T.sizeof)
        {
            ptr    += T.sizeof;
            length -= T.sizeof;
        }

        return result;
    }
}

private struct WriteBuffer
{
@nogc nothrow:

    const(void)* ptr;
    size_t length;
    size_t writtenLength;

    this(void[] buffer)
    {
        ptr    = buffer.ptr;
        length = buffer.length;
    }

    void write(T)(T value) if(isIntegral!T)
    {
        if(length >= T.sizeof)
        {
            *cast(T*)ptr = value;

            ptr    += T.sizeof;
            length -= T.sizeof;
        }

        writtenLength += T.sizeof;
    }
}

private enum int[89] stepTable =
[
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
];

private enum int[16] indexTable =
[
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
];

size_t decodedAdpcmSize(size_t compressedSize, int numChannels)
{
    return (compressedSize / (numChannels * 36)) * (numChannels * 130);
}

size_t compressedAdpcmSize(size_t size, int numChannels)
{
    return (size / (numChannels * 130)) * (numChannels * 36);
}

void decodeAdpcm(const(void)[] input, int numChannels, void[] output)
in
{
    assert(input.length % 36 == 0);
}
body
{
    struct Block
    {
        short predictor;
        int index;
        int step;

        short[8] samples;
    }

    numChannels = clamp(numChannels, 0, 2);

    diff_t blockCount = input.length / (numChannels * 36);

    ReadBuffer  inBuffer  = input;
    WriteBuffer outBuffer = output;

    Block[2] blocks;

    for(int b = 0; b < blockCount; ++b)
    {
        foreach(c ; 0 .. numChannels)
        {
            Block* block = &blocks[c];

            block.predictor = inBuffer.read!short();
            block.index     = clamp(inBuffer.read!short(), 0, 88);

            outBuffer.write(cast(short)block.predictor);

            block.step = stepTable[block.index];
        }

        foreach(i ; 0 .. 8)
        {
            foreach(c ; 0 .. numChannels)
            {
                Block* block = &blocks[c];
                uint code = inBuffer.read!uint();

                foreach(ref short sample ; block.samples)
                {
                    block.predictor = decodeAdpcmSample(code & 0xF, block.step, block.predictor);

                    sample = block.predictor;

                    block.index = clamp(block.index + indexTable[code & 0xF], 0, 88);
                    block.step  = stepTable[block.index];

                    code >>>= 4;
                }
            }

            foreach(j ; 0 .. 8)
            {
                foreach(c ; 0 .. numChannels)
                {
                    outBuffer.write!short(blocks[c].samples[j]);
                }
            }
        }
    }

    assert(outBuffer.length == 0);
    assert(output.length == outBuffer.writtenLength);
}

private short decodeAdpcmSample(byte code, int step, int predictor)
{
    int diff = (step >> 3)
        + (-(code >> 2 & 1) & (step >> 0))
        + (-(code >> 1 & 1) & (step >> 1))
        + (-(code >> 0 & 1) & (step >> 2));

    int tmp = -(code >> 3 & 1);

    return cast(short)clamp(predictor + ((tmp ^ diff) - tmp), short.min, short.max);
}
