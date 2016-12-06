

module Game.Core;

import std.datetime : Duration, msecs;

public
{
    import Game.Core.Containers;
    import Game.Core.Math;

    import Game.Core.Algorithm;
    import Game.Core.Io;
    import Game.Core.Memory;
    import Game.Core.Meta;
    import Game.Core.Misc;
    import Game.Core.Random;
    import Game.Core.String;
    import Game.Core.Traits;

    alias diff_t = ptrdiff_t;

    // todo find better place for these global, (eventually to be runtime) variables
    enum gameFramesPerSecond = 30; // todo make runtime value, eventually
    enum Duration gameFrameTimeMsecs = 33.msecs;
    enum gameGravity = 0.0035651791f; // todo make runtime value
}