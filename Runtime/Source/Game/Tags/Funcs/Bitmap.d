
module Game.Tags.Funcs.Bitmap;


mixin template TagBitmap()
{
    @nogc inout(BitmapDataBlock)* bitmapAt(int i) inout
    {
        if(i >= 0 && i < bitmaps.size)
        {
            return bitmaps.ptr + i;
        }

        return null;
    }
}

mixin template BitmapDataBlock()
{

    import Game.Core.Math;
    import Game.Tags;
    import Game.Render.Dxt;

    @nogc ColorArgb8 pixelColorAt(const ubyte[] inputBuffer, Vec2 coord, float mipmapScale = 1.0f) const
    {
        ColorArgb8 result;

        uint width  = this.width;
        uint height = this.height;

        uint u = cast(uint)(width  * coord.x) % width;
        uint v = cast(uint)(height * coord.y) % height;

        uint ublock = u / 4;
        uint vblock = v / 4;

        uint compressedWidth = width / 4;

        switch(format)
        {
        case TagEnums.BitmapPixelFormat.dxt1:
        {
            const Dxt1Block[] blocks = cast(const Dxt1Block[])inputBuffer;

            ColorArgb8[4][4] decoded = void;
            blocks[vblock * compressedWidth + ublock].decode(decoded);

            result = decoded[v & 3][u & 3];

            break;
        }
        case TagEnums.BitmapPixelFormat.dxt3:
        {
            const Dxt3Block[] blocks = cast(const Dxt3Block[])inputBuffer;

            ColorArgb8[4][4] decoded = void;
            blocks[vblock * compressedWidth + ublock].decode(decoded);

            result = decoded[v & 3][u & 3];

            break;
        }
        case TagEnums.BitmapPixelFormat.dxt5:
        {
            const Dxt5Block[] blocks = cast(const Dxt5Block[])inputBuffer;

            ColorArgb8[4][4] decoded = void;
            blocks[vblock * compressedWidth + ublock].decode(decoded);

            result = decoded[v & 3][u & 3];
            break;
        }
        case TagEnums.BitmapPixelFormat.r5g6b5:
            const ColorRgb565[] buffer = cast(const ColorRgb565[])inputBuffer;
            result = ColorArgb8(buffer[v * width + u]);
            break;
        case TagEnums.BitmapPixelFormat.a1r5g5b5:
            const ColorArgb1555[] buffer = cast(const ColorArgb1555[])inputBuffer;
            result = ColorArgb8(buffer[v * width + u]);
            break;
        case TagEnums.BitmapPixelFormat.a4r4g4b4:
            const ColorArgb4[] buffer = cast(const ColorArgb4[])inputBuffer;
            result = ColorArgb8(buffer[v * width + u]);
            break;
        case TagEnums.BitmapPixelFormat.a8r8g8b8:
            const ColorArgb8[] buffer = cast(const ColorArgb8[])inputBuffer;
            result = buffer[v * width + u];
            break;
        case TagEnums.BitmapPixelFormat.x8r8g8b8:
            const ColorRgb8[] buffer = cast(const ColorRgb8[])inputBuffer;
            result = ColorArgb8(buffer[v * width + u]);
            break;
        default: assert(0);
        }

        return result;
    }
}
