module Runtime_;

import std.conv      : emplace, to;
import std.datetime  : Duration, dur;
import std.datetime.stopwatch : StopWatch;
import std.exception : enforce;
import std.meta;
import std.stdio;
import std.string    : fromStringz;
import std.traits    : EnumMembers;

import SDL2;
import ImGuiC;

import Game.Ai;
import Game.Audio;
import Game.Cache;
import Game.Core;
import Game.DebugUi;
import Game.GameInterface;
import Game.Profiler;
import Game.SharedGameState;
import Game.Tags;
import Game.World;
import Game.World.Player;


version(Windows)
{
    import core.sys.windows.dll : SimpleDllMain;
    mixin SimpleDllMain;
}

version(Android)
{
    void main()
    {
    }

    extern(C) void rt_init();

    extern(C) int SDL_main(int argc, char** argv)
    {
        import Game.SharedGameState;
        import OpenAL;
        import core.stdc.stdlib : malloc;
        import std.file : chdir;
        import std.string : toStringz;

        SDL_LogSetAllPriority(SDL_LOG_PRIORITY_VERBOSE);

        rt_init();

        chdir(SDL_AndroidGetExternalStoragePath().fromStringz);

        // Video ////////////////////////////////////////////////////////////////////////////////////////////////////////////
        SDL_Init(SDL_INIT_VIDEO);
        SDL_Window* window = SDL_CreateWindow(null, 0, 0, 1920, 1080, SDL_WINDOW_VULKAN | SDL_WINDOW_FULLSCREEN_DESKTOP);

        // Audio ////////////////////////////////////////////////////////////////////////////////////////////////////////////

        ALCdevice*  alDevice  = alcOpenDevice(null);
        ALCcontext* alContext = alcCreateContext(alDevice, null);

        alcMakeContextCurrent(alContext);

        SharedGameState* sharedGameState = cast(SharedGameState*)malloc(SharedGameState.sizeof);
        if(!createSharedGameState(sharedGameState, window))
        {
            return 1;
        }

        initSharedGameState(sharedGameState);

        try
        {
            while(true)
            {
                if(!gameStep(sharedGameState))
                {
                    return 0;
                }

                stdout.flush();
            }
        }
        catch(Throwable t)
        {
            SDL_Log(t.toString().toStringz());
        }

        return 0;
    }
}

__gshared DebugUi debugUi; // todo temp debugging
__gshared StopWatch frameStopWatch;
__gshared Duration lastTime;
__gshared Duration accumulator;

extern(C++) void imguiSetClipboardText(void* userData, const(char)* text)
{
    SDL_SetClipboardText(text);
}

