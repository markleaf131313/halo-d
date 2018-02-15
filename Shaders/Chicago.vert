
#version 450 core
#extension GL_ARB_separate_shader_objects : enable


layout(set = 0, binding = 0) uniform SceneUbo
{
    mat4 viewproj;
    vec3 eyePos;
} scene;

layout(push_constant) uniform PushConstant
{
    vec4 uvs[4];
    ivec4 colorBlendFunc;
    ivec4 alphaBlendFunc;
} reg;

layout(set = 2, binding = 0) uniform Ubo
{
    mat4x3 nodes[32];
} ubo;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 coord;
layout(location = 3) in ivec2 node;

layout(location = 0) out vec2 coords[4];

out gl_PerVertex
{
    vec4 gl_Position;
};

void main(void)
{
    coords[0] = reg.uvs[0].xy + coord * reg.uvs[0].zw;
    coords[1] = reg.uvs[1].xy + coord * reg.uvs[1].zw;
    coords[2] = reg.uvs[2].xy + coord * reg.uvs[2].zw;
    coords[3] = reg.uvs[3].xy + coord * reg.uvs[3].zw;

    vec3 p = ubo.nodes[node.x] * vec4(position, 1.0);
    gl_Position = scene.viewproj * vec4(p, 1.0);

}
