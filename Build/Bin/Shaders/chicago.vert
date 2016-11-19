
#version 450 core


uniform mat4 viewproj;
uniform vec4 uvs[4];
uniform mat4x3 nodes[32];

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 uv;
layout(location = 3) in ivec2 node;

out vec2 coords[4];

void main(void)
{
    coords[0] = uvs[0].xy + uv * uvs[0].zw;
    coords[1] = uvs[1].xy + uv * uvs[1].zw;
    coords[2] = uvs[2].xy + uv * uvs[2].zw;
    coords[3] = uvs[3].xy + uv * uvs[3].zw;

    vec3 p = nodes[node.x] * vec4(position, 1.0);
    gl_Position = viewproj * vec4(p, 1.0);

}