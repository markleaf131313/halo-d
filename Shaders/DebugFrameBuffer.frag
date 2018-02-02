
#version 450 core
#extension GL_ARB_separate_shader_objects : enable


layout(binding = 0) uniform sampler2D tex0;
layout(binding = 1) uniform sampler2D tex1;
layout(binding = 2) uniform sampler2D tex2;
layout(binding = 3) uniform sampler2D tex3;

layout(location = 0) in vec2 inCoord;

layout(location = 0) out vec4 outColor;

void main()
{
    vec4 colors[4];

    colors[0] = texture(tex0, inCoord);
    colors[1] = texture(tex1, inCoord);
    colors[2] = texture(tex2, inCoord);
    colors[3] = texture(tex3, inCoord);

    outColor = colors[0];
}
