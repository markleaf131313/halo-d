
module Game.Core.Math.Transform;

import Game.Core.Math.Matrix;
import Game.Core.Math.Orientation;
import Game.Core.Math.Plane;
import Game.Core.Math.Quaternion;
import Game.Core.Math.Vector;


@nogc nothrow pure:


struct Transform
{
@nogc nothrow pure:

    union
    {
        struct
        {
            float scale     = 1.0f;
            Vec3  forward   = Vec3(1, 0, 0);
            Vec3  left      = Vec3(0, 1, 0);
            Vec3  up        = Vec3(0, 0, 1);
            Vec3  position  = Vec3(0);
        }
        struct
        {
            private float  mat4x3Scale;
            Mat4x3 mat4x3;
        }
        struct
        {
            private float mat3Scale;
            Mat3  mat3;
            private Vec3 mat3Position;
        }
    }

    this()(float scale, auto ref const(Mat3) mat3, auto ref const(Vec3) position)
    {
        this.scale    = scale;
        this.mat3     = mat3;
        this.position = position;
    }

    this()(auto ref const(Mat3) mat3, auto ref const(Vec3) position)
    {
        this.scale    = 1.0f;
        this.mat3     = mat3;
        this.position = position;
    }

    this()(auto ref const(Quat) quat, auto ref const(Vec3) position)
    {
        this.scale    = 1.0f;
        this.mat3     = Mat3(quat);
        this.position = position;
    }

    this()(auto ref const(Orientation) orientation)
    {
        scale    = orientation.scale;
        mat3     = Mat3(orientation.rotation);
        position = orientation.position;
    }

    Mat4x3 toMat4x3WithScale() const
    {
        Mat4x3 result = void;

        result[0] = mat3[0] * scale;
        result[1] = mat3[1] * scale;
        result[2] = mat3[2] * scale;
        result[3] = position;

        return result;
    }

    Mat4 toMat4() const
    {
        Mat4 result = void;

        result[0] = Vec4(mat3[0] * scale, 0.0f);
        result[1] = Vec4(mat3[1] * scale, 0.0f);
        result[2] = Vec4(mat3[2] * scale, 0.0f);
        result[3] = Vec4(position,        1.0f);

        return result;
    }

    Transform opBinary(string op : "*")(auto ref const(Transform) transform) const
    {
        return Transform(scale * transform.scale, mat3 * transform.mat3, this * transform.position);
    }

    Vec3 opBinary(string op : "*")(auto ref const(Vec3) vec) const
    {
        return mat4x3 * (vec * scale);
    }

    Plane3 opBinary(string op : "*")(auto ref const(Plane3) plane) const
    {
        Vec3 normal = mat3 * plane.normal;
        return Plane3(normal, dot(normal, this * (plane.normal * plane.d)));
    }
}

Transform inverse()(auto ref const(Transform) transform)
{
    Transform result = void;

    result.scale    = 1.0f / transform.scale;
    result.mat3     = transpose(transform.mat3);
    result.position = result.mat3 * (-transform.position * result.scale);

    return result;
}