
module Game.Render.ShaderTypes;

import Game.Core;
import Game.Render.Shader : GLShader, ShaderUniform;

alias ShaderEnvironment = GLShader!EnvironmentUniforms;
alias ShaderModel       = GLShader!ModelUniforms;
alias ShaderChicago     = GLShader!ChicagoUniforms;

struct EnvironmentUniforms
{
    ShaderUniform!Mat4 viewproj;
    ShaderUniform!Vec3 eyePos;
    ShaderUniform!(Vec2[5]) uvscales;
    ShaderUniform!ColorArgb perpendicularColor;
    ShaderUniform!ColorArgb parallelColor;
    ShaderUniform!float specularColorControl;

    ShaderUniform!int basemap;
    ShaderUniform!int d0map;
    ShaderUniform!int d1map;
    ShaderUniform!int micromap;
    ShaderUniform!int bumpmap;
    ShaderUniform!int lightmap;
    ShaderUniform!int cubemap;
}

struct ModelUniforms
{
    ShaderUniform!Mat4 viewproj;
    ShaderUniform!(Mat4x3[32]) nodes;
    ShaderUniform!Vec3 eyePosition;
    ShaderUniform!(Vec2[2]) uvscales;
    ShaderUniform!ColorRgb perpendicularColor;
    ShaderUniform!ColorRgb parallelColor;

    ShaderUniform!ColorRgb ambientColor;

    ShaderUniform!ColorRgb distantLight0_color;
    ShaderUniform!Vec3     distantLight0_direction;

    ShaderUniform!ColorRgb distantLight1_color;
    ShaderUniform!Vec3     distantLight1_direction;

    ShaderUniform!int diffusemap;
    ShaderUniform!int multimap;
    ShaderUniform!int detailmap;
    ShaderUniform!int cubemap;
}

struct ChicagoUniforms
{
    ShaderUniform!Mat4 viewproj;
    ShaderUniform!(Mat4x3[32]) nodes;
    ShaderUniform!(Vec4[4]) uvs;

    ShaderUniform!Vec4i colorBlendFunc;
    ShaderUniform!Vec4i alphaBlendFunc;

    ShaderUniform!int tex0;
    ShaderUniform!int tex1;
    ShaderUniform!int tex2;
    ShaderUniform!int tex3;
}