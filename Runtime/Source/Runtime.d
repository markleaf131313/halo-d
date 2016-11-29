
import core.sys.windows.dll : SimpleDllMain;

import std.conv      : emplace, to;
import std.datetime  : StopWatch, Duration, dur;
import std.exception : enforce;
import std.meta;
import std.stdio;
import std.string    : fromStringz;
import std.traits    : EnumMembers;

import OpenGL;
import SDL2;
import imgui;

import Game.Audio;
import Game.Cache;
import Game.Core;
import Game.GameInterface;
import Game.SharedGameState;
import Game.Tags;
import Game.World;
import Game.World.Player;


mixin SimpleDllMain;


__gshared int[][TagId] cacheTagPaths; // todo temp debugging
__gshared StopWatch frameStopWatch;
__gshared Duration lastTime;
__gshared Duration accumulator;

void loadCacheTagPaths()
{
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
        import std.algorithm.sorting : sort;
        import std.uni : icmp;
        import std.string : fromStringz;

        sort!((a, b) => icmp(fromStringz(Cache.inst.metaAt(a).path), fromStringz(Cache.inst.metaAt(b).path)) < 0)(group);
    }
}

extern(C) void imguiSetClipboardText(const(char)* text) nothrow @nogc
{
    SDL_SetClipboardText(text);
}

extern(C) auto imguiGetClipboardText() nothrow @nogc
{
    return SDL_GetClipboardText();
}

@property
bool toggleKeyPress(int p)()
{
    static bool pressed;

    const(ubyte)* state = SDL_GetKeyboardState(null);

    if(state[p])
    {
        if(!pressed)
        {
            pressed = true;
            return true;
        }
    }
    else
    {
        pressed = false;
    }

    return false;
}

export extern(C) void grabInterface(GameInterface* gameInterface, uint sizeof)
{
    assert(GameInterface.sizeof == sizeof);

    gameInterface.sharedGameStateSizeof = SharedGameState.sizeof;
    gameInterface.gameStep              = cast(typeof(GameInterface.gameStep))&gameStep;
    gameInterface.initSharedGameState   = cast(typeof(GameInterface.initSharedGameState))&initSharedGameState;
    gameInterface.createSharedGameState = cast(typeof(GameInterface.createSharedGameState))&createSharedGameState;

    gameInterface.loaded = true;
}

bool createSharedGameState(SharedGameState* gameState, SDL_Window* window)
{
    try
    {
        emplace(gameState);

        Audio.inst = &gameState.audio;
        Audio.inst.initialize();

        Cache.inst = &gameState.cache;
        gameState.cache.load("maps/bloodgulch.map");

        gameState.camera.near = 0.0065f;
        gameState.camera.far  = 1024.0f;
        gameState.camera.fieldOfView = toRadians(50.0f);
        gameState.camera.aspect = 1920.0f / 810.0f;

        gameState.world.setCurrentSbsp();
        gameState.world.initialize();

        gameState.renderer.load();
        gameState.renderer.loadShaders();

        gameState.window = window;

        {
            auto locs = &Cache.inst.scenario.playerStartingLocations;

            GObject.Creation data;

            data.tagIndex = Cache.inst.globals.playerInformation[0].unit.index;
            data.position = locs[0].position;

            data.forward = Vec3(1,0,0);
            data.up      = Vec3(0,0,1);

            gameState.camera.position = data.position;

            gameState.players[0].biped = cast(Biped*)gameState.world.createObject(data);
        }

        foreach(ref scenery ; Cache.inst.scenario.scenery)
        {
            auto palette = &Cache.inst.scenario.sceneryPalette[scenery.type];

            GObject.Creation data;

            data.tagIndex = palette.name.index;
            data.position = scenery.position;
            data.regionPermutation = scenery.desiredPermutation;
            data.velocity = Vec3(0);

            Mat3 mat = Mat3.fromYawPitchRoll(scenery.rotation[2], scenery.rotation[1], scenery.rotation[0]);

            data.forward = mat[0];
            data.up      = mat[2];

            gameState.world.createObject(data);

        }

        foreach(ref vehicle ; Cache.inst.scenario.vehicles)
        {
            auto palette = &Cache.inst.scenario.vehiclePalette[vehicle.type];

            GObject.Creation data = void;

            data.tagIndex = palette.name.index;
            data.position = vehicle.position;
            data.regionPermutation = vehicle.desiredPermutation;
            data.velocity = Vec3(0);
            data.rotationalVelocity = Vec3(0);

            data.forward = Vec3(1, 0, 0);
            data.up      = Vec3(0, 0, 1); // todo better rotation

            data.forward.x = cos(vehicle.rotation[0]) * cos(vehicle.rotation[1]);
            data.forward.y = sin(vehicle.rotation[0]) * cos(vehicle.rotation[1]);

            gameState.world.createObject(data);
        }

        foreach(ref q ; Cache.inst.scenario.netgameEquipment)
        {
            auto ic = Cache.get!TagItemCollection(q.itemCollection);

            GObject.Creation data;

            data.tagIndex = ic.itemPermutations[0].item.index; // todo randomize
            data.position = q.position;
            data.regionPermutation = 0;

            data.forward = Vec3(cos(q.facing), sin(q.facing), 0);
            data.up = Vec3(0,0,1);

            gameState.world.createObject(data);
        }

        glGenTextures(1, &gameState.imguiTexture);
        glBindTexture(GL_TEXTURE_2D, gameState.imguiTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);


    }
    catch(Exception ex)
    {
        writeln(ex);
        stdout.flush();

        return false;
    }

    return true;
}

