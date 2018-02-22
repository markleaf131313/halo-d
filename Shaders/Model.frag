
#version 450
#extension GL_ARB_separate_shader_objects : enable

uniform sampler2D diffusemap;
uniform sampler2D multimap;
uniform sampler2D detailmap;
uniform samplerCube cubemap;

in vec3 reflection;
in vec2 coords[2];
in vec4 d0in;
in vec4 d1;
in vec3 aNormal;

out vec4 outColors[3];


#ifndef MASK
    #error Missing MASK macro
#endif

#ifndef MASK_INVERT
    #error Missing MASK_INVERT macro
#endif

#ifndef DETAIL_FUNCTION
    #error missing DETAIL_FUNCTION macro
#endif

#ifndef DETAIL_AFTER_REFLECTION
    #error Missing DETAIL_AFTER_REFLECTION macro
#endif

const int kDetailBaisedMultiply = 0;
const int kDetailMultiply       = 1;
const int kDetailBaisedAdd      = 2;

const int kMaskReflection        = 1;
const int kMaskSelfIllumination  = 2;
const int kMaskChangeColor       = 3;
const int kMaskMultipurposeAlpha = 4;

vec3 maskDetail(in vec3 detail, in float mask)
{
    if(DETAIL_FUNCTION == kDetailMultiply)
    {
        return MASK_INVERT
            ? mix(detail, vec3(1.0), mask)
            : mix(vec3(1.0), detail, mask);
    }
    else
    {
        return MASK_INVERT
            ? mix(detail, vec3(0.5), mask)
            : mix(vec3(0.5), detail, mask);
    }
}

void main()
{
    // temporary uniforms ///////////////////
    vec3 changeColor = vec3(1.0, 1.0, 1.0);
    vec4 selfIlluminationColor = vec4(1.0, 1.0, 1.0, 1.0);
    ////////////////////////////////////////

    vec4 diffuse = texture(diffusemap, coords[0]);
    vec4 multi   = texture(multimap,   coords[0]);
    vec4 detail  = texture(detailmap,  coords[1]);
    vec4 cube    = texture(cubemap,    reflection);
    vec4 spec;

    vec4 d0 = d0in;

    switch(MASK)
    {
    case kMaskReflection:        detail.rgb = maskDetail(detail.rgb, multi.b); break;
    case kMaskSelfIllumination:  detail.rgb = maskDetail(detail.rgb, multi.g); break;
    case kMaskChangeColor:       detail.rgb = maskDetail(detail.rgb, multi.a); break;
    case kMaskMultipurposeAlpha: detail.rgb = maskDetail(detail.rgb, multi.r); break;
    }

    d0.rgb = d0.rgb + (multi.g * selfIlluminationColor.rgb);

    cube.rgb = cube.rgb * d1.rgb;
    d0.rgb = d0.rgb * (multi.a * changeColor.rgb + (1 - multi.a));

    if(DETAIL_AFTER_REFLECTION)
    {
        // diffuse.rgb = (diffuse.rgb * d0.rgb) + (cube.rgb * multi.b * d1.a);
        diffuse.rgb = diffuse.rgb * d0.rgb;
        spec.rgb = cube.rgb * multi.b * d1.a;

        switch(DETAIL_FUNCTION)
        {
        case kDetailBaisedMultiply: spec.rgb = (spec.rgb * detail.rgb) * 2.0;       break;
        case kDetailMultiply:       spec.rgb = (spec.rgb * detail.rgb);             break;
        case kDetailBaisedAdd:      spec.rgb = spec.rgb + (detail.rgb * 2.0 - 1.0); break;
        }
    }

    switch(DETAIL_FUNCTION)
    {
    case kDetailBaisedMultiply: diffuse.rgb = (diffuse.rgb * detail.rgb) * 2.0;       break;
    case kDetailMultiply:       diffuse.rgb = (diffuse.rgb * detail.rgb);             break;
    case kDetailBaisedAdd:      diffuse.rgb = diffuse.rgb + (detail.rgb * 2.0 - 1.0); break;
    }

    if(!DETAIL_AFTER_REFLECTION)
    {
        // diffuse.rgb = (diffuse.rgb * d0.rgb) + (cube.rgb * multi.b * d1.a);
        diffuse.rgb = diffuse.rgb * d0.rgb;
        spec.rgb = (cube.rgb * multi.b * d1.a);
    }

    outColors[0] = vec4(diffuse.rgb, diffuse.a);
    outColors[1] = vec4(spec.rgb, 1.0);
    outColors[2].xyz = normalize(aNormal);

}

