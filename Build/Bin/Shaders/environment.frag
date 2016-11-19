
#version 450 core

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

uniform sampler2D basemap;
uniform sampler2D d0map;
uniform sampler2D d1map;
uniform sampler2D micromap;
uniform sampler2D bumpmap;
uniform sampler2D lightmap;
uniform samplerCube cubemap;

uniform vec4 perpendicularColor;
uniform vec4 parallelColor;

uniform float specularColorControl;

in vec2 coord[5];
in vec2 lmcoord;
in vec3 aNormal;
in vec3 v0, v1, v2;
in vec3 eyeVector;

out vec4[3] outputColor;

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

    outputColor[0] = c0 * texture(lightmap, lmcoord);

    vec3 bump       = (2.0 * texture(bumpmap, coord[4]).xyz) - 1.0;
    vec3 normal     = normalize(vec3(dot(v0.xyz, bump), dot(v1.xyz, bump), dot(v2.xyz, bump)));
    vec3 reflection = -normalize(reflect(eyeVector, normal));

    vec3 cube = texture(cubemap, reflection).rgb;

    float coeff = 0.5;

    vec3 spec = pow(cube, vec3(8.0)) / 4.0;

    vec4 c1 = clamp(mix(parallelColor, perpendicularColor, coeff), 0.0, 1.0);
    c1.rgb = mix(spec, cube, c1.a);

    outputColor[1]     = vec4(c1.rgb * specularColorControl * c0.a, 1);
    outputColor[2].xyz = normal;
}