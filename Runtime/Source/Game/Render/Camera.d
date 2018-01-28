
module Game.Render.Camera;

import std.meta     : AliasSeq;
import std.typecons : tuple;

import Game.Core;
import Game.Tags;

struct Camera
{
Vec2 angle    = 0.0f;

Vec3 position = 0.0f;
Vec3 forward  = Vec3(1, 0, 0);
Vec3 up       = Vec3(0, 0, 1);

float aspect;
float fieldOfView;

float near;
float far;

Mat4   projection;
Mat4   projectionInverse;
Mat4x3 view;
Mat4   viewInverse;

Mat4 viewproj;

auto calculateRayFromMouse(Vec2 coord, Vec2 windowSize)
{
    Mat4 matrix = viewInverse * projectionInverse;

    Vec3 start = unprojectMatrix(Vec3(coord.x, windowSize.y - coord.y, 0.0f), matrix, windowSize);
    Vec3 end   = unprojectMatrix(Vec3(coord.x, windowSize.y - coord.y, 1.0f), matrix, windowSize);

    return tuple(start, end);
}

void updateMatrices()
{
    AliasSeq!(projection, projectionInverse) = perspectiveMatrixAndInverse(fieldOfView, aspect, near, far);

    Vec3 side = -cross(up, forward);

    side.normalize();

    view[0][0] = side.x;
    view[1][0] = side.y;
    view[2][0] = side.z;

    view[0][1] = up.x;
    view[1][1] = up.y;
    view[2][1] = up.z;

    view[0][2] = -forward.x;
    view[1][2] = -forward.y;
    view[2][2] = -forward.z;

    view[3] = Mat3(view) * -position;

    viewproj = projection * Mat4(view);

    Transform transform = Transform(Mat3(view), view[3]);
    viewInverse = inverse(transform).toMat4();


}

void updateRotation(float deltax, float deltay)
{
    immutable Vec3 UP = Vec3(0, 0, 1);

    angle += Vec2(deltax, deltay);
    angle.y = clamp(angle.y, -TagConstants.Camera.maxPitchAngle, TagConstants.Camera.maxPitchAngle);

    forward.x = cos(angle.x) * cos(angle.y);
    forward.y = sin(angle.x) * cos(angle.y);
    forward.z = sin(angle.y);

    Vec3 side = cross(forward, UP);
    up = cross(side, forward);
    normalize(up);
}
}
