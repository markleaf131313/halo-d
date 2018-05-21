
module Game.DebugUi;

import ImGuiC;

import Game.Audio;
import Game.Script;
import Game.SharedGameState;
import Game.World : GObject;

import Game.Cache;
import Game.Console;
import Game.Core;
import Game.Profiler;
import Game.Tags;

struct DebugUi
{
    SharedGameState* gameState;

    int[][TagId] cacheTagPaths;

    size_t gcHead = 0;
    size_t gcCount = 0;
    float[1000] gcUsedValues;
    float[1000] gcFreeValues;

    int[] openedTags;

    GObject* selectedObject;

    void loadCacheTagPaths()
    {
        import std.algorithm.sorting : sort;
        import std.string : fromStringz;

        foreach(int i, ref meta ; Cache.inst.getMetas())
        {
            if(meta.path)
            {
                if(auto group = meta.type in cacheTagPaths)
                {
                    *group ~= i;
                }
                else
                {
                    cacheTagPaths[meta.type] = [ i ];
                }
            }
        }

        foreach(ref group ; cacheTagPaths)
        {
            sort!((a, b) => icmp(fromStringz(Cache.inst.metaAt(a).path), fromStringz(Cache.inst.metaAt(b).path)) < 0)(group);
        }
    }

    void doUi()
    {
        import core.memory : GC;
        import std.algorithm.searching : canFind;

        mixin ProfilerObject.ScopedMarker;

        auto io = igGetIO();

        igBegin("GC");
        igValue("GC used", cast(int)GC.stats.usedSize);
        igValue("GC free", cast(int)GC.stats.freeSize);
        igValue("GC Total", cast(int)(GC.stats.freeSize + GC.stats.usedSize));

        gcUsedValues[gcHead] = GC.stats.usedSize;
        gcFreeValues[gcHead] = GC.stats.freeSize;

        igPlotLines("##GCused", gcUsedValues.ptr, cast(int)gcCount + 1, 0, null, 0, float.max, ImVec2(igGetWindowWidth(), 250));
        igPlotLines("##GCfree", gcFreeValues.ptr, cast(int)gcCount + 1, 0, null, 0, float.max, ImVec2(igGetWindowWidth(), 250));

        gcCount = max(gcHead, gcCount);
        gcHead = (gcHead + 1) % gcUsedValues.length;

        igEnd();

        if(igBegin("Main Window"))
        {
            foreach(tagId ; [EnumMembers!TagId])
            if(auto group = tagId in cacheTagPaths)
            {
                string name = enumName(tagId);

                if(igTreeNode(name.ptr))
                {
                    foreach(index ; *group)
                    {
                        if(igSelectable(Cache.inst.metaAt(index).path))
                        {
                            if(!canFind(openedTags, index))
                            {
                                openedTags ~= index;
                            }
                            else
                            {
                                char[256] windowName = void;
                                snprintf(windowName, "%s##%d", Cache.inst.metaAt(index).path, index);
                                igSetWindowFocus(windowName.ptr);
                            }
                        }
                    }

                    igTreePop();
                }
            }
        }

        igEnd();

        foreach(int j, ref int i ; openedTags)
        {
            auto meta = &Cache.inst.metaAt(i);
            bool opened = true;

            char[1024] buffer = void;
            snprintf(buffer, "%s##%d", meta.path, i);

            igSetNextWindowPos(Vec2(0,0), ImGuiCond_FirstUseEver, Vec2(0.5f, 0.5f));
            if(igBegin(buffer.ptr, &opened, ImGuiWindowFlags_NoSavedSettings))
            {
                InvokeByTag!setView(meta.type, meta.index, meta.data, openedTags, null);
            }
            igEnd();

            if(!opened)
            {
                i = indexNone;
            }
        }

        for(int i = 0; i < openedTags.length; ++i)
        {
            if(openedTags[i] == indexNone)
            {
                openedTags[i] = openedTags[$ - 1];

                openedTags.length -= 1;
                i                 -= 1;
            }
        }

        if(selectedObject)
        {
            bool opened = true;

            igSetNextWindowPos(Vec2(0,0), ImGuiCond_FirstUseEver, Vec2(0.5f, 0.5f));
            igSetNextWindowSize(Vec2(600, 500), ImGuiCond_FirstUseEver);

            if(igBegin("Selected Object Info", &opened))
            {
                if(igButton("Open Tag"))
                {
                    int index = selectedObject.tagIndex.i;

                    if(!canFind(openedTags, index))
                    {
                        openedTags ~= index;
                    }
                    else
                    {
                        char[256] name = void;
                        snprintf(name, "%s##%d", Cache.inst.metaAt(index).path, index);
                        igSetWindowFocus(name.ptr);
                    }
                }

                igPushID(selectedObject);
                selectedObject.byTypeDebugUi();
                igPopID();
            }
            igEnd();

            if(!opened)
            {
                selectedObject = null;
            }
        }

        Console.doUi(gameState.hsRuntime);
        Profiler.doUi();

        igShowMetricsWindow();
    }
}

