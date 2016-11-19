
#version 450 core

layout(location = 0) uniform sampler2D tex;
in vec2 coord;
out vec4 color;

void main()
{
    color = texture(tex, coord);
}