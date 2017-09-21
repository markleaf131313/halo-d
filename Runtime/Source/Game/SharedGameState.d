
module Game.SharedGameState;

import SDL2;

import Game.Audio;
import Game.Cache;
import Game.Render;
import Game.Script;
import Game.World;
import Game.World.Player;

struct SharedGameState
{
    @disable this(this);

    uint initializedSizeof = this.sizeof;

    SDL_Window* window;
    SDL_GLContext context;

    uint imguiTexture;

    Camera camera;
    Player[16] players; // TODO rename to "localPlayers" ?

    Cache cache;
    Audio audio;
    World world;
    Renderer renderer;
    HsRuntime hsRuntime;
}
