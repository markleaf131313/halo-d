
module Game.Render.Private.Pixels;


import Game.Tags;

@nogc nothrow:

private immutable pixelBitSize =
[
        0x08, 0x08, 0x08, 0x10, 0x00, 0x00,
        0x10,
        0x00,
        0x10,
        0x10,
        0x20,
        0x20,
        0x00, 0x00,
        0x04, //DXT1
        0x08, //DXT2
        0x08, //DXT4
        0x08,
];

uint pixelFormatGLFormat(TagEnums.BitmapPixelFormat format)
{

    return 0;
}

bool pixelFormatSupported(TagEnums.BitmapPixelFormat format)
{
    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    case a1r5g5b5:
    case r5g6b5:
    case a4r4g4b4:
    case a8r8g8b8:
    case x8r8g8b8:
    case dxt1:
    case dxt3:
    case dxt5:
        return true;
    default:
    }

    return false;
}

uint pixelFormatSize(TagEnums.BitmapPixelFormat format, uint w, uint h)
{
    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    case dxt1: return ((h + 3) / 4) * ((w + 3) / 4) * 8;
    case dxt3:
    case dxt5: return ((h + 3) / 4) * ((w + 3) / 4) * 16;
    default:
    }

    return (w * h * pixelBitSize[int(format)] + 4) / 8;
}

void pixelFormatCopyGpu2D(TagEnums.BitmapPixelFormat format, uint tex, int level, uint w, uint h, void* buffer)
{
    uint size = pixelFormatSize(format, w, h);

    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    default: assert(0);
    }
}

void pixelFormatCopyGpu3D(TagEnums.BitmapPixelFormat format, uint tex, int level, uint w, uint h, uint d, void* buffer)
{
    uint size = pixelFormatSize(format, w, h);

    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    default: assert(0);
    }
}

