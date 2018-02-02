
#version 450 core
#extension GL_ARB_separate_shader_objects : enable

#define TYPE_NORMAL             0
#define TYPE_BLENDED            1
#define TYPE_BLENDED_SPECULAR   2

#define FUNCT_DOUBLE_MULTIPLY   0
#define FUNCT_MULTIPLY          1
#define FUNCT_DOUBLE_ADD        2

#ifndef TYPE
    #error Missing TYPE macro
#endif

#ifndef FUNCT_DETAIL
    #error Missing FUNCT_DETAIL macro
#endif

#ifndef FUNCT_MICRO
    #error Missing FUNCT_MICRO macro
#endif

layout(set = 1, binding = 0) uniform sampler2D basemap;
layout(set = 1, binding = 1) uniform sampler2D d0map;
layout(set = 1, binding = 2) uniform sampler2D d1map;
layout(set = 1, binding = 3) uniform sampler2D micromap;
layout(set = 1, binding = 4) uniform sampler2D bumpmap;
layout(set = 1, binding = 5) uniform samplerCube cubemap;

layout(set = 2, binding = 0) uniform sampler2D lightmapTextures[64];

layout(std430, push_constant) uniform PushConstants
{
    vec4 perpendicularColor;
    vec4 parallelColor;
    vec2 uvscales[5];
    float specularColorControl;
    uint lightmapIndex;
} reg;

layout(location = 0)  in vec2 coord[5];
layout(location = 6)  in vec2 lmcoord;
layout(location = 7)  in vec3 aNormal;
layout(location = 8)  in vec3 v0;
layout(location = 9)  in vec3 v1;
layout(location = 10) in vec3 v2;
layout(location = 11) in vec3 eyeVector;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outSpecular;
layout(location = 2) out vec4 outPosition;
layout(location = 3) out vec4 outNormal;

void main()
{
    vec4 base, d0, d1, micro;

    base  = texture(basemap, coord[0]);
    d0    = texture(d0map, coord[1]);
    d1    = texture(d1map, coord[2]);
    micro = texture(micromap, coord[3]);

    vec4 c0;

    #if   TYPE == TYPE_NORMAL
        c0.rgb = base.a * d0.rgb;
        c0.a = base.a * d0.a;
        c0.rgb = (1.0 - base.a) * d1.rgb + c0.rgb;
        c0.a = (1.0 - base.a) * d1.a + c0.a;
    #elif TYPE == TYPE_BLENDED
        c0.rgb = base.a * d0.rgb;
        c0.a = base.a * d0.a;
        c0.rgb = (1.0 - base.a) * d1.rgb + c0.rgb;
        c0.a = (1.0 - base.a) * d1.a + c0.a;
    #elif TYPE == TYPE_BLENDED_SPECULAR
        c0.rgb = base.a * d0.rgb;
        c0.rgb = (1.0 - base.a) * d1.rgb + c0.rgb;
        c0.a = base.a;
    #endif

    #if   FUNCT_DETAIL == FUNCT_DOUBLE_MULTIPLY
        c0.rgb = (base.rgb * c0.rgb) * 2.0;
    #elif FUNCT_DETAIL == FUNCT_MULTIPLY
        c0.rgb = (base.rgb * c0.rgb);
    #elif FUNCT_DETAIL == FUNCT_DOUBLE_ADD
        c0.rgb = base.rgb + 2.0 * (c0.rgb - 0.5);
    #endif

    // detail mask

    #if   TYPE == TYPE_NORMAL
        c0.a = base.a * c0.a;
    #elif TYPE == TYPE_BLENDED || TYPE == TYPE_BLENDED_SPECULAR
        c0.a = micro.a * c0.a;
    #endif


    #if   FUNCT_MICRO == FUNCT_DOUBLE_MULTIPLY
        c0.rgb = (micro.rgb * c0.rgb) * 2.0;
    #elif FUNCT_MICRO == FUNCT_MULTIPLY
        c0.rgb = micro.rgb * c0.rgb;
    #elif FUNCT_MICRO == FUNCT_DOUBLE_ADD
        c0.rgb = micro.rgb + 2.0 * (c0.rgb - 0.5);
    #endif

    #if TYPE == TYPE_NORMAL
        c0.a = micro.a * c0.a;
    #endif

    outAlbedo = c0 * texture(lightmapTextures[reg.lightmapIndex], lmcoord);

    vec3 bump       = (2.0 * texture(bumpmap, coord[4]).xyz) - 1.0;
    vec3 normal     = normalize(vec3(dot(v0.xyz, bump), dot(v1.xyz, bump), dot(v2.xyz, bump)));
    vec3 reflection = -normalize(reflect(eyeVector, normal));

    vec3 cube = texture(cubemap, reflection).rgb;

    float coeff = 0.5;

    vec3 spec = pow(cube, vec3(8.0)) / 4.0;

    vec4 c1 = clamp(mix(reg.parallelColor, reg.perpendicularColor, coeff), 0.0, 1.0);
    c1.rgb = mix(spec, cube, c1.a);

    outSpecular   = vec4(c1.rgb * reg.specularColorControl * c0.a, 1);
    outNormal.xyz = normal;
}
