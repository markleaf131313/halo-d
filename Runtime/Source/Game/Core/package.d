

module Game.Core;

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

    alias diff_t = ptrdiff_t;

    // todo find better place for these global, (eventually to be runtime) variables
    enum gameFramesPerSecond = 30; // todo make runtime value, eventually
    enum gameGravity = 0.0035651791f; // todo make runtime value
}