bool initSharedGameState(SharedGameState* gameState)
{
    enforce(gameState.initializedSizeof == SharedGameState.sizeof);

    Cache.inst = &gameState.cache;
    loadCacheTagPaths();

    gameState.audio.updateCallbacksOnReload();
    Audio.inst = &gameState.audio;

    ImGuiIO* io = igGetIO();

    ubyte* pixels;
    int width, height;

    io.Fonts.GetTexDataAsRGBA32(&pixels, &width, &height, null);

    glBindTexture(GL_TEXTURE_2D, gameState.imguiTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glBindTexture(GL_TEXTURE_2D, 0);

    io.Fonts.SetTexID(cast(ImTextureID)gameState.imguiTexture);

    io.KeyMap[ImGuiKey_Tab]       = SDLK_TAB;
    io.KeyMap[ImGuiKey_LeftArrow] = SDL_SCANCODE_LEFT;
    io.KeyMap[ImGuiKey_RightArrow] = SDL_SCANCODE_RIGHT;
    io.KeyMap[ImGuiKey_UpArrow]   = SDL_SCANCODE_UP;
    io.KeyMap[ImGuiKey_DownArrow] = SDL_SCANCODE_DOWN;
    io.KeyMap[ImGuiKey_PageUp]    = SDL_SCANCODE_PAGEUP;
    io.KeyMap[ImGuiKey_PageDown]  = SDL_SCANCODE_PAGEDOWN;
    io.KeyMap[ImGuiKey_Home]      = SDL_SCANCODE_HOME;
    io.KeyMap[ImGuiKey_End]       = SDL_SCANCODE_END;
    io.KeyMap[ImGuiKey_Delete]    = SDLK_DELETE;
    io.KeyMap[ImGuiKey_Backspace] = SDLK_BACKSPACE;
    io.KeyMap[ImGuiKey_Enter]     = SDLK_RETURN;
    io.KeyMap[ImGuiKey_Escape]    = SDLK_ESCAPE;
    io.KeyMap[ImGuiKey_A] = SDLK_a;
    io.KeyMap[ImGuiKey_C] = SDLK_c;
    io.KeyMap[ImGuiKey_V] = SDLK_v;
    io.KeyMap[ImGuiKey_X] = SDLK_x;
    io.KeyMap[ImGuiKey_Y] = SDLK_y;
    io.KeyMap[ImGuiKey_Z] = SDLK_z;

    io.SetClipboardTextFn = &imguiSetClipboardText;
    io.GetClipboardTextFn = &imguiGetClipboardText;

    SDL_SysWMinfo wmInfo;
    wmInfo.version_ = SDL_VERSION;
    SDL_GetWindowWMInfo(gameState.window, &wmInfo);
    io.ImeWindowHandle = wmInfo.info.win.window;

    frameStopWatch.start();

    return true;
}

template EnumMembersNameArray(T...)
{
    static if(T.length == 1 && is(T[0] == enum))
    {
        alias EnumMembersNameArray = EnumMembersNameArray!(EnumMembers!(T[0]));
    }
    else static if(T.length == 1)
    {
        alias EnumMembersNameArray = AliasSeq!(T[0].stringof);
    }
    else static if (T.length > 0)
    {
        alias EnumMembersNameArray = AliasSeq!(
            T[0].stringof,
            EnumMembersNameArray!(T[1 .. $/2]),
            EnumMembersNameArray!(T[$/2 .. $]));
    }
    else
    {
        alias EnumMembersNameArray = AliasSeq!();
    }
}

void setView(T)(DatumIndex tagIndex, void* f, ref int[] tags, int[] blockIndices = [])
{
    import std.meta   : Alias;
    import std.traits : getUDAs;

    static int selectedIndex; // todo remove hack
    T* fields = cast(T*)f;

    static if(__traits(getAliasThis, T).length)
    {
        alias Type = typeof(__traits(getMember, fields, __traits(getAliasThis, T)[0]));
        setView!Type(tagIndex, &__traits(getMember, fields, __traits(getAliasThis, T)[0]), tags);
    }

    igPushIdPtr(f);
    scope(exit) igPopId();

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

        igPushIdPtr(&field);
        scope(exit) igPopId();

        alias explainUdas = getUDAs!(typeof(*fields).tupleof[i], TagExplanation);

        static if(explainUdas.length)
        {
            static if(explainUdas[0].header.length)      igText(explainUdas[0].header);
            static if(explainUdas[0].explanation.length) igTextWrapped(explainUdas[0].explanation);
        }

        static if(is(Field == enum))
        {
            immutable immutable(char)*[] names = [ EnumMembersNameArray!Field ];

            int currentItem = cast(int)field;
            igCombo(identifier, &currentItem, names.ptr, cast(int)names.length);
            field = cast(Field)currentItem;
        }
        else static if(is(Field == int))
        {
            igInputInt(identifier, &field);
        }
        else static if(is(Field == short))
        {
            igInputShort(identifier, &field);
        }
        else static if(is(Field == float))
        {
            igInputFloat(identifier, &field);
        }
        else static if(is(Field == TagString))
        {
            igInputText(identifier, field.ptr, 32);
        }
        else static if(is(Field == Vec3))
        {
            igInputFloat3(identifier, field[]);
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
            if(igButton("..."))
            {
                selectedIndex = indexNone;
                igOpenPopup("Find Tag");
            }

            igSameLine();

            if(igButton("clear"))
            {
                field.index = DatumIndex.none;
            }

            igSameLine();

            if(igButton("Open"))
            {
                if(field.isValid())
                {
                    tags ~= field.index.i;
                }
            }

            if(field.path)
            {
                import core.stdc.string : strlen;
                igSameLine();
                igInputText(identifier, cast(char*)field.path, strlen(field.path), ImGuiInputTextFlags_ReadOnly);
            }

            igSetNextWindowSize(ImVec2(600, 500), ImGuiSetCond_FirstUseEver);
            if(igBeginPopupModal("Find Tag"))
            {
                if(igButton("Select"))
                {
                    if(selectedIndex != indexNone)
                    {
                        auto meta = &Cache.inst.metaAt(selectedIndex);

                        field.path  = meta.path;
                        field.index = meta.index;
                    }

                    igCloseCurrentPopup();
                }

                igBeginChild("Scroll");
                igColumns(2);

                foreach(int j, ref meta ; Cache.inst.getMetas())
                {
                    igPushIdInt(j);
                    if(igSelectable(meta.path, selectedIndex == j,
                        ImGuiSelectableFlags_SpanAllColumns | ImGuiSelectableFlags_DontClosePopups))
                    {
                        selectedIndex = j;
                    }
                    igNextColumn();
                    igText("tests");
                    igNextColumn();
                    igPopId();
                }
                igEndChild();


                igEndPopup();
            }

        }
        else static if(is(Field == TagData))
        {
            igInputInt(identifier, &field.size);
        }
        else static if(is(Field : TagBlock!BlockType, BlockType))
        {
            if(field.ptr && field.size)
            {
                //igSetNextTreeNodeOpened(true, ImGuiSetCond_FirstUseEver);
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

bool gameStep(SharedGameState* gameState)
{
try
{
    static float mouseWheel;
    static int ticks;

    SDL_Event ev = void;

    while(SDL_PollEvent(&ev))
    switch(ev.type)
    {
    case SDL_QUIT: return false;
    case SDL_MOUSEWHEEL:
    {
        if(ev.wheel.y > 0)
        {
            mouseWheel += 1.0f;
        }

        if(ev.wheel.y < 0)
        {
            mouseWheel -= 1.0f;
        }
        break;
    }
    case SDL_TEXTINPUT:
    {
        igGetIO().AddInputCharactersUTF8(ev.text.text.ptr);
        break;
    }
    case SDL_MOUSEMOTION:
    {
        if(ev.motion.state & SDL_BUTTON_RMASK)
        {
            gameState.camera.updateRotation(ev.motion.xrel / -300.0f, ev.motion.yrel / -300.0f);
        }

        break;
    }
    case SDL_KEYDOWN:
    case SDL_KEYUP:
    {
        auto io = igGetIO();
        int key = ev.key.keysym.sym & ~SDLK_SCANCODE_MASK;
        io.KeysDown[key] = (ev.type == SDL_KEYDOWN);
        io.KeyShift      = ((SDL_GetModState() & KMOD_SHIFT) != 0);
        io.KeyCtrl       = ((SDL_GetModState() & KMOD_CTRL) != 0);
        io.KeyAlt        = ((SDL_GetModState() & KMOD_ALT) != 0);
        io.KeySuper      = ((SDL_GetModState() & KMOD_GUI) != 0);

        break;
    }
    default:
    }



    {

        static StopWatch stopWatch;
        auto io = igGetIO();

        stopWatch.stop();

        io.DisplaySize = Vec2(1920.0f, 810.0f);

        if(stopWatch.peek().hnsecs != 0)
        {
            io.DeltaTime = clamp(stopWatch.peek().msecs / 1000.0f, 0.0001f, 500.0f);
        }

        stopWatch.reset();
        stopWatch.start();

        int mx, my;
        uint mouseMask = SDL_GetMouseState(&mx, &my);

        if(SDL_GetWindowFlags(gameState.window) & SDL_WINDOW_MOUSE_FOCUS)
        {
            io.MousePos = Vec2(cast(float)mx, cast(float)my);
        }
        else
        {
            io.MousePos = Vec2(-1, -1);
        }

        io.MouseDown[0] = (mouseMask & SDL_BUTTON_LMASK) != 0;
        io.MouseDown[1] = (mouseMask & SDL_BUTTON_RMASK) != 0;
        io.MouseDown[2] = (mouseMask & SDL_BUTTON_MMASK) != 0;

        io.MouseWheel = mouseWheel;
        mouseWheel = 0.0f;

        static GObject* selectedObject;

        World.LineResult line = void;
        World.LineOptions options;

        options.structure = true;
        options.objects   = true;
        options.surface.frontFacing = true;

        // TODO(REFACTOR, HARDCODE) remove hardcoded window size
        Vec3 start, end;
        AliasSeq!(start, end) = gameState.camera.calculateRayFromMouse(Vec2(mx, my), Vec2(1920, 810));

        if(io.MouseDown[0]
            && !igIsMouseHoveringAnyWindow()
            && gameState.world.collideLine(null, start, end - start, options, line))
        {
            if(line.collisionType == World.CollisionType.object)
            {
                selectedObject = line.model.object;
            }
        }

        // ImGui New Frame Start ////////////////////////////////////////////////////////////////////////////////////////////

        igNewFrame();
        static int[] openedTags;

        igBegin("Main Window");
        igValueInt("Ticks", ticks);


        foreach(tagId ; [EnumMembers!TagId])
        if(auto group = tagId in cacheTagPaths)
        {
            import std.conv : to;
            const(char)[] name = to!string(tagId) ~ "\0";

            if(igTreeNode(name.ptr))
            {
                foreach(index ; *group)
                {
                    if(igSelectable(Cache.inst.metaAt(index).path))
                    {
                        import std.algorithm.searching : canFind;

                        if(!canFind(openedTags, index))
                        {
                            openedTags ~= index;
                        }
                        else
                        {
                            igSetWindowFocus2(Cache.inst.metaAt(index).path);
                        }
                    }
                }

                igTreePop();
            }
        }

        igEnd();

        foreach(int j, ref i ; openedTags)
        {
            auto meta = &Cache.inst.metaAt(i);
            bool opened = true;

            const(char)[] name = fromStringz(meta.path) ~ "##" ~ to!string(i) ~ "\0";

            igSetNextWindowPosCenter(ImGuiSetCond_FirstUseEver);
            if(igBegin2(name.ptr, &opened, ImVec2(600, 500), -1.0f, ImGuiWindowFlags_NoSavedSettings))
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

            igSetNextWindowPosCenter(ImGuiSetCond_FirstUseEver);
            igSetNextWindowSize(ImVec2(600, 500), ImGuiSetCond_FirstUseEver);

            if(igBegin("Selected Object Info", &opened))
            {
                igPushIdPtr(selectedObject);
                selectedObject.byTypeDebugUI();
                igPopId();
            }
            igEnd();


            if(!opened)
            {
                selectedObject = null;
            }

        }

        igShowMetricsWindow();

        gameState.renderer.doUi();

        igRender();
    }


    Duration currentTime = dur!"hnsecs"(frameStopWatch.peek().hnsecs);
    accumulator += min(dur!"msecs"(200), currentTime - lastTime);

    lastTime = currentTime;

    enum frameDelta = dur!"seconds"(1) / gameFramesPerSecond;

    StopWatch stopWatch;
    stopWatch.start();

    for( ; accumulator >= frameDelta; accumulator -= frameDelta)
    {
        ticks += 1;

        const(ubyte)* state = SDL_GetKeyboardState(null);

        Vec2 f, s;

        f = gameState.camera.forward.xy;
        f.normalize();
        s = -cross(gameState.camera.up, gameState.camera.forward).xy;
        s.normalize();

        Vec3 vel = 0;

        static bool fast = true;
        static Player.LocalControl[2] playerLocalControls;

        if(toggleKeyPress!SDL_SCANCODE_LSHIFT)
        {
            fast = !fast;
        }

        if(SDL_GetMouseState(null, null) & SDL_BUTTON_MMASK)
        {
            float speed = fast ? 0.9f : 0.1f;

            if(state[SDL_SCANCODE_W]) vel += Vec3(f * speed, 0);
            if(state[SDL_SCANCODE_S]) vel -= Vec3(f * speed, 0);
            if(state[SDL_SCANCODE_D]) vel += Vec3(s * speed, 0);
            if(state[SDL_SCANCODE_A]) vel -= Vec3(s * speed, 0);
            if(state[SDL_SCANCODE_R]) vel.z += speed;
            if(state[SDL_SCANCODE_F]) vel.z -= speed;

            gameState.camera.position += vel;
        }
        else if(gameState.players[0].biped)
        {
            auto player = &gameState.players[0];
            auto biped  = gameState.players[0].biped;

            static int swapWeaponsTimer;

            if(state[SDL_SCANCODE_Q])
            {
                swapWeaponsTimer = clampedIncrement(swapWeaponsTimer);
            }
            else
            {
                swapWeaponsTimer = 0;
            }

            if(playerLocalControls[0].weaponIndex == indexNone || biped.weapons[playerLocalControls[0].weaponIndex] is null)
            {
                playerLocalControls[0].weaponIndex = biped.nextWeaponIndex;
            }

            if(swapWeaponsTimer == 1 || playerLocalControls[0].weaponIndex == indexNone)
            {
                playerLocalControls[0].weaponIndex = biped.findUsableWeaponIndex(playerLocalControls[0].weaponIndex);
            }

            Unit.Control control;

            control.jump       =  state[SDL_SCANCODE_SPACE] != 0;
            control.crouch     =  state[SDL_SCANCODE_LSHIFT] != 0;
            control.action     =  state[SDL_SCANCODE_E] != 0;
            control.melee      =  state[SDL_SCANCODE_F] != 0;
            control.reload     =  state[SDL_SCANCODE_R] != 0;
            control.primaryTrigger = (SDL_GetMouseState(null, null) & SDL_BUTTON_LMASK) != 0;
            control.swapWeapon =  state[SDL_SCANCODE_E] != 0; // todo need weapon ticks from globals tag

            int forward = 0;
            int side = 0;

            if(state[SDL_SCANCODE_W]) forward += 1;
            if(state[SDL_SCANCODE_S]) forward -= 1;
            if(state[SDL_SCANCODE_D]) side -= 1;
            if(state[SDL_SCANCODE_A]) side += 1;

            Vec2 throttle = Vec2(forward, side);

            normalize(throttle);

            // todo check unit controllable flag

            if(control.action)
            {
                if(player.biped.parent is null)
                {
                    if(!player.processVehicleAction())
                    {
                        control.reload = true;
                    }
                }
            }

            if(control.swapWeapon)
            {
                if(!player.weaponSwapHandled)
                {
                    player.weaponSwapHandled = player.processWeaponAction();
                }
            }
            else
            {
                player.weaponSwapHandled = false;
            }

            Vec3 dir;

            Vec2 playerAngleInput = gameState.camera.angle;

            dir.x = cos(playerAngleInput.x) * cos(playerAngleInput.y);
            dir.y = sin(playerAngleInput.x) * cos(playerAngleInput.y);
            dir.z = sin(playerAngleInput.y);

            player.biped.control = control;
            player.biped.throttle = Vec3(throttle, 0);
            player.biped.desiredForwardDirection = dir;
            player.biped.aim.desired = dir;
            player.biped.nextWeaponIndex = playerLocalControls[0].weaponIndex;

        }

        gameState.audio.update(); // TODO REFACTOR
        gameState.world.updateLogicEffects(1.0f / gameFramesPerSecond);
        gameState.world.updateLogicParticles(1.0f / gameFramesPerSecond); // TODO(REFACTOR) ordering is wrong

        foreach(ref o ; gameState.world.objects)
        {
            GObject* object = o.ptr;

            if(object.headerFlags.active && !object.headerFlags.newlyCreated)
            {
                object.doLogicUpdate();
            }
        }

        foreach(ref o ; gameState.world.objects)
        {
            GObject* object = o.ptr;

            if(object.headerFlags.newlyCreated)
            {
                object.headerFlags.newlyCreated = false;

                object.doLogicUpdate();
            }
        }

        gameState.players[0].action.type = Player.Action.Type.none;

        if(auto biped = gameState.players[0].biped)
        {
            GObject*[16] objects;

            GObjectTypeMask mask = GObjectTypeMask(
                TagEnums.ObjectType.vehicle,
                TagEnums.ObjectType.weapon,
                TagEnums.ObjectType.equipment);

            int num = gameState.world.calculateNearbyObjects(World.ObjectSearchType.bothCollideableAndNoncollideable,
                            mask, gameState.players[0].biped.bound, objects.ptr, objects.length);

            foreach(object ; objects[0 .. num])
            {
                switch(object.type)
                {
                case TagEnums.ObjectType.vehicle:
                {
                    gameState.players[0].requestVehicleAction(cast(Vehicle*)object);

                    break;
                }
                case TagEnums.ObjectType.weapon:
                case TagEnums.ObjectType.equipment:
                {
                    gameState.players[0].handleItemInProximity(cast(Item*)object);

                    break;
                }
                default:
                }
            }
        }

        gameState.audio.updateObjectLoopingSounds();

        if(dur!"hnsecs"(stopWatch.peek().hnsecs) > frameDelta)
        {
            accumulator = dur!"seconds"(0);
            break;
        }
    }


    gameState.camera.updateMatrices();
    gameState.renderer.render(gameState.world, gameState.camera);

    SDL_GL_SwapWindow(gameState.window);

    return true;
}
catch(Exception ex)
{
    writeln(ex);
    stdout.flush();

    return false;
}
}