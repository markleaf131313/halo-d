
#version 450 core

layout(location = 0) uniform mat4 viewproj;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;

out vec3 vertColor;

void main()
{
    vertColor = color;

    gl_Position = viewproj * vec4(position, 1.0);
}