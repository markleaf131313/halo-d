
module Game.Tags.Types;

import std.string : fromStringz;

public import Game.Core.Math
    : Vec2s, Vec2, Vec3, Vec4, Quat, Plane2, Plane3, Euler3
    , ColorRgb, ColorArgb, ColorRgb8, ColorArgb8;

public import Game.Tags.Generated.Meta;

public import Game.Core.Containers.DatumArray : DatumIndex;
import Game.Core.Memory : ExactPointer32;

mixin template TagPad(int size)
{
    private ubyte[size] pad__;
}

struct TagField
{
    string comment;
}

struct TagExplanation
{
    string header;
    string explanation;
}

struct TagRef
{
@nogc nothrow:

    static assert(this.sizeof == 0x10);

    @disable this(this);

    alias isValid this;

    TagId id;
    ExactPointer32!(const(char)) path;
    uint length;
    DatumIndex index;

    bool isValid() const
    {
        return index != DatumIndex.none;
    }

    bool isIndexNone() const
    {
        return index == DatumIndex.none;
    }
}

struct TagBlock(T)
{
@nogc nothrow:

    static assert(this.sizeof == 0xC);

    @disable this();
    @disable this(this);

    int size;
    ExactPointer32!T ptr;
    int debugIndex; // this is normally only used in editors, but we repurpose it

    alias ptr this;

    bool inUpperBound(int i) const
    {
        return i < size;
    }

    bool inBounds(int i) const
    {
        return i >= 0 && i < size;
    }

    pragma(inline, true)
    ref auto opIndex(int i) inout
    in
    {
        assert(i >= 0 && i < size);
    }
    body
    {
        return ptr[i];
    }

    pragma(inline, true)
    inout(T)[] opSlice() inout
    {
        return ptr ? ptr[0 .. size] : ptr[0 .. 0];
    }

    inout(T)[] opSlice(int a, int b) inout
    {
        return ptr[a .. b];
    }

    pragma(inline, true)
    int opDollar() const
    {
        return size;
    }

}

struct TagData
{
@nogc nothrow:

    static assert(this.sizeof == 0x14);

    @disable this();
    @disable this(this);

    int size;
    bool external;
    int offset;

    ExactPointer32!void data;

    int pad2;

    T* dataAs(T)() const
    {
        return cast(T*)data;
    }
}

// TODO(REFACTOR) nothing really "tag" about this, could just rename to "Bounds" or "BoundedValue" etc...
struct TagBounds(T)
{
@nogc nothrow:

    T lower;
    T upper;

    bool inBounds(string boundaries)(T value) const
    {
        static if(boundaries == "[]")
        {
            return value >= lower && value <= upper;
        }
        else
        {
            static assert(0, "Invalid boundaries \"" ~ boundaries ~ "\".");
        }
    }

    static if(is(T == float))
    {
        float mix(float a) const
        {
            return (upper - lower) * a + lower;
        }
    }
}

struct TagString
{
@nogc nothrow:

    static assert(this.sizeof == 32);

    @disable this(this);

    alias toStr this;

    const(char)[] toStr() const
    {
        return fromStringz(buffer.ptr);
    }

    bool isEmpty() const
    {
        return buffer[0] == '\0';
    }

    inout(char)* ptr() inout
    {
        return buffer.ptr;
    }

private:

    char[32] buffer;

}

struct TagModelVertex
{
    static assert(this.sizeof == 0x44);

    Vec3 position;
    Vec3 normal;
    Vec3 binormal;
    Vec3 tangent;

    Vec2 uv;

    short node0, node1;
    Vec2 weight;
}

struct TagBspVertex
{
    static assert(this.sizeof == 0x38);

    Vec3 position;
    Vec3 normal;
    Vec3 binormal;
    Vec3 tangent;

    Vec2 coord;
}

struct TagBspLightmapVertex
{
    static assert(this.sizeof == 0x14);

    Vec3 normal;
    Vec2 coord;
}
