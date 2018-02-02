
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 coord;

layout(location = 0) out vec2 outCoord;

out gl_PerVertex
{
    vec4 gl_Position;
};

void main()
{
    outCoord = coord;
    gl_Position = vec4(position, 1.0f);
}
