
module Game.Render.Pipeline;

import Vulkan;

import Game.Core;

struct Pipeline
{
@nogc nothrow:

enum VertexInputType
{
    sbspVertex,
    modelVertex,
}

VkPipelineVertexInputStateCreateInfo   vertexInputInfo;
VkPipelineInputAssemblyStateCreateInfo inputAssembly;
VkPipelineViewportStateCreateInfo      viewportState;
VkPipelineRasterizationStateCreateInfo rasterizer;
VkPipelineMultisampleStateCreateInfo   multisampling;
VkPipelineColorBlendStateCreateInfo    colorBlending;
VkPipelineDynamicStateCreateInfo       dynamicState;
VkPipelineDepthStencilStateCreateInfo  depthStencilState;
VkPipelineLayoutCreateInfo             layoutInfo;

VkVertexInputAttributeDescription[7] attributeDescs;
VkVertexInputBindingDescription[2]   bindingDescs;

@disable this(this);

void setRasterizer(VertexInputType type)
{
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;

    switch(type)
    {
    case VertexInputType.sbspVertex:
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        break;
    case VertexInputType.modelVertex:
        inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
        break;
    default:
    }
}

void setVertexInputInfo(VertexInputType type)
{
    import Game.Tags : TagBspVertex, TagBspLightmapVertex, TagModelVertex;

    switch(type)
    {
    case VertexInputType.sbspVertex:
        bindingDescs[0] = VkVertexInputBindingDescription(0, TagBspVertex.sizeof,         VK_VERTEX_INPUT_RATE_VERTEX);
        bindingDescs[1] = VkVertexInputBindingDescription(1, TagBspLightmapVertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX);
        vertexInputInfo.vertexBindingDescriptions = bindingDescs[0 .. 2];

        attributeDescs[0] = VkVertexInputAttributeDescription(0, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.position.offsetof);
        attributeDescs[1] = VkVertexInputAttributeDescription(1, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.normal.offsetof);
        attributeDescs[2] = VkVertexInputAttributeDescription(2, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.binormal.offsetof);
        attributeDescs[3] = VkVertexInputAttributeDescription(3, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.tangent.offsetof);
        attributeDescs[4] = VkVertexInputAttributeDescription(4, 0, VK_FORMAT_R32G32_SFLOAT,    TagBspVertex.coord.offsetof);
        attributeDescs[5] = VkVertexInputAttributeDescription(5, 1, VK_FORMAT_R32G32B32_SFLOAT, TagBspLightmapVertex.normal.offsetof);
        attributeDescs[6] = VkVertexInputAttributeDescription(6, 1, VK_FORMAT_R32G32_SFLOAT,    TagBspLightmapVertex.coord.offsetof);
        vertexInputInfo.vertexAttributeDescriptions = attributeDescs[0 .. 7];
        break;
    case VertexInputType.modelVertex:
        bindingDescs[0] = VkVertexInputBindingDescription(0, TagModelVertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX);
        vertexInputInfo.vertexBindingDescriptions = bindingDescs[0 .. 1];

        attributeDescs[0] = VkVertexInputAttributeDescription(0, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.position.offsetof);
        attributeDescs[1] = VkVertexInputAttributeDescription(1, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.normal.offsetof);
        attributeDescs[2] = VkVertexInputAttributeDescription(2, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.coord.offsetof);
        attributeDescs[3] = VkVertexInputAttributeDescription(3, 0, VK_FORMAT_R16G16_UINT,      TagModelVertex.node0.offsetof);
        attributeDescs[4] = VkVertexInputAttributeDescription(4, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.weight.offsetof);
        vertexInputInfo.vertexAttributeDescriptions = attributeDescs[0 .. 5];
        break;
    default:
    }
}

VkGraphicsPipelineCreateInfo makeCreateInfo()
{
    VkGraphicsPipelineCreateInfo info;

    info.pVertexInputState   = &vertexInputInfo;
    info.pInputAssemblyState = &inputAssembly;
    info.pViewportState      = &viewportState;
    info.pRasterizationState = &rasterizer;
    info.pMultisampleState   = &multisampling;
    info.pDepthStencilState  = &depthStencilState;
    info.pColorBlendState    = &colorBlending;
    info.pDynamicState       = &dynamicState;

    return info;
}

}
