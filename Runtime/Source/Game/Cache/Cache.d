
module Game.Cache.Cache;

import std.stdio  : File;
import std.string : fromStringz;

import Game.Cache.SharedResourceCache;

import Game.Audio;
import Game.Tags;
import Game.Core;


private alias LoadFunctionsMap = void function(ref Cache, ref Cache.Meta, ref Cache.SharedLoadData)[uint];
private immutable LoadFunctionsMap mapToLoadFunctions;

shared static this()
{
    import std.ascii     : toUpper;
    import std.exception : assumeUnique;

    static void proxy(T)(ref Cache cache, ref Cache.Meta meta, ref Cache.SharedLoadData loadData)
    {
        cache.loadTag!T(meta, loadData);
    }

    LoadFunctionsMap map;

    foreach(member ; __traits(allMembers, TagId))
    {
        mixin("map[TagId." ~ member ~ "] = &proxy!Tag" ~ toUpper(member[0]) ~ member[1 .. $] ~ ";");
    }

    map.rehash;
    mapToLoadFunctions = assumeUnique(map);

}

struct Cache
{
@disable this(this);

struct Meta
{
    static assert(this.sizeof == 0x20);

    @disable this(this);

    TagId type;
    TagId[2] parentTypes;

    DatumIndex index;

    ExactPointer32!(const(char)) path;
    ExactPointer32!void          data;

    bool external;
    int pad0;

