
module Game.Render.Pipeline;

import Vulkan;

import Game.Core;

struct Pipeline
{
@nogc nothrow:

VkPipelineVertexInputStateCreateInfo   vertexInputInfo;
VkPipelineInputAssemblyStateCreateInfo inputAssembly;
VkPipelineViewportStateCreateInfo      viewportState;
VkPipelineRasterizationStateCreateInfo rasterizer;
VkPipelineMultisampleStateCreateInfo   multisampling;
VkPipelineColorBlendStateCreateInfo    colorBlending;
VkPipelineDynamicStateCreateInfo       dynamicState;
VkPipelineDepthStencilStateCreateInfo  depthStencilState;
VkPipelineLayoutCreateInfo             layoutInfo;


@disable this(this);

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
