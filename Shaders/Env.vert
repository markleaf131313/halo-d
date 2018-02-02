
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

layout(set = 0, binding = 0) uniform Ubo
{
    mat4 viewproj;
    vec3 eyePos;
} ubo;

layout(std140, push_constant) uniform PushConstant
{
    vec2 uvscales[5];
    vec4 perpendicularColor;
    vec4 parallelColor;
    float specularColorControl;
    uint lightmapIndex;
} reg;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 binormal;
layout(location = 3) in vec3 tangent;
layout(location = 4) in vec2 uv;

layout(location = 5) in vec3 lmnormal;
layout(location = 6) in vec2 lmuv;

layout(location = 0) out vec2 coord[5];
layout(location = 6) out vec2 lmcoord;
layout(location = 7) out vec3 aNormal;
layout(location = 8) out vec3 v0;
layout(location = 9) out vec3 v1;
layout(location = 10) out vec3 v2;
layout(location = 11) out vec3 eyeVector;

void main()
{
    coord[0] = uv * reg.uvscales[0];
    coord[1] = uv * reg.uvscales[1];
    coord[2] = uv * reg.uvscales[2];
    coord[3] = uv * reg.uvscales[3];
    coord[4] = uv * reg.uvscales[4];

    lmcoord = lmuv;
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

    eyeVector = -position.xyz + ubo.eyePos.xyz;

    gl_Position = ubo.viewproj * vec4(position, 1.0);
}
