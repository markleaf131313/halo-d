

import OpenAL;
import OpenGL;
import OpenGL.Loader;
import SDL2;
import Vorbis;

import Game.GameInterface;

import std.stdio;
import std.file;
import std.path;
import std.datetime;


struct LibraryState
{
    void* library;
    SysTime modificationTime;
    GameInterface gameInterface = void;
}

__gshared LibraryState libraryState;

immutable string libraryPath;
immutable string libraryPathLoaded;

shared static this()
{
    version(Windows)
    {
        libraryPath       = dirName(thisExePath()) ~ "/runtime.dll\0";
        libraryPathLoaded = dirName(thisExePath()) ~ "/runtime_loaded.dll\0";
    }
    else version(Posix)
    {
        libraryPath       = dirName(thisExePath()) ~ "/libruntime.so\0";
        libraryPathLoaded = dirName(thisExePath()) ~ "/libruntime_loaded.so\0";
    }
    else
    {
        static assert(0);
    }

    libraryState.gameInterface.loaded = false;
}

bool checkNeedsReload()
{
    SysTime time, ignoreme;
    getTimes(libraryPath, ignoreme, time);

    if(libraryState.library == null)
    {
        libraryState.modificationTime = time;
        return doReloadLibrary();
    }
    else if(time != libraryState.modificationTime)
    {
        libraryState.modificationTime = time;
        return doReloadLibrary();
    }

    return false;
}

bool doReloadLibrary()
{
    import core.runtime : Runtime;

    version(Windows)
    {
        import core.sys.windows.windows;
        import core.sys.windows.dll;
    }
    else version(Posix)
    {
        import core.sys.posix.dlfcn;
    }
    else
    {
        static assert(0);
    }

    with(libraryState)
    {
        if(library !is null)
        {
            Runtime.unloadLibrary(library);

            library = null;
            gameInterface.loaded = false;
        }

        try
        {
            copy(libraryPath, libraryPathLoaded);
        }
        catch(Exception ex)
        {
            writeln(ex);
            stdout.flush();
            return false;
        }

        library = Runtime.loadLibrary(libraryPathLoaded);

        if(library is null)
        {
            writeln("failed to load lib");
            return false;
        }

        extern(C) void function(GameInterface*, uint) grabInterface;

        version(Windows)    grabInterface = cast(typeof(grabInterface))GetProcAddress(library, "grabInterface");
        else version(Posix) grabInterface = cast(typeof(grabInterface))dlsym(library, "grabInterface");
        else static assert(0);

        if(grabInterface !is null)
        {
            grabInterface(&gameInterface, GameInterface.sizeof);
            return true;
        }

        return false;
    }
}

extern(System) nothrow @nogc
static void openglDebugCallback(
    GLenum source,
    GLenum type,
    GLuint id,
    GLenum severity,
    GLsizei length,
    const(GLchar*) message,
    void* userParam)
{
    import core.stdc.stdio : printf, stdout;

    static const(char*) to(T : char*)(GLenum value)
    {
        switch(value)
        {
        // sources
        case GL_DEBUG_SOURCE_API: return "API";
        case GL_DEBUG_SOURCE_WINDOW_SYSTEM: return "Window System";
        case GL_DEBUG_SOURCE_SHADER_COMPILER: return "Shader Compiler";
        case GL_DEBUG_SOURCE_THIRD_PARTY: return "Third Party";
        case GL_DEBUG_SOURCE_APPLICATION: return "Application";
        case GL_DEBUG_SOURCE_OTHER: return "Other";

        // error types
        case GL_DEBUG_TYPE_ERROR: return "Error";
        case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: return "Deprecated Behaviour";
        case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR: return "Undefined Behaviour";
        case GL_DEBUG_TYPE_PORTABILITY: return "Portability";
        case GL_DEBUG_TYPE_PERFORMANCE: return "Performance";
        case GL_DEBUG_TYPE_MARKER: return "Marker";
        case GL_DEBUG_TYPE_PUSH_GROUP: return "Push Group";
        case GL_DEBUG_TYPE_POP_GROUP: return "Pop Group";
        case GL_DEBUG_TYPE_OTHER: return "Other";

            // severity markers
        case GL_DEBUG_SEVERITY_HIGH: return "High";
        case GL_DEBUG_SEVERITY_MEDIUM: return "Medium";
        case GL_DEBUG_SEVERITY_LOW: return "Low";
        case GL_DEBUG_SEVERITY_NOTIFICATION: return "Notification";

        default: return "(undefined)";
        }
    }

    printf("Message: %s \nSource: %s \nType: %s \nID: %d\nSeverity: %s\n\n",
        message, to!(char*)(source), to!(char*)(type), id, to!(char*)(severity));

    fflush(stdout);

    if(severity == GL_DEBUG_SEVERITY_HIGH)
    {
        printf("Aborting...\n");
        assert(0);
    }

}

void openglEnableDebugging()
{
    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);

    glDebugMessageCallback(&openglDebugCallback, null);

    glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, true);
    glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DEBUG_SEVERITY_NOTIFICATION, 0, null, false);

}

void main(string[] args)
{
    try
    {
        import std.exception : enforce;
        import core.stdc.stdlib : malloc;

        // Video ////////////////////////////////////////////////////////////////////////////////////////////////////////////

        enforce(SDL_Init(SDL_INIT_VIDEO) == 0);

        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 5);

        SDL_Window* window = SDL_CreateWindow(null, 100, 100, 1920, 810, SDL_WINDOW_OPENGL);
        SDL_GLContext context = SDL_GL_CreateContext(window);

        enforce(gladLoadGL(x => SDL_GL_GetProcAddress(x)));
        openglEnableDebugging();

        SDL_GL_SetSwapInterval(0);

        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glFrontFace(GL_CW);
        glCullFace(GL_BACK);

        // Audio ////////////////////////////////////////////////////////////////////////////////////////////////////////////

        ALCdevice*  alDevice  = alcOpenDevice(null);
        ALCcontext* alContext = alcCreateContext(alDevice, null);

        alcMakeContextCurrent(alContext);


        checkNeedsReload();

        assert(libraryState.gameInterface.loaded);

        void* sharedGameState = malloc(libraryState.gameInterface.sharedGameStateSizeof);
        if(!libraryState.gameInterface.createSharedGameState(sharedGameState, window))
        {
            return;
        }

        libraryState.gameInterface.initSharedGameState(sharedGameState);

        while(true) with(libraryState.gameInterface)
        {
            if(checkNeedsReload())
            {
                initSharedGameState(sharedGameState);
            }

            if(loaded)
            {
                if(!gameStep(sharedGameState))
                {
                    return;
                }

                stdout.flush();
            }
            else
            {
                SDL_Event ev = void;

                while(SDL_PollEvent(&ev))
                {
                    switch(ev.type)
                    {
                    case SDL_QUIT: return;
                    default:
                    }
                }

                SDL_GL_SwapWindow(window);
            }
        }

    }
    catch(Exception ex)
    {
        writeln(ex);
        stdout.flush();
    }

}
