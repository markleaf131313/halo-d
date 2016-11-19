
#version 450 core


layout(location = 0) in vec3  position;
layout(location = 1) in vec3  normal;
layout(location = 2) in vec2  uv;
layout(location = 3) in ivec2 node;
layout(location = 4) in vec2  weight;

uniform mat4   viewproj;
uniform mat4x3 nodes[32];

uniform vec2 uvscales[2];
uniform vec3 eyePosition;
uniform vec3 perpendicularColor;
uniform vec3 parallelColor;

uniform vec3 ambientColor;

uniform vec3 distantLight0_color;
uniform vec3 distantLight0_direction;

uniform vec3 distantLight1_color;
uniform vec3 distantLight1_direction;


out vec3 reflection;
out vec2 coords[2];
out vec4 d0in;
out vec4 d1;
out vec3 aNormal;

void main()
{
    vec3 rNormal = mat3(nodes[node.x]) * normal * weight.x + mat3(nodes[node.y]) * normal * weight.y;
    vec3 rPosition = nodes[node.x] * vec4(position, 1.0) * weight.x + nodes[node.y] * vec4(position, 1.0) * weight.y;

    vec3 eyeVector = eyePosition - rPosition;
    reflection = -normalize(reflect(eyeVector, rNormal));

    vec3 lightSum = ambientColor;

    float attenuationDistantLight0 = dot(rNormal, -distantLight0_direction);
    float attenuationDistantLight1 = dot(rNormal, -distantLight1_direction);

    lightSum += attenuationDistantLight0 * distantLight0_color;
    lightSum += attenuationDistantLight1 * distantLight1_color;

    d0in.rgb = lightSum;

    float p = abs(dot(normalize(eyeVector), rNormal));
    d1.rgb = (p * perpendicularColor) + (1.0 - p) * parallelColor;


    coords[0] = uvscales[0] * uv;
    coords[1] = uvscales[1] * coords[0];

    aNormal = rNormal;

    gl_Position = viewproj * vec4(rPosition, 1.0);
}

