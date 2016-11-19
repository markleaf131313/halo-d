
module Game.Cache.SharedResourceCache;

import std.stdio : File;

import Game.Cache.Cache;
import Game.Core.Io : rawRead;

struct SharedResourceCache
{
    struct Meta
    {
        static assert(this.sizeof == 12);

        uint pathOffset;
        uint dataSize;
        uint dataOffset;
    }

    void load(string filename)
    {
        file.open(filename, "rb");
        rawRead(file, &header);
    }

    void read(uint offset, void* buffer, uint size)
    {
        file.seek(offset);
        file.rawRead(buffer[0 .. size]);
    }

    void* loadResourceIntoCache(ref Cache cache, uint index)
    {
        Meta meta = readMeta(index);

        byte[] buffer = cache.allocateFromBuffer(meta.dataSize);

        file.seek(meta.dataOffset);
        file.rawRead(buffer);

        return buffer.ptr;
    }

    char[] readPathNames()
    {
        char[] result = new char[](header.metaOffset - header.stringOffset);
        read(header.stringOffset, result.ptr, result.length);
        return result;
    }

    Meta[] readMetaTable()
    {
        Meta[] result = new Meta[](header.count);
        read(header.metaOffset, result.ptr, header.count * Meta.sizeof);
        return result;
    }

private:

    struct Header
    {
        static assert(this.sizeof == 16);

        uint type;
        uint stringOffset;
        uint metaOffset;
        uint count;
    }

    Header header;
    File   file;

    Meta readMeta(uint index)
    {
        Meta result = void;

        file.seek(header.metaOffset + index * Meta.sizeof);
        rawRead(file, &result);

        return result;
    }
}