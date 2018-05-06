
#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3  position;
layout(location = 1) in vec3  normal;
layout(location = 2) in vec2  coord;
layout(location = 3) in ivec2 node;
layout(location = 4) in vec2  weight;

layout(set = 0, binding = 0) uniform SceneUbo
{
    mat4 viewproj;
    vec3 eyePos;
} scene;

layout(std430, push_constant) uniform PushConstant
{
    vec2 uvscales[2];
    vec3 perpendicularColor;
    vec3 parallelColor;

    vec3 ambientColor;

    vec3 distantLight0_color;
    vec3 distantLight0_direction;

    vec3 distantLight1_color;
    vec3 distantLight1_direction;
} reg;

layout(set = 2, binding = 0) uniform Ubo
{
    mat4 nodes[32];
} ubo;

layout(location = 0) out vec3 reflection;
layout(location = 1) out vec2 coords[2];
layout(location = 3) out vec4 d0in;
layout(location = 4) out vec4 d1;
layout(location = 5) out vec3 aNormal;

out gl_PerVertex
{
    vec4 gl_Position;
};

void main()
{
    vec3 rNormal = normalize(mat3(ubo.nodes[node.x]) * normal * weight.x + mat3(ubo.nodes[node.y]) * normal * weight.y);
    vec3 rPosition = vec3(ubo.nodes[node.x] * vec4(position, 1.0) * weight.x + ubo.nodes[node.y] * vec4(position, 1.0) * weight.y);

    vec3 eyeVector = scene.eyePos - rPosition;
    reflection = -normalize(reflect(eyeVector, rNormal));

    vec3 lightSum = reg.ambientColor;

    // TODO transparency for distant light
    float attenuationDistantLight0 = max(0.0, dot(rNormal, -reg.distantLight0_direction));
    float attenuationDistantLight1 = max(0.0, dot(rNormal, -reg.distantLight1_direction));

    lightSum += attenuationDistantLight0 * reg.distantLight0_color;
    lightSum += attenuationDistantLight1 * reg.distantLight1_color;

    d0in.rgb = lightSum;

    float p = abs(dot(normalize(eyeVector), rNormal));
    d1.rgb = (p * reg.perpendicularColor) + (1.0 - p) * reg.parallelColor;
    d1.a = 1.0;

    coords[0] = reg.uvscales[0] * coord;
    coords[1] = reg.uvscales[1] * coords[0];

    aNormal = rNormal;

    gl_Position = scene.viewproj * vec4(rPosition, 1.0);
}