extern(C++) const(char)* imguiGetClipboardText(void* userData)
{
    return SDL_GetClipboardText();
}

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

        igCreateContext();
        gameState.window = window;

        Audio.inst = &gameState.audio;
        Audio.inst.initialize(&gameState.world);

        Cache.inst = &gameState.cache;
        gameState.cache.load("maps/bloodgulch.map");

        gameState.world.setCurrentSbsp();
        gameState.world.initialize();

        gameState.hsRuntime.initialize();
        gameState.hsRuntime.initializeScenario(gameState.cache.scenario);

        gameState.renderer.initialize(window, gameState.world.getCurrentSbsp);

        gameState.camera.near = 0.0065f;
        gameState.camera.far  = 1024.0f;
        gameState.camera.fieldOfView = toRadians(50.0f);
        gameState.camera.aspect = float(gameState.renderer.windowWidth) / float(gameState.renderer.windowHeight);

        {
            auto locs = &Cache.inst.scenario.playerStartingLocations;

            GObject.Creation data;

            data.tagIndex = Cache.inst.globals.playerInformation[0].unit.index;
            data.position = locs[0].position;

            data.forward = Vec3(1,0,0);
            data.up      = Vec3(0,0,1);

            gameState.camera.position = data.position;

            gameState.players[0].biped = cast(Biped*)gameState.world.createObject(data);

            data.position.x -= 0.5f;
            gameState.world.createObject(data);
        }

        foreach(ref scenery ; Cache.inst.scenario.scenery)
        {
            if(scenery.type == indexNone)
            {
                continue;
            }

            auto palette = &Cache.inst.scenario.sceneryPalette[scenery.type];

            GObject.Creation data;

            data.tagIndex = palette.name.index;
            data.position = scenery.position;
            data.regionPermutation = scenery.desiredPermutation;

            Mat3 mat = Mat3.fromEulerXYZ(scenery.rotation);

            data.forward = mat[0];
            data.up      = mat[2];

            gameState.world.createObject(data);

        }

        foreach(ref vehicle ; Cache.inst.scenario.vehicles)
        {
            auto palette = &Cache.inst.scenario.vehiclePalette[vehicle.type];

            GObject.Creation data;

            data.tagIndex = palette.name.index;
            data.position = vehicle.position;
            data.regionPermutation = vehicle.desiredPermutation;

            Mat3 mat = Mat3.fromEulerXYZ(vehicle.rotation);

            data.forward = mat[0];
            data.up      = mat[2];

            gameState.world.createObject(data);
        }

        foreach(ref q ; Cache.inst.scenario.netgameEquipment)
        {
            auto ic = Cache.get!TagItemCollection(q.itemCollection);

            GObject.Creation data;

            data.tagIndex = ic.itemPermutations[0].item.index; // TODO randomize
            data.position = q.position;
            data.regionPermutation = 0;

            data.forward = Vec3(cos(q.facing), sin(q.facing), 0);
            data.up = Vec3(0,0,1);

            gameState.world.createObject(data);
        }

        version(none)
        {
            int squadCount;
            int platoonCount;

            foreach(ref tagEncounter ; Cache.inst.scenario.encounters)
            {
                DatumIndex index = gameState.ai.encounters.add();
                Encounter* encounter = &gameState.ai.encounters[index];

                encounter.squadBegin = squadCount;
                encounter.squadEnd   = squadCount += tagEncounter.squads.size;

                encounter.platoonBegin = platoonCount;
                encounter.platoonEnd   = platoonCount += tagEncounter.platoons.size;

                foreach(int i, ref tagSquad ; tagEncounter.squads)
                {
                    Squad* squad = &gameState.ai.squads[encounter.squadBegin + i];

                    if(tagSquad.flags.noTimerDelayForever)
                    {
                        squad.delayTicks = 999;
                    }
                    else
                    {
                        squad.delayTicks = cast(typeof(squad.delayTicks))(tagSquad.squadDelayTime * gameFramesPerSecond);
                    }

                    if(tagSquad.respawnMinActors > 0 || tagSquad.respawnMaxActors > 0)
                    {
                        if(tagSquad.respawnTotal != 0) squad.respawnTotal = tagSquad.respawnTotal;
                        else                           squad.respawnTotal = 999;
                    }
                }

                foreach(int i, ref tagPlatoon ; tagEncounter.platoons)
                {
                    Platoon* platoon = &gameState.ai.platoons[encounter.platoonBegin + i];
                    platoon.startInDefendingState = tagPlatoon.flags.startInDefendingState;
                }
            }

            foreach(int i, ref encounter ; gameState.ai.encounters)
            {
                auto tagEncounter = &Cache.inst.scenario.encounters[i];

                if(tagEncounter.flags.notInitiallyCreated)
                {
                    continue;
                }

                assert(0);
            }
        }

        // TODO imgui initialization

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

    debugUi.gameState = gameState;
    debugUi.loadCacheTagPaths();

    gameState.audio.updateCallbacksOnReload();
    Audio.inst = &gameState.audio;

    ImGuiIO* io = igGetIO();

    float dpi;
    SDL_GetDisplayDPI(SDL_GetWindowDisplayIndex(gameState.window), &dpi, null, null);

    // TODO need to update to SDL 2.0.8 for GetDisplayDPI to work on Android
    version(Android)
    {
        io.FontGlobalScale = 2.0f;
    }
    else
    {
        if(dpi > 100.0f)
        {
            io.FontGlobalScale = 2.0f;
        }
    }

    ubyte* pixels;
    int width, height;

    io.Fonts.GetTexDataAsRGBA32(&pixels, &width, &height, null);

    // TODO IMGUI initialization

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
    version(Windows) io.ImeWindowHandle = wmInfo.info.win.window;

    frameStopWatch.start();

    return true;
}


