
#version 450 core

layout(location = 0) uniform mat4 proj;

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4 color;

out vec2 coord;
out vec4 vertexColor;

void main()
{
    coord = uv;
    vertexColor = color;

    gl_Position = proj * vec4(position, 0, 1);
}