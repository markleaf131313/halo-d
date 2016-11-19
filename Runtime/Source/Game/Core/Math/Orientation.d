
module Game.Core.Math.Orientation;

import Game.Core.Math.Algorithms;
import Game.Core.Math.Vector;
import Game.Core.Math.Quaternion;


@nogc nothrow pure:


struct Orientation
{
    float scale;
    Quat  rotation;
    Vec3  position;
}

Orientation mix()(auto ref const(Orientation) a, auto ref const(Orientation) b, float alpha)
{
    return Orientation(
        Game.Core.Math.Algorithms.mix(a.scale, b.scale, alpha),
        slerp(a.rotation, b.rotation, alpha),
        Game.Core.Math.Vector.mix(a.position, b.position, alpha)
    );
}