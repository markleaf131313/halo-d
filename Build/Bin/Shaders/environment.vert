
#version 450 core

uniform mat4 viewproj;
uniform vec2 uvscales[5];
uniform vec3 eyePos;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 binormal;
layout(location = 3) in vec3 tangent;
layout(location = 4) in vec2 uv;

layout(location = 5) in vec3 lmnormal;
layout(location = 6) in vec2 lmuv;

out vec2 coord[5];
out vec2 lmcoord;
out vec3 aNormal;
out vec3 v0, v1, v2;
out vec3 eyeVector;

void main()
{
    coord[0] = uv * uvscales[0];
    coord[1] = uv * uvscales[1];
    coord[2] = uv * uvscales[2];
    coord[3] = uv * uvscales[3];
    coord[4] = uv * uvscales[4];

    lmcoord  = lmuv;
    aNormal = normal;

    v0.x = tangent.x;
    v1.x = tangent.y;
    v2.x = tangent.z;

    v0.y = binormal.x;
    v1.y = binormal.y;
    v2.y = binormal.z;

    v0.z = normal.x;
    v1.z = normal.y;
    v2.z = normal.z;

    eyeVector = -position.xyz + eyePos.xyz;

    gl_Position = viewproj * vec4(position, 1.0);
}