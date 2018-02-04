
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 coord;
layout(location = 2) in vec4 color;

layout(std430, push_constant) uniform PushConstants
{
    vec2 scale;
    vec2 translate;
} push;

layout(location = 0) out vec2 outCoord;
layout(location = 1) out vec4 outColor;

out gl_PerVertex
{
    vec4 gl_Position;
};

void main()
{
    outCoord = coord;
    outColor = color;

    gl_Position = vec4(position * push.scale + push.translate, 0.0, 1.0);
}
