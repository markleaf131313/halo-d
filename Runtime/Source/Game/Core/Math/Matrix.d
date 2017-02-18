
module Game.Core.Math.Matrix;

import std.math     : cos, sin, tan;
import std.meta     : allSatisfy;
import std.traits   : isAssignable, isNumeric, Unqual;
import std.conv     : to;
import std.typecons : tuple;

public import Game.Core.Math.Vector;
import Game.Core.Math.Euler;
import Game.Core.Math.Quaternion;

import Game.Core.Meta : staticIota;


@nogc nothrow pure:


alias Matrix2(T) = Matrix!(2, 2, T);
alias Matrix3(T) = Matrix!(3, 3, T);
alias Matrix4(T) = Matrix!(4, 4, T);

alias Mat2 = Matrix2!float;
alias Mat3 = Matrix3!float;
alias Mat4 = Matrix4!float;

alias Mat3x2 = Matrix!(3, 2, float);
alias Mat4x3 = Matrix!(4, 3, float);

enum isMatrix(T) = is(T : Matrix!(cols, rows, Type), int cols, int rows, Type);


struct Matrix(int _cols, int _rows, _T) if(_cols >= 2 && _rows >= 2)
{
@nogc nothrow pure:

    enum cols = _cols;
    enum rows = _rows;

    alias Type   = _T;
    alias Column = Vector!(rows, Type);

    private enum isTypeAssignable(U) = isAssignable!(Type, U);
    private enum isMatrix3 = (cols == 3 && rows == 3);
    private enum isMatrix2 = (cols == 2 && rows == 2);
    private Column[cols] m;

    this(Type d)
    {
        foreach(i ; staticIota!(cols))
        {
            foreach(j ; staticIota!(rows))
            {
                static if(i == j) m[i][j] = d;
                else              m[i][j] = 0;
            }
        }
    }

    this(Args...)(Args args)
    if(args.length == rows * cols && allSatisfy!(isTypeAssignable, typeof(args)))
    {
        foreach(i ; staticIota!(cols))
        {
            foreach(j ; staticIota!(rows))
            {
                m[i][j] = args[i * rows + j];
            }
        }
    }

    this(Args...)(Args args)
    if(args.length == cols && allSatisfy!(isVector, typeof(args)))
    {
        foreach(i ; staticIota!(cols))
        {
            static assert(args[i].size == rows);
            m[i] = args[i];
        }
    }

    this(M)(auto ref const(M) mat) if(isMatrix!M)
    {
        foreach(i ; staticIota!(cols))
        {
            foreach(j ; staticIota!(rows))
            {
                static      if(i < M.cols && j < M.rows) m[i][j] = mat[i][j];
                else static if(i == j)                   m[i][j] = 1;
                else                                     m[i][j] = 0;
            }
        }
    }

    this()(auto ref const(Quaternion!Type) q) if(isMatrix3)
    {
        Type xx = q.x * q.x; Type xy = q.x * q.y; Type yz = q.y * q.z;
        Type yy = q.y * q.y; Type xz = q.x * q.z; Type yw = q.y * q.w;
        Type zz = q.z * q.z; Type xw = q.x * q.w; Type zw = q.z * q.w;

        this(
            1 - 2 * (yy + zz),  2 * (xy + zw),      2 * (xz - yw),
            2 * (xy - zw),      1 - 2 * (xx + zz),  2 * (yz + xw),
            2 * (xz + yw),      2 * (yz - xw),      1 - 2 * (xx + yy));
    }

    static Matrix fromUnitVector()(auto ref const(Column) unit) if(isMatrix2)
    {
        return Matrix(unit.x, unit.y, -unit.y, unit.x);
    }

    static Matrix fromEulerAngleZ()(Type angle) if(isMatrix2)
    {
        Type c = cos(angle);
        Type s = sin(angle);

        return Matrix(c, s, -s, c);
    }

    static Matrix fromAxisAngle()(auto ref const(Vector!(3, Type)) axis, Type angle) if(isMatrix3)
    {
        Vector!(3, Type) a = axis;
        normalize(a);

        Type c = cos(angle);
        Type s = sin(angle);
        Type t = 1 - c;

        return Matrix(
            t * a.x * a.x + c,        t * a.x * a.y + a.z * s,  t * a.x * a.z - a.y * s,
            t * a.x * a.y - a.z * s,  t * a.y * a.y + c,        t * a.y * a.z + a.x * s,
            t * a.x * a.z + a.y * s,  t * a.y * a.z - a.x * s,  t * a.z * a.z + c);
    }

    static Matrix fromEuler()(auto ref const(Vector!(3, Type)) euler) if(isMatrix3)
    {
        Vector!(3, Type) axis = euler;
        auto length = normalize(axis);

        if(length == Type(0))
        {
            return Matrix(1);
        }

        return fromAxisAngle(euler, length);
    }

    static Matrix fromEulerAngleX()(Type angle) if(isMatrix3)
    {
        auto c = cos(angle);
        auto s = sin(angle);

        return Matrix(1, 0, 0, 0, c, s, 0, -s, c);
    }

    static Matrix fromEulerAngleY()(Type angle) if(isMatrix3)
    {
        auto c = cos(angle);
        auto s = sin(angle);

        return Matrix(c, 0, -s, 0, 1, 0, s, 0, c);
    }

    static Matrix fromEulerAngleZ()(Type angle) if(isMatrix3)
    {
        auto c = cos(angle);
        auto s = sin(angle);

        return Matrix(c, s, 0, -s, c, 0, 0, 0, 1);
    }

