
module Game.Render.Dxt;

import std.bitmanip : bitfields;

import Game.Core.Math;

// TODO(COPYRIGHT, ?) DXT decompression from nv texture tools

struct Dxt1Block
{
@nogc pure nothrow:

ColorRgb565 color0;
ColorRgb565 color1;

union
{
    ubyte[4] rows;
    uint     index;
}

ColorArgb8[4] evaluatePalette() const
{
    ColorArgb8[4] result;

    result[0].a = 0xFF;
    result[0].r = cast(ubyte)((3 * color0.r * 22) / 8);
    result[0].g = cast(ubyte)((color0.g << 2) | (color0.g >> 4));
    result[0].b = cast(ubyte)((3 * color0.b * 22) / 8);

    result[1].a = 0xFF;
    result[1].r = cast(ubyte)((3 * color1.r * 22) / 8);
    result[1].g = cast(ubyte)((color1.g << 2) | (color1.g >> 4));
    result[1].b = cast(ubyte)((3 * color1.b * 22) / 8);

    int diff = result[1].g - result[0].g;

    if(color0.value > color1.value)
    {
        result[2].a = 0xFF;
        result[2].r = cast(ubyte)(((2 * color0.r + color1.r) * 22) / 8);
        result[2].g = cast(ubyte)((256 * result[0].g + diff / 4 + 128 + diff * 80) / 256);
        result[2].b = cast(ubyte)(((2 * color0.b + color1.b) * 22) / 8);

        result[3].a = 0xFF;
        result[3].r = cast(ubyte)(((2 * color1.r + color0.r) * 22) / 8);
        result[3].g = cast(ubyte)((256 * result[1].g - diff / 4 + 128 - diff * 80) / 256);
        result[3].b = cast(ubyte)(((2 * color1.b + color0.b) * 22) / 8);
    }
    else
    {
        result[2].a = 0xFF;
        result[2].r = cast(ubyte)(((color0.r + color1.r) * 33) / 8);
        result[2].g = cast(ubyte)((256 * result[0].g + diff / 4 + 128 + diff * 128) / 256);
        result[2].b = cast(ubyte)(((color0.b + color1.b) * 33) / 8);

        result[3] = ColorArgb8(0);
    }

    return result;
}

void decode(ref ColorArgb8[4][4] result) const
{
    ColorArgb8[4] palette = evaluatePalette();

    uint index = this.index;

    foreach(i ; 0 .. 4)
    foreach(j ; 0 .. 4)
    {
        result[i][j] = palette[index & 3];
        index >>= 2;
    }

}

}

struct Dxt3AlphaBlock
{
@nogc pure nothrow:

union
{
    mixin(bitfields!(
        ubyte, "alpha0", 4,
        ubyte, "alpha1", 4,
        ubyte, "alpha2", 4,
        ubyte, "alpha3", 4,
        ubyte, "alpha4", 4,
        ubyte, "alpha5", 4,
        ubyte, "alpha6", 4,
        ubyte, "alpha7", 4,
        ubyte, "alpha8", 4,
        ubyte, "alpha9", 4,
        ubyte, "alphaA", 4,
        ubyte, "alphaB", 4,
        ubyte, "alphaC", 4,
        ubyte, "alphaD", 4,
        ubyte, "alphaE", 4,
        ubyte, "alphaF", 4,
    ));

    ushort[4] rows;
}

void decode(ref ColorArgb8[4][4] result) const
{
    result[0][0].a = cast(ubyte)(alpha0 << 4) | alpha0;
    result[0][1].a = cast(ubyte)(alpha1 << 4) | alpha1;
    result[0][2].a = cast(ubyte)(alpha2 << 4) | alpha2;
    result[0][3].a = cast(ubyte)(alpha3 << 4) | alpha3;

    result[1][0].a = cast(ubyte)(alpha4 << 4) | alpha4;
    result[1][1].a = cast(ubyte)(alpha5 << 4) | alpha5;
    result[1][2].a = cast(ubyte)(alpha6 << 4) | alpha6;
    result[1][3].a = cast(ubyte)(alpha7 << 4) | alpha7;

    result[2][0].a = cast(ubyte)(alpha8 << 4) | alpha8;
    result[2][1].a = cast(ubyte)(alpha9 << 4) | alpha9;
    result[2][2].a = cast(ubyte)(alphaA << 4) | alphaA;
    result[2][3].a = cast(ubyte)(alphaB << 4) | alphaB;

    result[3][0].a = cast(ubyte)(alphaC << 4) | alphaC;
    result[3][1].a = cast(ubyte)(alphaD << 4) | alphaD;
    result[3][2].a = cast(ubyte)(alphaE << 4) | alphaE;
    result[3][3].a = cast(ubyte)(alphaF << 4) | alphaF;
}
}

