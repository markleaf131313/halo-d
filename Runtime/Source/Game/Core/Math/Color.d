
module Game.Core.Math.Color;

import std.math     : abs, floor;
import std.bitmanip : bitfields;

import Game.Core.Math.Algorithms;
import Game.Core.Math.Vector;


struct ColorRgb
{
@nogc pure nothrow:

    union
    {
        struct
        {
            float r;
            float g;
            float b;
        }

        private float[3] values;
    }

    this(float rgb)
    {
        r = rgb;
        g = rgb;
        b = rgb;
    }

    this(float r, float g, float b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }

    this(ColorArgb8 color)
    {
        r = color.r / float(ubyte.max);
        g = color.g / float(ubyte.max);
        b = color.b / float(ubyte.max);
    }

    ref inout(float[3]) opSlice() inout return
    {
        return values;
    }

    ColorRgb opBinaryRight(string op)(ColorRgb color) if(op == "+" || op == "*")
    {
        mixin("return ColorRgb(r " ~ op ~ " color.r, g " ~ op ~ " color.g, b " ~ op ~ " color.b);");
    }

    ColorRgb opBinary(string op)(float scalar) if(op == "+" || op == "-" ||  op == "*")
    {
        mixin("return ColorRgb(scalar "~ op ~" r, scalar "~ op ~" g, scalar "~ op ~" b);");
    }

    ColorRgb opBinaryRight(string op)(float scalar) if(op == "+" || op == "-" || op == "*")
    {
        mixin("return ColorRgb(r "~ op ~" scalar, g "~ op ~" scalar, b "~ op ~" scalar);");
    }

    @property ref inout(Vec3) asVector() return inout
    {
        return *cast(typeof(return)*)&this;
    }

    ColorHsv toHsv() const
    {
        ColorHsv result = void;

        float min = .min(r, g, b);
        float max = .max(r, g, b);
        float delta = max - min;

        result.v = max;

        if(max == 0.0f) result.s = 0.0f;
        else            result.s = delta / max;

        if(result.s == 0.0f)
        {
            result.h = 0.0f;
        }
        else
        {

            if     (r == max) result.h = (g - b) / delta;
            else if(g == max) result.h = (b - r) / delta + 2.0f;
            else              result.h = (r - g) / delta + 4.0f;

            result.h *= 1.0f / 6.0f;

            if(result.h < 0.0f)
            {
                result.h += 1.0f;
            }
        }

        return result;
    }

}

struct ColorArgb
{
@nogc pure nothrow:

    union
    {
        struct
        {
            float a;
            float r;
            float g;
            float b;
        }

        struct
        {
            private float _a;
            ColorRgb rgb;
        }

        private float[4] values;
    }

    this(float argb)
    {
        a = argb;
        r = argb;
        g = argb;
        b = argb;
    }

    this(float a, float r, float g, float b)
    {
        this.a = a;
        this.r = r;
        this.g = g;
        this.b = b;
    }

    this(float a, ColorRgb color)
    {
        this.a = a;
        r = color.r;
        g = color.g;
        b = color.b;
    }

    this(ColorArgb8 color)
    {
        a = color.a / float(ubyte.max);
        r = color.r / float(ubyte.max);
        g = color.g / float(ubyte.max);
        b = color.b / float(ubyte.max);
    }

    ref inout(float[4]) opSlice() inout return
    {
        return values;
    }

    ColorArgb opBinary(string op)(float scalar) if(op == "+" || op == "-" ||  op == "*")
    {
        mixin("return ColorArgb(scalar "~ op ~" a, scalar "~ op ~" r, scalar "~ op ~" g, scalar "~ op ~" b);");
    }

    ColorArgb opBinaryRight(string op)(float scalar) if(op == "+" || op == "-" || op == "*")
    {
        mixin("return ColorArgb(a "~ op ~" scalar, r "~ op ~" scalar, g "~ op ~" scalar, b "~ op ~" scalar);");
    }
}

struct ColorArgb8
{
@nogc pure nothrow:

    union
    {
        struct
        {
            ubyte a;
            ubyte r;
            ubyte g;
            ubyte b;
        }

        uint value;
    }

    this(ubyte argb)
    {
        a = argb;
        r = argb;
        g = argb;
        b = argb;
    }

    this(ColorRgb8 color)
    {
        a = ubyte.max;
        r = color.r;
        b = color.b;
        g = color.g;
    }

    this(ColorArgb4 color)
    {
        a = cast(ubyte)(color.a << 4) | color.a;
        r = cast(ubyte)(color.r << 4) | color.r;
        g = cast(ubyte)(color.g << 4) | color.g;
        b = cast(ubyte)(color.b << 4) | color.b;
    }

    this(ColorArgb1555 color)
    {
        a = cast(ubyte)(color.a * ubyte.max);
        r = cast(ubyte)((color.r * 527u + 23u) >>> 6u);
        g = cast(ubyte)((color.g * 527u + 23u) >>> 6u);
        b = cast(ubyte)((color.b * 527u + 23u) >>> 6u);
    }

