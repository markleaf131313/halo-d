
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

layout(set = 0, binding = 0) uniform sampler2D tex;

layout(location = 0) in vec2 inCoord;
layout(location = 1) in vec4 inColor;

layout(location = 0) out vec4 outColor;

void main()
{
   outColor = inColor * texture(tex, inCoord);
}
