
#version 450 core

layout(binding = 0) uniform sampler2D tex;

in vec2 coord;
in vec4 vertexColor;

out vec4 outColor;

void main()
{

    outColor = vertexColor * texture(tex, coord);

}