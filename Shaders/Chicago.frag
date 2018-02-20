
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

layout(set = 1, binding = 0) uniform sampler2D tex0;
layout(set = 1, binding = 1) uniform sampler2D tex1;
layout(set = 1, binding = 2) uniform sampler2D tex2;
layout(set = 1, binding = 3) uniform sampler2D tex3;

layout(push_constant) uniform PushConstant
{
    vec4 uvs[4];
    ivec4 colorBlendFunc;
    ivec4 alphaBlendFunc;
} reg;


layout(location = 0) in vec2 coords[4];

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outSpecular;
layout(location = 2) out vec4 outPosition;
layout(location = 3) out vec4 outNormal;

void main(void)
{
    const int kBlendNextMap = 1;
    const int kBlendMultiply = 2;
    const int kBlendDoubleMultiply = 3;
    const int kBlendAdd = 4;

    vec4 t[4] = vec4[]
    (
        texture(tex0, coords[0]),
        texture(tex1, coords[1]),
        texture(tex2, coords[2]),
        texture(tex3, coords[3])
    );

    vec4 c[4];

    c[0] = t[0];

    for(int i = 0; i < 3; ++i)
    {
        vec4 a = c[i];
        vec4 b = t[i + 1];

        vec4 o = a; // default just use current

        switch(int(reg.colorBlendFunc[i]))
        {
        case kBlendNextMap:        o.rgb = b.rgb;             break;
        case kBlendMultiply:       o.rgb = a.rgb * b.rgb;     break;
        case kBlendDoubleMultiply: o.rgb = a.rgb * b.rgb * 2; break;
        case kBlendAdd:            o.rgb = a.rgb + b.rgb;     break;
        default:
        }

        switch(int(reg.alphaBlendFunc[i]))
        {
        case kBlendNextMap:        o.a = b.a;           break;
        case kBlendMultiply:       o.a = a.a * b.a;     break;
        case kBlendDoubleMultiply: o.a = a.a * b.a * 2; break;
        case kBlendAdd:            o.a = a.a + b.a;     break;
        default:
        }

        c[i + 1] = o;
    }

    outAlbedo = c[3];
    outSpecular = c[3];
    outPosition = c[3];
    outNormal = c[3];
}
