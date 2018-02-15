
module Game.GameInterface;

import SDL2 : SDL_Window;

struct GameInterface
{
    bool loaded;
    uint sharedGameStateSizeof;

    bool function(void*) gameStep;
    bool function(void*) initSharedGameState;
    bool function(void*, SDL_Window*) createSharedGameState;
}
