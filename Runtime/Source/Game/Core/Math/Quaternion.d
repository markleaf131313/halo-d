
module Game.Core.Math.Quaternion;

import std.math : sin, acos;


import Game.Core.Math.Vector;

alias Quat = Quaternion!float;

enum isQuaternion(Q) = is(Q : Quaternion!U, U);

struct Quaternion(_T)
{
    alias Type = _T;

    union
    {
        struct
        {
            Type x;
            Type y;
            Type z;
            Type w;
        }

        private Type[4]      values;
        private Vector4!Type vec;
    }


    this(Type x, Type y, Type z, Type w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    private this()(auto ref Vector4!Type v)
    {
        vec = v;
    }

    ref Quaternion opOpAssign(string op : "*")(auto ref const(Quaternion) q)
    {
        this = this * q;
        return this;
    }

    Quaternion opBinary(string op : "*")(auto ref const(Quaternion) q)
    {
        return Quaternion(
            w * q.x + x * q.w + y * q.z - z * q.y,
            w * q.y + y * q.w + z * q.x - x * q.z,
            w * q.z + z * q.w + x * q.y - y * q.x,
            w * q.w - x * q.x - y * q.y - z * q.z);
    }

}


Quaternion!T conjugate(T)(auto ref const(Quaternion!T) quat)
{
    return Quaternion!T(-quat.x, -quat.y, -quat.z, quat.w);
}

Quaternion!T mix(T)(auto ref const(Quaternion!T) x, auto ref const(Quaternion!T) y, T a)
{
    Quaternion!T z = y;
    T cosTheta = dot(x.vec, y.vec);

    if(cosTheta > T(1) - T.epsilon)
    {
        return Quaternion!T(Game.Core.Math.Vector.mix(x.vec, z.vec, a));
    }
    else
    {
        T angle = acos(cosTheta);
        return Quaternion!T((sin((T(1) - a) * angle) * x.vec + sin(a * angle) * z.vec) / sin(angle));
    }
}

Quaternion!T slerp(T)(auto ref const(Quaternion!T) x, auto ref const(Quaternion!T) y, T a)
{
    Quaternion!T z = y;
    T cosTheta = dot(x.vec, y.vec);

    if(cosTheta < T(0))
    {
        z.vec    = -y.vec;
        cosTheta = -cosTheta;
    }

    if(cosTheta > T(1) - T.epsilon)
    {
        return Quaternion!T(Game.Core.Math.Vector.mix(x.vec, z.vec, a));
    }
    else
    {
        T angle = acos(cosTheta);
        return Quaternion!T((sin((T(1) - a) * angle) * x.vec + sin(a * angle) * z.vec) / sin(angle));
    }
}

T normalize(T)(ref Quaternion!T quat)
{
    return Game.Core.Math.Vector.normalize(quat.vec);
}