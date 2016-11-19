
#version 450 core

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D tex3;

uniform ivec4 colorBlendFunc;
uniform ivec4 alphaBlendFunc;

in vec2 coords[4];

out vec4 colorOut[3];


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

        switch(int(colorBlendFunc[i])) // int() cast here is required because of AMD glsl compiler bug.
        {
        case kBlendNextMap:        o.rgb = b.rgb; break;
        case kBlendMultiply:       o.rgb = a.rgb * b.rgb; break;
        case kBlendDoubleMultiply: o.rgb = a.rgb * b.rgb * 2; break;
        case kBlendAdd:            o.rgb = a.rgb + b.rgb; break;
        }

        switch(int(alphaBlendFunc[i])) // int() cast here is required because of AMD glsl compiler bug.
        {
        case kBlendNextMap:        o.a = b.a; break;
        case kBlendMultiply:       o.a = a.a * b.a; break;
        case kBlendDoubleMultiply: o.a = a.a * b.a * 2; break;
        case kBlendAdd:            o.a = a.a + b.a; break;
        }


        c[i + 1] = o;

    }


    colorOut[0] = c[3];
}