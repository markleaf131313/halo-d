
module Game.Render.Private.Pixels;

import OpenGL;

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
    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    case a1r5g5b5: return GL_RGB5_A1;
    case r5g6b5:   return GL_RGB5;
    case a4r4g4b4: return GL_RGBA4;
    case a8r8g8b8: return GL_RGBA8;
    case x8r8g8b8: return GL_RGB8;
    case dxt1: return GL_COMPRESSED_RGB_S3TC_DXT1_EXT;
    case dxt3: return GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
    case dxt5: return GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
    default:
    }

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
    case a1r5g5b5: glTextureSubImage2D(tex, level, 0, 0, w, h, GL_BGRA, GL_UNSIGNED_SHORT_1_5_5_5_REV, buffer); break;
    case r5g6b5:   glTextureSubImage2D(tex, level, 0, 0, w, h, GL_RGB,  GL_UNSIGNED_SHORT_5_6_5, buffer);       break;
    case a4r4g4b4: glTextureSubImage2D(tex, level, 0, 0, w, h, GL_BGRA, GL_UNSIGNED_SHORT_4_4_4_4_REV, buffer); break;
    case a8r8g8b8: glTextureSubImage2D(tex, level, 0, 0, w, h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, buffer);   break;
    case x8r8g8b8: glTextureSubImage2D(tex, level, 0, 0, w, h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, buffer);   break;

    case dxt1: glCompressedTextureSubImage2D(tex, level, 0, 0, w, h, GL_COMPRESSED_RGB_S3TC_DXT1_EXT,  size, buffer); break;
    case dxt3: glCompressedTextureSubImage2D(tex, level, 0, 0, w, h, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, size, buffer); break;
    case dxt5: glCompressedTextureSubImage2D(tex, level, 0, 0, w, h, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, size, buffer); break;
    default: assert(0);
    }
}

void pixelFormatCopyGpu3D(TagEnums.BitmapPixelFormat format, uint tex, int level, uint w, uint h, uint d, void* buffer)
{
    uint size = pixelFormatSize(format, w, h);

    switch(format) with(TagEnums.BitmapPixelFormat)
    {
    case a1r5g5b5: glTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_BGRA, GL_UNSIGNED_SHORT_1_5_5_5_REV, buffer); break;
    case r5g6b5:   glTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_RGB,  GL_UNSIGNED_SHORT_5_6_5, buffer);       break;
    case a4r4g4b4: glTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_BGRA, GL_UNSIGNED_SHORT_4_4_4_4_REV, buffer); break;
    case a8r8g8b8: glTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, buffer);   break;
    case x8r8g8b8: glTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, buffer);   break;

    case dxt1: glCompressedTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_COMPRESSED_RGB_S3TC_DXT1_EXT,  size, buffer); break;
    case dxt3: glCompressedTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, size, buffer); break;
    case dxt5: glCompressedTextureSubImage3D(tex, level, 0, 0, d, w, h, 1, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, size, buffer); break;
    default: assert(0);
    }
}