private void setViewEnum(Field)(const(char)* identifier, ref Field field)
{
    static immutable immutable(char)*[] names = enumNamesArray!Field;

    int currentItem = cast(int)field;
    igCombo(identifier, &currentItem, names.ptr + 1, cast(int)names.length - 1);
    field = cast(Field)currentItem;
}

private void popupFindTag(ref TagRef tagRef, bool initialize)
{
    static int selectedIndex;

    if(initialize)
    {
        selectedIndex = tagRef.index.i;
    }

    igSetNextWindowSize(ImVec2(600, 500), ImGuiCond_FirstUseEver);
    if(igBeginPopupModal("Find Tag"))
    {
        if(igButton("Select"))
        {
            if(selectedIndex != indexNone)
            {
                auto meta = &Cache.inst.metaAt(selectedIndex);

                tagRef.path  = meta.path;
                tagRef.index = meta.index;
            }

            igCloseCurrentPopup();
        }

        igSameLine();

        if(igButton("Cancel"))
        {
            igCloseCurrentPopup();
        }

        igBeginChild("Scroll");
        igColumns(2);

        foreach(int j, ref meta ; Cache.inst.getMetas())
        {
            igPushID(j);

            const auto flags = ImGuiSelectableFlags_SpanAllColumns | ImGuiSelectableFlags_DontClosePopups;
            if(igSelectable(meta.path, selectedIndex == j, flags))
            {
                selectedIndex = j;
            }

            igNextColumn();

            if(string name = enumName(meta.type))
            {
                igText(name.ptr);
            }
            else
            {
                char[5] buffer;

                *cast(TagId*)buffer.ptr = meta.type;

                igText(buffer.ptr);
            }

            igNextColumn();
            igPopID();
        }
        igEndChild();


        igEndPopup();
    }
}