    @property T* tagData(T)()
    {
        return cast(T*)data;
    }
}

enum maxBufferSize = 0x400_0000;

private __gshared Cache* instance;

SharedResourceCache bitmapCache;
SharedResourceCache soundCache;
SharedResourceCache locCache;

static @nogc nothrow pragma(inline, true)
{
    @property Cache* inst()                { return instance; }
    @property void   inst(Cache* instance) { this.instance = instance; }

    T* get(T)(ref const(DatumIndex) i) { return i == DatumIndex.none ? null : cast(T*)inst.metas[i.i].data; }
    T* get(T)(ref const(TagRef)   r)   { return get!T(r.index); }
}

~this()
{
    import core.sys.windows.windows : VirtualFree, MEM_RELEASE;

    VirtualFree(buffer, 0, MEM_RELEASE);
}

void load(in string filename)
{
    struct MapHeader
    {
        static assert(this.sizeof == 100);

        int head;
        int game;

        private int fileSize; // can't trust this value

        int pad0;

        uint tagTableOffset;
        uint tagTableSize;

        int pad1;
        int pad2;

        char[32] name;
        char[32] versionString;

        enum Type
        {
            singleplayer,
            multiplayer,
            ui
        }

        Type type;
    }

    if(buffer is null)
    {
        import core.sys.windows.windows : VirtualAlloc, MEM_COMMIT, MEM_RESERVE, PAGE_READWRITE;

        // mallocCast!byte(maxBufferSize);
        buffer = cast(byte*)VirtualAlloc(cast(void*)0x4044_0000, maxBufferSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

        table  = cast(TagTable*)buffer;
        metas  = cast(Meta*)(buffer + TagTable.sizeof);

        bitmapCache.load("maps/bitmaps.map");
        soundCache .load("maps/sounds.map");
        locCache   .load("maps/loc.map");
    }

    MapHeader header = void;

    file.open(filename, "rb");
    rawRead(file, &header);

    //assert(header.head == "head");

    file.seek(header.tagTableOffset);
    file.rawRead(buffer[0 .. header.tagTableSize]);

    bufferSize = header.tagTableSize;

    SharedLoadData sharedLoadData =
    {
        { &soundCache, soundCache.readMetaTable(), soundCache.readPathNames() }
    };

    foreach(ref meta ; metas[0 .. table.metaCount])
    {
        meta.path = fixPointer(meta.path);

        if(auto loadFunc = meta.type in mapToLoadFunctions)
        {
            (*loadFunc)(this, meta, sharedLoadData);
        }

        if(meta.type == TagId.globals)
        {
            globalsIndex = meta.index.i;
        }
    }

    auto scenario = cast(TagScenario*)metas[0].data;
    assert(scenario !is null);

    foreach(ref bsp ; scenario.structureBsps[0 .. 1])
    {
        Meta* meta = &metas[bsp.structureBsp.index.i];
        void** buf = fixPointer(cast(void**)bsp.ptr);

        file.seek(bsp.offset);
        file.rawRead((cast(byte*)buf)[0 .. bsp.size]);

        meta.data = *buf;

        loadTag!TagScenarioStructureBsp(*meta, sharedLoadData);
    }

}

void read(uint offset, void* buffer, uint size)
{
    file.seek(offset);
    file.rawRead((cast(ubyte*)buffer)[0 .. size]);
}

void readModelVertexData(ref ubyte[] vertexData, ref ubyte[] indexData)
{
    file.seek(table.modelDataOffset);

    vertexData.length = table.vertexDataSize;
    indexData.length  = table.modelDataSize - table.vertexDataSize;

    file.rawRead(vertexData);
    file.rawRead(indexData);
}

@nogc nothrow pragma(inline, true)
@property TagScenario* scenario()
{
    return metas[0].tagData!TagScenario;
}

@nogc nothrow pragma(inline, true)
@property TagGlobals* globals()
{
    return metas[globalsIndex].tagData!TagGlobals;
}

@nogc nothrow
Meta[] getMetas()
{
    return metas[0 .. table.metaCount];
}

@nogc nothrow pragma(inline, true)
ref Meta metaAt(ref DatumIndex i)
{
    return metas[i.i];
}

@nogc nothrow pragma(inline, true)
ref Meta metaAt(int i)
{
    return metas[i];
}

pragma(inline, true)
T* fixPointer(T)(T* ptr)
{
    return ptr is null ? null : cast(T*)(cast(size_t)buffer + (cast(size_t)ptr - 0x4044_0000));
}

byte[] allocateFromBuffer(size_t size)
{
    byte* result = buffer + bufferSize;
    bufferSize += size;

    assert(bufferSize <= maxBufferSize);

    return result[0 .. size];
}

private:

struct TagTable
{
    static assert(this.sizeof == 0x28);

    ExactPointer32!void metas;
    int scenarioIndex;
    int last;

    int metaCount;

    uint vertexDataCount;
    uint modelDataOffset;
    uint tagIndexCount;
    uint vertexDataSize;
    uint modelDataSize;

    char[4] footer; // "tags"
}

struct SharedLoadData
{
    struct Type
    {
        SharedResourceCache* cache;
        SharedResourceCache.Meta[] metas;
        char[] paths;
    }
    Type sounds;
}

File file;

TagTable* table;
Meta*     metas;

int globalsIndex;

byte* buffer;
uint  bufferSize;

void loadTag(T)(ref Meta meta, ref SharedLoadData sharedLoadData)
{
    if(!meta.external)
    {
        if(meta.data)
        {
            meta.data = fixPointer(meta.data);
            loadBlockFields(cast(T*)meta.data);
        }
    }
    else
    {
        static if(is(T == TagBitmap) || is(T == TagFont))
        {
            static if(is(T == TagBitmap)) alias sharedCache = bitmapCache;
            else                          alias sharedCache = locCache;

            meta.data = sharedCache.loadResourceIntoCache(this, cast(uint)meta.data);
            loadBlockFieldsExternal(cast(T*)meta.data, cast(uint)meta.data);
        }
        else static if(is(T == TagSound))
        {
            loadTagSound(meta, sharedLoadData);
        }
        else static if(is(T == TagUnicodeStringList) || is(T == TagHudMessageText))
        {
            pragma(msg, __FILE__ ~ " Reminder: implement this for " ~ T.stringof);
        }
        else
        {
            assert(false, "Invalid type (" ~ T.stringof ~ ") to be external.");
        }
    }
}

void loadTagSound(ref Meta meta, ref SharedLoadData sharedLoadData)
{
    meta.data = fixPointer(meta.data);

    TagSound* tagSound = meta.tagData!TagSound;
    const(char)[] soundPath = fromStringz(meta.path);

    auto sharedMeta = sharedLoadData.sounds.metas.findFirst!(
    (ref x, ref y)
    {
        import std.string : icmp;
        return icmp(fromStringz(sharedLoadData.sounds.paths.ptr + x.pathOffset), y) == 0;
    })(soundPath);

    if(sharedMeta is null)
    {
        return;
    }

    SharedResourceCache* cache = sharedLoadData.sounds.cache;
    TagSound tempTagSound = void;

    cache.read(sharedMeta.dataOffset, &tempTagSound, TagSound.sizeof);

    tagSound.pitchRanges.ptr = null; // todo specific loading code for ranges ?
    tagSound.sampleRate  = tempTagSound.sampleRate;
    tagSound.encoding    = tempTagSound.encoding;
    tagSound.compression = tempTagSound.compression;

    // todo copy unmapped field (offset = 0x84)

    uint start = 0;

    if(sharedMeta.dataSize > TagSound.sizeof)
    {
        byte[] data = allocateFromBuffer(sharedMeta.dataSize - TagSound.sizeof);
        cache.read(sharedMeta.dataOffset + TagSound.sizeof, data.ptr, data.length);
        start = cast(uint)data.ptr;
    }

    loadBlockFieldsExternal(tagSound, start);

    foreach(ref pitchRange ; tagSound.pitchRanges)
    foreach(ref permutation ; pitchRange.permutations)
    {
        void* data = mallocCast!void(permutation.samples.size);
        permutation.cacheBufferIndex = Audio.inst.addSampleData(data);

        cache.read(permutation.samples.offset, data, permutation.samples.size);

    }
}

void loadBlockFields(T)(T* block)
{
    void implLoadBlockFields(T)(T* block)
    {
        foreach(ref member ; block.tupleof)
        {
            alias Member = typeof(member);

            static if(is(Member : TagBlock!U, U))
            {
                member.ptr = fixPointer(member.ptr);

                foreach(ref i ; member)
                {
                    loadBlockFields(&i);
                }
            }
            else static if(is(Member == TagRef))
            {
                member.path = fixPointer(member.path);
            }
            else static if(is(Member == TagData))
            {
                // member.data = fixPointer(member.data); // TODO, do we need this for data ?
            }
            else static if(is(Member : T[size], T, int size) && is(T == struct))
            {
                foreach(ref f ; member)
                {
                    implLoadBlockFields(&f);
                }
            }
        }
    }

    enum parents = __traits(getAliasThis, T);

    static if(parents.length == 1)
    {
        loadBlockFields(&mixin("block." ~ parents[0]));
    }

    implLoadBlockFields(block);
}

void loadBlockFieldsExternal(T)(T* block, uint start)
{
    void implLoadBlockFieldsExternal(T)(T* block, uint start)
    {
        foreach(ref member ; block.tupleof)
        {
            alias Member = typeof(member);

            static if(is(Member : TagBlock!U, U))
            {
                member.debugIndex = 0;

                if(member.size)
                {
                    member.ptr = cast(typeof(member.ptr))(cast(uint)member.ptr + start);

                    foreach(ref i ; member)
                    {
                        loadBlockFieldsExternal(&i, start);
                    }
                }
            }
            else static if(is(Member == TagRef))
            {
                member.path = fixPointer(member.path);
            }
            else static if(is(Member == TagData))
            {
                if(member.data)
                {
                    member.data = cast(void*)(cast(uint)member.data + start);
                }
            }
            else static if(is(Member : T[size], T, int size) && is(T == struct))
            {
                foreach(ref f ; member)
                {
                    implLoadBlockFieldsExternal(&f, start);
                }
            }
        }
    }

    enum parents = __traits(getAliasThis, T);

    static if(parents.length == 1)
    {
        loadBlockFieldsExternal(&mixin("block." ~ parents[0]), start);
    }

    implLoadBlockFieldsExternal(block, start);

}

}