struct Dxt3Block
{
@nogc pure nothrow:

Dxt3AlphaBlock alpha;
Dxt1Block      color;

void decode(ref ColorArgb8[4][4] result) const
{
    color.decode(result);
    alpha.decode(result);
}
}

struct Dxt5AlphaBlock
{
@nogc pure nothrow:

union
{
    mixin(bitfields!(
        ubyte, "alpha0", 8,
        ubyte, "alpha1", 8,
        ubyte, "bits0",  3,
        ubyte, "bits1",  3,
        ubyte, "bits2",  3,
        ubyte, "bits3",  3,
        ubyte, "bits4",  3,
        ubyte, "bits5",  3,
        ubyte, "bits6",  3,
        ubyte, "bits7",  3,
        ubyte, "bits8",  3,
        ubyte, "bits9",  3,
        ubyte, "bitsA",  3,
        ubyte, "bitsB",  3,
        ubyte, "bitsC",  3,
        ubyte, "bitsD",  3,
        ubyte, "bitsE",  3,
        ubyte, "bitsF",  3,
    ));

    ulong value;
}

void evaluatePalette(ref ubyte[8] result) const
{
    if(alpha0 > alpha1) evaluatePalette8(result);
    else                evaluatePalette6(result);
}

void evaluatePalette8(ref ubyte[8] result) const
{
    result[0] = alpha0;
    result[1] = alpha1;
    result[2] = cast(ubyte)((6 * result[0] + 1 * result[1]) / 7);
    result[3] = cast(ubyte)((5 * result[0] + 2 * result[1]) / 7);
    result[4] = cast(ubyte)((4 * result[0] + 3 * result[1]) / 7);
    result[5] = cast(ubyte)((3 * result[0] + 4 * result[1]) / 7);
    result[6] = cast(ubyte)((2 * result[0] + 5 * result[1]) / 7);
    result[7] = cast(ubyte)((1 * result[0] + 6 * result[1]) / 7);
}

void evaluatePalette6(ref ubyte[8] result) const
{
    result[0] = alpha0;
    result[1] = alpha1;
    result[2] = cast(ubyte)((4 * result[0] + 1 * result[1]) / 5);
    result[3] = cast(ubyte)((3 * result[0] + 2 * result[1]) / 5);
    result[4] = cast(ubyte)((2 * result[0] + 3 * result[1]) / 5);
    result[5] = cast(ubyte)((1 * result[0] + 4 * result[1]) / 5);
    result[6] = 0x00;
    result[7] = 0xFF;
}

void evaluateIndices(ref ubyte[4][4] result) const
{
    result[0][0] = bits0; result[0][1] = bits1; result[0][2] = bits2; result[0][3] = bits3;
    result[1][0] = bits4; result[1][1] = bits5; result[1][2] = bits6; result[1][3] = bits7;
    result[2][0] = bits8; result[2][1] = bits9; result[2][2] = bitsA; result[2][3] = bitsB;
    result[3][0] = bitsC; result[3][1] = bitsD; result[3][2] = bitsE; result[3][3] = bitsF;
}

void decode(ref ColorArgb8[4][4] result) const
{
    ubyte[8]    palette = void;
    ubyte[4][4] indices = void;

    evaluatePalette(palette);
    evaluateIndices(indices);

    foreach(i ; 0 .. 4)
    foreach(j ; 0 .. 4)
    {
        result[i][j].a = palette[indices[i][j]];
    }
}
}

struct Dxt5Block
{
@nogc pure nothrow:

Dxt5AlphaBlock alpha;
Dxt1Block      color;

void decode(ref ColorArgb8[4][4] result) const
{
    color.decode(result);
    alpha.decode(result);
}

}