void setView(T)(DatumIndex tagIndex, void* f, ref int[] tags, int[] blockIndices = [])
{
    import std.meta   : Alias;
    import std.traits : getUDAs;
    import std.algorithm.searching : canFind;
    import core.stdc.string : strlen;

    T* fields = cast(T*)f;

    static if(__traits(getAliasThis, T).length)
    {
        alias Type = typeof(__traits(getMember, fields, __traits(getAliasThis, T)[0]));
        setView!Type(tagIndex, &__traits(getMember, fields, __traits(getAliasThis, T)[0]), tags);
    }

    igPushID(f);
    scope(exit) igPopID();

    static if(is(T == Tag.SoundPermutationsBlock))
    {
        if(igButton("Play"))
        {
            Audio.inst.playDebug(tagIndex, blockIndices[$ - 2], blockIndices[$ - 1]);
        }
    }

    static if(is(T == TagSoundLooping))
    {{
        TagSoundLooping* tagSoundLooping = cast(T*)f;

        if(tagSoundLooping.playingIndex)
        {
            if(igButton("Stop"))
            {
                assert(0);
            }
        }
        else
        {
            if(igButton("Play"))
            {
                tagSoundLooping.playingIndex = Audio.inst.createObjectLoopingSound(tagIndex);
            }
        }
    }}

    foreach(i, ref field ; fields.tupleof)
    {

        alias Field = typeof(field);
        alias identifier = Alias!(__traits(identifier, T.tupleof[i]));

        igPushID(&field);
        scope(exit) igPopID();

        alias explainUdas = getUDAs!(typeof(*fields).tupleof[i], TagExplanation);

        static if(explainUdas.length)
        {
            static if(explainUdas[0].header.length)      igText(explainUdas[0].header);
            static if(explainUdas[0].explanation.length) igTextWrapped(explainUdas[0].explanation);
        }

        static      if(is(Field == enum))      setViewEnum(identifier, field);
        else static if(is(Field == int))       igInputInt(identifier, &field);
        else static if(is(Field == short))     igInputShort(identifier, &field);
        else static if(is(Field == float))     igInputFloat(identifier, &field);
        else static if(is(Field == TagString)) igInputText(identifier, field.ptr, 32);
        else static if(is(Field == Vec3))      igInputFloat3(identifier, &field.x);
        else static if(is(Field == TagData))   igInputInt(identifier, &field.size);
        else static if(is(Field == ColorRgb))
        {
            float[3] value = [ field.r, field.g, field.b ];
            if(igColorEdit3(identifier, value.ptr))
            {
                field.r = value[0];
                field.g = value[1];
                field.b = value[2];
            }
        }
        else static if(is(Field == ColorArgb))
        {
            float[4] value = [ field.r, field.g, field.b, field.a ];
            if(igColorEdit4(identifier, value.ptr))
            {
                field.a = value[3];
                field.r = value[0];
                field.g = value[1];
                field.b = value[2];
            }
        }
        else static if(is(Field : TagBounds!Bound, Bound))
        {
            static      if(is(Bound == int))   igDragIntRange2  (identifier, &field.lower, &field.upper);
            else static if(is(Bound == short)) igDragShortRange2(identifier, &field.lower, &field.upper);
            else static if(is(Bound == float)) igDragFloatRange2(identifier, &field.lower, &field.upper);
            else static assert(0);
        }
        else static if(is(Field == TagRef))
        {
            bool initialize = false;

            if(igButton("..."))
            {
                igOpenPopup("Find Tag");
                initialize = true;
            }

            igSameLine();

            if(igButton("clear"))
            {
                field.index = DatumIndex.none;
                field.path = null;
            }

            igSameLine();

            if(igButton("Open"))
            {
                if(field.isValid())
                {
                    int index = field.index.i;

                    if(!canFind(tags, index))
                    {
                        tags ~= index;
                    }
                    else
                    {
                        char[256] name = void;
                        snprintf(name, "%s##%d", Cache.inst.metaAt(index).path, index);
                        igSetWindowFocus(name.ptr);
                    }
                }
            }

            {
                char[1] nullBuffer = void;
                nullBuffer[0] = 0;

                auto len = field.path ? strlen(field.path) : 0;

                igSameLine();
                igInputText(identifier, field.path ? cast(char*)field.path : nullBuffer.ptr,
                    len, ImGuiInputTextFlags_ReadOnly);
            }

            popupFindTag(field, initialize);

        }
        else static if(is(Field : TagBlock!BlockType, BlockType))
        {
            if(field.ptr && field.size)
            {
                igSetNextTreeNodeOpen(true, ImGuiCond_FirstUseEver);
            }

            if(igTreeNode(identifier))
            {
                igSliderInt("##index", &field.debugIndex, 0, max(0, field.size - 1));

                if(field.ptr && field.size)
                {
                    // SliderInt doesn't respect input bounds...
                    field.debugIndex = clamp(field.debugIndex, 0, max(0, field.size - 1));

                    setView!(typeof(*field.ptr))(tagIndex, field.ptr + field.debugIndex,
                        tags, blockIndices ~ field.debugIndex);
                }

                igTreePop();
            }
        }
        else static if(is(Field : V[size], V, int size) && is(V == struct))
        {
            foreach(j, ref value ; field)
            {
                igText("%s %d", identifier.ptr, j);
                igIndent();
                setView!(typeof(value))(tagIndex, &value, tags);
                igUnindent();
            }
        }
        else
        {
            continue;
        }

        alias udas = getUDAs!(typeof(*fields).tupleof[i], TagField);

        static if(udas.length)
        {
            if(igIsItemHovered())
            {
                igBeginTooltip();
                igText(udas[0].comment);
                igEndTooltip();
            }
        }
    }

    alias explainUdas = getUDAs!(T, TagExplanation);

    static if(explainUdas.length)
    {
        static if(explainUdas[0].header.length)      igText(explainUdas[0].header);
        static if(explainUdas[0].explanation.length) igTextWrapped(explainUdas[0].explanation);
    }
}