    this(ColorRgb565 color)
    {
        a = ubyte.max;
        r = cast(ubyte)((color.r * 527u + 23u) >>> 6u);
        g = cast(ubyte)((color.g * 259u + 33u) >>> 6u);
        b = cast(ubyte)((color.b * 527u + 23u) >>> 6u);
    }
}

struct ColorRgb8
{
@nogc pure nothrow:

    union
    {
        struct
        {
            ubyte _;
            ubyte r;
            ubyte g;
            ubyte b;
        }

        uint value;
    }

    this(ubyte rgb)
    {
        r = rgb;
        g = rgb;
        b = rgb;
    }

    this(ubyte r, ubyte g, ubyte b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }

}

struct ColorRgb565
{
@nogc pure nothrow:

    static assert(this.sizeof == 2);

    union
    {
        mixin(bitfields!(
            ubyte, "b", 5,
            ubyte, "g", 6,
            ubyte, "r", 5,
        ));

        ushort value;
    }

}

struct ColorArgb1555
{
@nogc pure nothrow:

    static assert(this.sizeof == 2);

    union
    {
        mixin(bitfields!(
            ubyte, "a", 1,
            ubyte, "r", 5,
            ubyte, "g", 5,
            ubyte, "b", 5,
        ));

        ushort value;
    }

}

struct ColorArgb4
{
@nogc pure nothrow:

    import std.bitmanip : bitfields;

    static assert(this.sizeof == 2);

    union
    {
        mixin(bitfields!(
            ubyte, "a", 4,
            ubyte, "r", 4,
            ubyte, "g", 4,
            ubyte, "b", 4,
        ));

        ushort value;
    }

}

struct ColorHsv
{
    float h;
    float s;
    float v;

    ColorRgb toRgb() const
    {
        ColorRgb result;

        if(s == 0.0f)
        {
            result.r = v;
            result.g = v;
            result.b = v;
        }
        else
        {
            int   i = cast(int)floor(h);
            float f = h - i;

            float p = v * (1.0f - s);
            float q = v * (1.0f - s * f);
            float t = v * (1.0f - s * (1.0f - f));

            switch(i)
            {
            case 0: result.r = v; result.g = t; result.b = p; break;
            case 1: result.r = q; result.g = v; result.b = p; break;
            case 2: result.r = p; result.g = v; result.b = t; break;
            case 3: result.r = p; result.g = q; result.b = v; break;
            case 4: result.r = t; result.g = p; result.b = v; break;
            case 5: result.r = v; result.g = p; result.b = q; break;
            default:
            }
        }

        return result;
    }
}

ColorArgb saturate(ColorArgb color)
{
    return ColorArgb(
        Game.Core.Math.Algorithms.saturate(color.a),
        Game.Core.Math.Algorithms.saturate(color.r),
        Game.Core.Math.Algorithms.saturate(color.g),
        Game.Core.Math.Algorithms.saturate(color.b));
}

ColorRgb saturate(ColorRgb color)
{
    return ColorRgb(
        Game.Core.Math.Algorithms.saturate(color.r),
        Game.Core.Math.Algorithms.saturate(color.g),
        Game.Core.Math.Algorithms.saturate(color.b));
}

ColorRgb clamp(ColorRgb color, float min, float max)
{
    return ColorRgb(
        Game.Core.Math.Algorithms.clamp(color.r, min, max),
        Game.Core.Math.Algorithms.clamp(color.g, min, max),
        Game.Core.Math.Algorithms.clamp(color.b, min, max));
}

ColorArgb clamp(ColorArgb color, float min, float max)
{
    return ColorArgb(
        Game.Core.Math.Algorithms.clamp(color.a, min, max),
        Game.Core.Math.Algorithms.clamp(color.r, min, max),
        Game.Core.Math.Algorithms.clamp(color.g, min, max),
        Game.Core.Math.Algorithms.clamp(color.b, min, max));
}

ColorRgb mixColor(ColorRgb lower, ColorRgb upper, float a, bool useHsv, bool acrossLongHuePath)
{
    ColorRgb result;

    if(useHsv)
    {
        ColorHsv lowerHsv = lower.toHsv();
        ColorHsv upperHsv = upper.toHsv();

        if((abs(lowerHsv.h - upperHsv.h) > 0.5f) != acrossLongHuePath)
        {
            if(lowerHsv.h >= upperHsv.h) upperHsv.h += 1.0f;
            else                         lowerHsv.h += 1.0f;
        }

        ColorHsv hsv =
        {
            h: mix(lowerHsv.h, upperHsv.h, a),
            s: mix(lowerHsv.s, upperHsv.s, a),
            v: mix(lowerHsv.v, upperHsv.v, a),
        };

        if(hsv.h > 1.0f)
        {
            hsv.h -= 1.0f;
        }

        result = hsv.toRgb();
    }
    else
    {
        result.r = mix(lower.r, upper.r, a);
        result.g = mix(lower.g, upper.g, a);
        result.b = mix(lower.b, upper.b, a);
    }

    return result;
}