    // TODO better name, isn't "XYZ" but closer to: X_3 * -Y_2 * Z_1
    static Matrix fromEulerXYZ()(Euler3 euler) if(isMatrix3)
    {
        // using "X_roll * Y_pitch * Z_yaw" rotation
        // where Y_pitch is rotating in opposite direction (negative sin())

        Matrix result = void;

        Type s0 =  sin(euler.roll);  Type c0 = cos(euler.roll);
        Type s1 = -sin(euler.pitch); Type c1 = cos(euler.pitch);
        Type s2 =  sin(euler.yaw);   Type c2 = cos(euler.yaw);

        result[0] = Column(c1 * c2,  c0 * s2 + c2 * s0 * s1, s0 * s2 - c0 * c2 * s1);
        result[1] = Column(-c1 * s2, c0 * c2 - s0 * s1 * s2, c2 * s0 + c0 * s1 * s2);
        result[2] = Column(s1,       -c1 * s0,               c0 * c1);

        return result;
    }

    static Matrix fromPerpUnitVectors(V : Vector!(3, Type))(auto ref const(V) forward, auto ref const(V) up)
    if(isMatrix3)
    {
        return Matrix(forward, cross(up, forward), up);
    }

    ref inout(Column) opIndex(int i) inout
    {
        return m[i];
    }

    auto opBinary(string op, N)(N num) const if(isNumeric!N)
    {
        Matrix!(cols, rows, Unqual!(typeof(m[0][0] * num))) result = void;

        foreach(i ; staticIota!(cols))
        {
            foreach(j ; staticIota!(rows))
            {
                result[i][j] = mixin("m[i][j] " ~ op ~ " num");
            }
        }

        return result;
    }

    auto opBinaryRight(string op, N)(N num) const if(isNumeric!N)
    {
        Matrix!(cols, rows, Unqual!(typeof(m[0][0] * num))) result = void;

        foreach(i ; staticIota!(cols))
        {
            foreach(j ; staticIota!(rows))
            {
                result[i][j] = mixin("num " ~ op ~ " m[i][j]");
            }
        }

        return result;
    }

    auto opBinary(string op : "*", V)(auto ref const(V) vec) const
    if(isVector!V && (V.size == cols || V.size == cols - 1 && V.size == rows))
    {
        template impl(int i)
        {
            enum s = to!string(i);
            static if(i == 0) enum impl = "m[0][i] * vec[0]";
            else              enum impl = impl!(i - 1) ~ " + m[" ~ s ~ "][i] * vec[" ~ s ~ "]";
        }

        Vector!(rows, Unqual!(typeof(m[0][0] * vec.x))) result = void;

        foreach(i ; staticIota!(result.size))
        {
            // Allow case of Mat4x3 * Vec3, where Vec3 is interpreted as Vec4 with "w" = 1
            static if(V.size == cols) result[i] = mixin(impl!(V.size - 1));
            else                      result[i] = mixin(impl!(V.size - 1)) + m[cols - 1][i];
        }

        return result;
    }

    auto opBinary(string op : "*", M)(auto ref const(M) mat) const if(isMatrix!M && cols == M.rows)
    {
        template impl(int i)
        {
            enum s = to!string(i);
            static if(i == 0) enum impl = "m[0][j] * mat[i][0]";
            else              enum impl = impl!(i - 1) ~ " + m[" ~ s ~ "][j] * mat[i][" ~ s ~ "]";
        }

        alias Result = Matrix!(M.cols, rows, Unqual!(typeof(m[0][0] * mat[0][0])));
        Result result = void;

        foreach(i ; staticIota!(Result.cols))
        {
            foreach(j ; staticIota!(Result.rows))
            {
                result[i][j] = mixin(impl!(cols - 1));
            }
        }

        return result;
    }
}

auto inverse(M)(auto ref const(M) mat) if(isMatrix!M && M.cols == 3 && M.rows == 3)
{
    return transpose(mat);
}

auto transpose(M)(auto ref const(M) mat) if(isMatrix!M)
{
    Matrix!(M.rows, M.cols, M.Type) result = void;

    foreach(i ; staticIota!(M.cols))
    {
        foreach(j ; staticIota!(M.rows))
        {
            result[j][i] = mat[i][j];
        }
    }

    return result;
}

auto perspectiveMatrixAndInverse(T)(T fovy, T ratio, T near, T far)
{
    Matrix4!T result  = 0;
    Matrix4!T inverse = 0;

    const T f = 1 / tan(fovy / 2);
    const T d = near - far;

    result[0][0] = f / ratio;
    result[1][1] = f;
    result[2][2] = (near + far) / d;
    result[2][3] = -1;
    result[3][2] = (2 * near * far) / d;

    inverse[0][0] = ratio / f;
    inverse[1][1] = 1 / f;
    inverse[2][3] = d / (2 * near * far);
    inverse[3][2] = -1;
    inverse[3][3] = (near + far) / (2 * near * far);

    return tuple(result, inverse);
}

Matrix4!T orthogonalMatrix(T)(T left, T right, T bot, T top)
{
    Matrix4!T result = Matrix4!T(1);

    result[0][0] = 2 / (right - left);
    result[1][1] = 2 / (top - bot);
    result[2][2] = -1;
    result[3][0] = -(right + left) / (right - left);
    result[3][1] = -(top + bot) / (top - bot);

    return result;
}

Vec3 unprojectMatrix(Vec3 window, Mat4 viewproj, Vec2 viewportDimension)
{
    Vec4 pt = Vec4(window.xy / viewportDimension, window.z, 1.0f);
    Vec4 result = viewproj * (pt * 2.0f - 1.0f);

    return result.xyz / result.w;
}