bool gameStep(SharedGameState* gameState)
{
try
{
    mixin ProfilerObject.ScopedFrame;

    struct FingerAnalog
    {
        long fingerIndex = indexNone;
        Vec2 center;
        Vec2 delta = Vec2(0.0f);
    }

    static FingerAnalog movementFinger;
    static FingerAnalog rotationFinger;

    static float mouseWheel;
    static int ticks;

    Random_shared_static_this();

    SDL_Event ev = void;

    while(SDL_PollEvent(&ev))
    switch(ev.type)
    {
    case SDL_RENDER_DEVICE_RESET:
        gameState.renderer.resetDeviceContextNoCleanup();
        gameState.renderer.initialize(gameState.window, gameState.world.getCurrentSbsp());
        break;
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
    case SDL_FINGERDOWN:
    {
        if(igIsWindowHovered(ImGuiHoveredFlags_AnyWindow))
        {
            break;
        }

        if(ev.tfinger.x < 0.25f)
        {
            if(movementFinger.fingerIndex == indexNone)
            {
                movementFinger.fingerIndex = ev.tfinger.fingerId;
                movementFinger.center = Vec2(ev.tfinger.y, ev.tfinger.x);
                movementFinger.delta = Vec2(0.0f);
            }
        }
        else
        {
            if(rotationFinger.fingerIndex == indexNone)
            {
                rotationFinger.fingerIndex = ev.tfinger.fingerId;
                rotationFinger.center = Vec2(ev.tfinger.x, ev.tfinger.y);
                rotationFinger.delta = Vec2(0.0f);
            }
        }
        break;
    }
    case SDL_FINGERMOTION:
    {
        if(ev.tfinger.fingerId == rotationFinger.fingerIndex)
        {
            gameState.camera.updateRotation(ev.tfinger.dx * 4.0f, ev.tfinger.dy * 2.0f);
        }
        if(ev.tfinger.fingerId == movementFinger.fingerIndex)
        {
            movementFinger.delta = Vec2(ev.tfinger.y, ev.tfinger.x) - movementFinger.center;
        }
        break;
    }
    case SDL_FINGERUP:
    {
        if(ev.tfinger.fingerId == rotationFinger.fingerIndex) rotationFinger.fingerIndex = indexNone;
        if(ev.tfinger.fingerId == movementFinger.fingerIndex) movementFinger.fingerIndex = indexNone;
        break;
    }
    default:
    }

    {
        static StopWatch stopWatch;
        auto io = igGetIO();

        if(stopWatch.running)
            stopWatch.stop();

        io.DisplaySize = Vec2(1920.0f, 1080.0f); // TODO unhardcode

        if(stopWatch.peek().total!"hnsecs" != 0)
        {
            io.DeltaTime = clamp(stopWatch.peek().total!"msecs" / 1000.0f, 0.0001f, 500.0f);
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

        World.LineResult line = void;
        World.LineOptions options;

        options.structure = true;
        options.objects   = true;
        options.surface.frontFacing = true;

        // TODO(REFACTOR, HARDCODE) remove hardcoded window size
        Vec3 start, end;
        AliasSeq!(start, end) = gameState.camera.calculateRayFromMouse(Vec2(mx, my), Vec2(1920, 810));

        if(io.MouseDown[0]
            && !igIsWindowHovered(ImGuiHoveredFlags_AnyWindow)
            && gameState.world.collideLine(null, start, end - start, options, line))
        {
            if(line.collisionType == World.CollisionType.object)
            {
                debugUi.selectedObject = line.model.object;
            }
        }

        igNewFrame();

        debugUi.doUi();
        gameState.renderer.doUi();

        igRender();
    }


    Duration currentTime = frameStopWatch.peek();
    accumulator += min(dur!"msecs"(200), currentTime - lastTime);

    lastTime = currentTime;

    enum frameDelta = dur!"seconds"(1) / gameFramesPerSecond;

    StopWatch stopWatch;
    stopWatch.start();

    for( ; accumulator >= frameDelta; accumulator -= frameDelta)
    {
        mixin ProfilerObject.ScopedMarker;

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

        if(movementFinger.fingerIndex != indexNone)
        {
            gameState.camera.position += gameState.camera.rotation * -Vec3(movementFinger.delta * 1.5f, 0.0f);
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
            control.primaryTrigger   = (SDL_GetMouseState(null, null) & SDL_BUTTON_LMASK) != 0;
            control.secondaryTrigger = (SDL_GetMouseState(null, null) & SDL_BUTTON_RMASK) != 0;
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

        gameState.audio.update(gameState.camera.position); // TODO REFACTOR
        gameState.world.updateLogicEffects(1.0f / gameFramesPerSecond);
        gameState.world.updateLogicParticles(1.0f / gameFramesPerSecond); // TODO(REFACTOR) ordering is wrong

        foreach(ref object ; gameState.world.objects)
        {
            if(object.headerFlags.active && !object.headerFlags.newlyCreated)
            {
                object.updateLogic();
            }
        }

        foreach(ref object ; gameState.world.objects)
        {
            if(object.headerFlags.newlyCreated)
            {
                object.headerFlags.newlyCreated = false;

                object.updateLogic();
            }
        }

        foreach(ref object ; gameState.world.objects)
        {
            if(object.headerFlags.requestedDeletion)
            {
                // TODO move to separate function in World

                object.disconnectFromWorld();
                gameState.world.objects.remove(object.selfIndex);

                object.byTypeDestruct();
                free(&object); // TODO validate no memory leaks
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

            int num = gameState.world.calculateNearbyObjects(World.ObjectSearchType.all, mask,
                biped.location, biped.bound, objects.ptr, objects.length);

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

        if(stopWatch.peek() > frameDelta)
        {
            accumulator = dur!"seconds"(0);
            break;
        }
    }


    gameState.camera.updateMatrices();
    gameState.renderer.render(gameState.world, gameState.camera);

    return true;
}
catch(Exception ex)
{
    writeln(ex);
    stdout.flush();

    return false;
}
}
