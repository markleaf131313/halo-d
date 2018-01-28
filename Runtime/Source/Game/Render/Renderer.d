
module Game.Render.Renderer;

import std.container.array;
import std.conv : to;
import std.file : readText;
import std.meta : AliasSeq;

import SDL2;
import ImGui;
import Vulkan;

import Game.Render.Camera;

import Game.Cache;
import Game.Core;
import Game.Debug;
import Game.Tags;
import Game.World;



struct Renderer
{

@disable this(this);

struct Vertex
{
    float[2] pos;
    float[3] color;

    static VkVertexInputBindingDescription  getBindingDescription()
    {
        VkVertexInputBindingDescription binding;

        binding.binding = 0;
        binding.stride = this.sizeof;
        binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

        return binding;
    }

    static VkVertexInputAttributeDescription[2] getAttributeDescriptions()
    {
        VkVertexInputAttributeDescription[2] descs;

        descs[0].binding = 0;
        descs[0].location = 0;
        descs[0].format = VK_FORMAT_R32G32_SFLOAT;
        descs[0].offset = pos.offsetof;

        descs[1].binding = 0;
        descs[1].location = 1;
        descs[1].format = VK_FORMAT_R32G32B32_SFLOAT;
        descs[1].offset = color.offsetof;

        return descs;
    }

}

struct SwapChainSupportDetails
{
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR[]     formats;
    VkPresentModeKHR[]       presentModes;
}

version(Android)
{
    static immutable const(char)*[] validationLayers =
    [
        "VK_LAYER_LUNARG_parameter_validation",
        "VK_LAYER_LUNARG_object_tracker",
        "VK_LAYER_LUNARG_core_validation",
    ];
}
else
{
    static immutable const(char)*[] validationLayers =
    [
        "VK_LAYER_LUNARG_standard_validation",
    ];
}

static immutable const(char)*[] requiredExtensions =
[
    VK_EXT_DEBUG_REPORT_EXTENSION_NAME,
];

static immutable const(char)*[] requiredDeviceExtensions =
[
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,
];

static Vertex[] vertices =
[
    Vertex([ 0.0f, -0.5f], [1.0f, 0.0f, 0.0f]),
    Vertex([ 0.5f,  0.5f], [0.0f, 1.0f, 0.0f]),
    Vertex([-0.5f,  0.5f], [0.0f, 0.0f, 1.0f]),
];

VkInstance               instance;
VkDebugReportCallbackEXT callback;
VkPhysicalDevice         physicalDevice;
VkDevice                 device;
VkQueue                  graphicsQueue;
VkQueue                  presentQueue;
VkSurfaceKHR             surface;
VkSwapchainKHR           swapchain;
VkFormat                 swapchainImageFormat;
VkExtent2D               swapchainExtent;
VkImage[]                swapchainImages;
VkImageView[]            swapchainImageViews;
VkRenderPass             renderPass;
VkPipelineLayout         pipelineLayout;
VkPipeline               graphicsPipeline;
VkFramebuffer[]          swapchainFramebuffers;
VkCommandPool            commandPool;
VkCommandBuffer[]        commandBuffers;
VkBuffer                 vertexBuffer;
VkSemaphore              imageAvailableSemaphore;
VkSemaphore              renderFinishedSemaphore;
VkDeviceMemory           vertexBufferMemory;


uint windowWidth = 1080;
uint windowHeight = 1920;

struct Queues
{
    int graphicsQueue = -1;
    int presentQueue  = -1;

    bool opCast(T : bool)()
    {
        return graphicsQueue >= 0 && presentQueue >= 0;
    }
}

Queues findGraphicsQueueIndex(VkPhysicalDevice device)
{
    Queues result;

    uint queueFamilyCount;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);
    auto queueFamilies = new VkQueueFamilyProperties[queueFamilyCount];
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    foreach(int i, ref VkQueueFamilyProperties family ; queueFamilies)
    {
        VkBool32 presentSupport = false;
        vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport);

        if(family.queueCount > 0)
        {
            if(family.queueFlags & VK_QUEUE_GRAPHICS_BIT) result.graphicsQueue = i;
            if(presentSupport)                            result.presentQueue  = i;

            if(result)
            {
                return result;
            }
        }
    }

    return result;
}

void createInstance(SDL_Window* window)
{
    const(char)*[] extensions;
    uint           extensionCount;

    if(!SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, null))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "SDL_Vulkan_GetInstanceExtensions(): %s", SDL_GetError());
        assert(0);
    }

    extensions = new const(char)*[extensionCount + requiredExtensions.length];
    extensions[$ - requiredExtensions.length .. $] = requiredExtensions;

    if(!SDL_Vulkan_GetInstanceExtensions(window, &extensionCount, extensions.ptr))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "SDL_Vulkan_GetInstanceExtensions(): %s", SDL_GetError());
        assert(0);
    }

    foreach(ext ; extensions)
    {
        SDL_Log("Extension: %s", ext);
    }

    VkApplicationInfo    appInfo;
    VkInstanceCreateInfo instanceCreateInfo;

    appInfo.apiVersion = VK_API_VERSION_1_0;

    instanceCreateInfo.pApplicationInfo = &appInfo;
    instanceCreateInfo.enabledExtensionCount = extensions.length32;
    instanceCreateInfo.ppEnabledExtensionNames = extensions.ptr;
    instanceCreateInfo.enabledLayerCount = validationLayers.length;
    instanceCreateInfo.ppEnabledLayerNames = validationLayers.ptr;

    if(VkResult result = vkCreateInstance(&instanceCreateInfo, null, &instance))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateInstance(): %s", result.to!string.ptr);
        assert(0);
    }
}

uint debugCallback(
    VkDebugReportFlagsEXT flags,
    VkDebugReportObjectTypeEXT objectType,
    ulong object,
    size_t location,
    int messageCode,
    const(char)* pLayerPrefix,
    const(char)* pMessage,
    void* pUserData)
{
    SDL_Log(pMessage);

    return VK_FALSE;
}

void setupDebugCallback()
{
    VkDebugReportCallbackCreateInfoEXT info;
    info.flags = VK_DEBUG_REPORT_ERROR_BIT_EXT | VK_DEBUG_REPORT_WARNING_BIT_EXT;
    info.pUserData = &this;
    info.pfnCallback = function(
        VkDebugReportFlagsEXT flags,
        VkDebugReportObjectTypeEXT objectType,
        ulong object,
        size_t location,
        int messageCode,
        const(char)* pLayerPrefix,
        const(char)* pMessage,
        void* pUserData)
    {
        return (cast(typeof(this)*)pUserData)
            .debugCallback(flags, objectType, object, location, messageCode, pLayerPrefix, pMessage, pUserData);
    };

    auto func = cast(PFN_vkCreateDebugReportCallbackEXT)vkGetInstanceProcAddr(instance, "vkCreateDebugReportCallbackEXT");

    if(func)
    {
        if(VkResult result = func(instance, &info, null, &callback))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateDebugReportCallbackEXT(): %s", result.to!string.ptr);
            assert(0);
        }
    }
}

void createSurface(SDL_Window* window)
{
    if(!SDL_Vulkan_CreateSurface(window, instance, &surface))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "SDL_Vulkan_CreateSurface(): %s", SDL_GetError());
        assert(0);
    }
}

void pickPhysicalDevice()
{
    uint deviceCount;
    vkEnumeratePhysicalDevices(instance, &deviceCount, null);

    if(deviceCount == 0)
    {
        assert(0, "No physical devices.");
    }

    VkPhysicalDevice[] devices = new VkPhysicalDevice[deviceCount];
    vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr);

    foreach(device ; devices)
    {
        VkPhysicalDeviceProperties deviceProperties;
        VkPhysicalDeviceFeatures deviceFeatures;

        vkGetPhysicalDeviceProperties(device, &deviceProperties);
        vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

        switch(deviceProperties.deviceType)
        {
        case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:
            if(findGraphicsQueueIndex(device))
            {
                physicalDevice = device;
            }
            break;
        case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:
            if(findGraphicsQueueIndex(device) && physicalDevice is null)
            {
                physicalDevice = device;
            }
            break;
        default:
        }
    }

    if(physicalDevice is null)
    {
        assert(0, "No supported device found.");
    }
}

void createLogicalDevice()
{
    auto queues = findGraphicsQueueIndex(physicalDevice);

    VkDeviceQueueCreateInfo[] queueInfos;

    float priority = 1.0f;

    if(queues.graphicsQueue == queues.presentQueue)
    {
        queueInfos = new VkDeviceQueueCreateInfo[1];
    }
    else
    {
        queueInfos = new VkDeviceQueueCreateInfo[2];
    }

    foreach(i, ref queueInfo ; queueInfos)
    {
        queueInfo.queueFamilyIndex = (i == 0) ? queues.graphicsQueue : queues.presentQueue;
        queueInfo.queueCount = 1;
        queueInfo.pQueuePriorities = &priority;
    }

    VkPhysicalDeviceFeatures features;
    VkDeviceCreateInfo info;

    info.pQueueCreateInfos       = queueInfos.ptr;
    info.queueCreateInfoCount    = queueInfos.length32;
    info.pEnabledFeatures        = &features;
    info.enabledLayerCount       = validationLayers.length;
    info.ppEnabledLayerNames     = validationLayers.ptr;
    info.enabledExtensionCount   = requiredDeviceExtensions.length;
    info.ppEnabledExtensionNames = requiredDeviceExtensions.ptr;

    if(VkResult result = vkCreateDevice(physicalDevice, &info, null, &device))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateDevice(): %s", result.to!string.ptr);
        assert(0);
    }

    vkGetDeviceQueue(device, queues.graphicsQueue, 0, &graphicsQueue);
    vkGetDeviceQueue(device, queues.presentQueue, 0, &presentQueue);
}

SwapChainSupportDetails querySwapChainSupport(VkPhysicalDevice device)
{
    SwapChainSupportDetails result;

    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &result.capabilities);
    uint formatCount;
    vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null);

    if(formatCount != 0)
    {
        result.formats = new VkSurfaceFormatKHR[formatCount];
        vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, result.formats.ptr);
    }

    uint presentModeCount;
    vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null);

    if(presentModeCount != 0)
    {
        result.presentModes = new VkPresentModeKHR[presentModeCount];
        vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, result.presentModes.ptr);
    }

    return result;
}

VkSurfaceFormatKHR chooseSwapSurfaceFormat(const(VkSurfaceFormatKHR)[] availableFormats)
{
    if(availableFormats.length == 1 && availableFormats[0].format == VK_FORMAT_UNDEFINED)
    {
        return VkSurfaceFormatKHR(VK_FORMAT_B8G8R8A8_UNORM, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
    }

    foreach(ref availableFormat ; availableFormats)
    {
        if(availableFormat.format == VK_FORMAT_B8G8R8A8_UNORM && availableFormat.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return availableFormat;
        }
    }

    return availableFormats[0];
}

VkPresentModeKHR chooseSwapPresentMode(const(VkPresentModeKHR)[] availablePresentModes)
{
    VkPresentModeKHR bestAlternativeMode = VK_PRESENT_MODE_FIFO_KHR;

    foreach(ref availablePresentMode ; availablePresentModes)
    {
        switch(availablePresentMode)
        {
        case VK_PRESENT_MODE_MAILBOX_KHR:   return VK_PRESENT_MODE_MAILBOX_KHR;
        case VK_PRESENT_MODE_IMMEDIATE_KHR: bestAlternativeMode = VK_PRESENT_MODE_IMMEDIATE_KHR; break;
        default:
        }
    }

    return bestAlternativeMode;
}

VkExtent2D chooseSwapExtent(ref const(VkSurfaceCapabilitiesKHR) capabilities)
{
    import std.algorithm.comparison : min, max;

    if(capabilities.currentExtent.width != uint.max)
    {
        return capabilities.currentExtent;
    }
    else
    {
        VkExtent2D actualExtent = { windowWidth, windowHeight };

        actualExtent.width = max(capabilities.minImageExtent.width, min(capabilities.maxImageExtent.width, actualExtent.width));
        actualExtent.height = max(capabilities.minImageExtent.height, min(capabilities.maxImageExtent.height, actualExtent.height));

        return actualExtent;
    }
}

void createSwapChain()
{
    SwapChainSupportDetails swapChainSupport = querySwapChainSupport(physicalDevice);

    VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
    VkPresentModeKHR   presentMode   = chooseSwapPresentMode(swapChainSupport.presentModes);
    VkExtent2D         extent        = chooseSwapExtent(swapChainSupport.capabilities);

    uint imageCount = swapChainSupport.capabilities.minImageCount + 1;
    if(swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount)
    {
        imageCount = swapChainSupport.capabilities.maxImageCount;
    }

    VkSwapchainCreateInfoKHR info;
    info.surface = surface;
    info.minImageCount = imageCount;
    info.imageFormat = surfaceFormat.format;
    info.imageColorSpace = surfaceFormat.colorSpace;
    info.imageExtent = extent;
    info.imageArrayLayers = 1;
    info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

    info.preTransform = swapChainSupport.capabilities.currentTransform;
    info.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

    info.presentMode = presentMode;
    info.clipped = VK_TRUE;

    if(VkResult result = vkCreateSwapchainKHR(device, &info, null, &swapchain))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateSwapchainKHR(): %s", result.to!string.ptr);
        assert(0);
    }

    swapchainImageFormat = surfaceFormat.format;
    swapchainExtent = extent;

    vkGetSwapchainImagesKHR(device, swapchain, &imageCount, null);
    swapchainImages = new VkImage[imageCount];
    vkGetSwapchainImagesKHR(device, swapchain, &imageCount, swapchainImages.ptr);
}

void cleanupSwapchain()
{
    foreach(swapchainFramebuffer; swapchainFramebuffers)
    {
        vkDestroyFramebuffer(device, swapchainFramebuffer, null);
    }

    vkFreeCommandBuffers(device, commandPool, commandBuffers.length32, commandBuffers.ptr);

    vkDestroyPipeline(device, graphicsPipeline, null);
    vkDestroyPipelineLayout(device, pipelineLayout, null);
    vkDestroyRenderPass(device, renderPass, null);

    foreach(swapchainImageView ; swapchainImageViews)
    {
        vkDestroyImageView(device, swapchainImageView, null);
    }

    vkDestroySwapchainKHR(device, swapchain, null);
}

void recreateSwapchain()
{
    vkDeviceWaitIdle(device);

    cleanupSwapchain();

    createSwapChain();
    createImageViews();
    createRenderPass();
    createGraphicsPipeline();
    createFramebuffers();
    createCommandBuffers();
}

void createImageViews()
{
    swapchainImageViews = new VkImageView[swapchainImages.length];

    foreach(i, image ; swapchainImages)
    {
        VkImageViewCreateInfo info;

        info.image = image;
        info.viewType = VK_IMAGE_VIEW_TYPE_2D;
        info.format = swapchainImageFormat;

        info.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;

        info.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        info.subresourceRange.baseMipLevel = 0;
        info.subresourceRange.levelCount = 1;
        info.subresourceRange.baseArrayLayer = 0;
        info.subresourceRange.layerCount = 1;

        if(VkResult result = vkCreateImageView(device, &info, null, &swapchainImageViews[i]))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateImageView(): %s", result.to!string.ptr);
            assert(0);
        }
    }
}

VkShaderModule createShaderModule(const(void)[] code)
{
    VkShaderModuleCreateInfo info;
    info.codeSize = code.length;
    info.pCode = cast(const(uint)*)code.ptr;

    VkShaderModule result;
    if(VkResult res = vkCreateShaderModule(device, &info, null, &result))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateShaderModule(): %s", res.to!string.ptr);
        assert(0);
    }

    return result;
}

void createRenderPass()
{
    VkSubpassDependency dependency;
    dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;
    dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    VkAttachmentDescription colorAttachment;
    colorAttachment.format = swapchainImageFormat;
    colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    VkAttachmentReference colorAttachmentRef;
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass;
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;


    VkRenderPassCreateInfo renderPassInfo;
    renderPassInfo.attachmentCount = 1;
    renderPassInfo.pAttachments = &colorAttachment;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if(VkResult result = vkCreateRenderPass(device, &renderPassInfo, null, &renderPass))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateRenderPass(): %s", result.to!string.ptr);
        assert(0);
    }

}

void createGraphicsPipeline()
{
    const(void)[] fragFile = import("frag.spv");
    const(void)[] vertFile = import("vert.spv");

    VkShaderModule vertShaderModule = createShaderModule(vertFile);
    scope(exit) vkDestroyShaderModule(device, vertShaderModule, null);

    VkShaderModule fragShaderModule = createShaderModule(fragFile);
    scope(exit) vkDestroyShaderModule(device, fragShaderModule, null);

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShaderModule;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module_ = fragShaderModule;
    shaderStages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vertexInputInfo;

    auto bindingDesc = Vertex.getBindingDescription();
    auto attributeDescs = Vertex.getAttributeDescriptions();

    vertexInputInfo.vertexBindingDescriptionCount = 1;
    vertexInputInfo.pVertexBindingDescriptions = &bindingDesc;

    vertexInputInfo.vertexAttributeDescriptionCount = attributeDescs.length32;
    vertexInputInfo.pVertexAttributeDescriptions = attributeDescs.ptr;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;

    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = VK_FALSE;

    VkViewport viewport;
    viewport.x = 0.0f;
    viewport.y = 0.0f;
    viewport.width = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);
    viewport.minDepth = 0.0f;
    viewport.maxDepth = 1.0f;

    VkRect2D scissor;
    scissor.extent = swapchainExtent;


    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.depthClampEnable = VK_FALSE;
    rasterizer.rasterizerDiscardEnable = VK_FALSE;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0f;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo multisampling;
    multisampling.sampleShadingEnable = VK_FALSE;

    VkPipelineColorBlendAttachmentState colorBlendAttachment;
    colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
    colorBlendAttachment.blendEnable = VK_FALSE;

    VkPipelineColorBlendStateCreateInfo colorBlending;
    colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    colorBlending.logicOpEnable = VK_FALSE;
    colorBlending.attachmentCount = 1;
    colorBlending.pAttachments = &colorBlendAttachment;

    VkDynamicState[2] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.dynamicStateCount = dynamicStates.length;
    dynamicState.pDynamicStates = dynamicStates.ptr;

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;

    if(VkResult result = vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &pipelineLayout))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreatePipelineLayout(): %s", result.to!string.ptr);
        assert(0);
    }

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.stageCount = shaderStages.length;
    pipelineInfo.pStages = shaderStages.ptr;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.layout = pipelineLayout;

    pipelineInfo.renderPass = renderPass;
    pipelineInfo.subpass = 0;

    if(VkResult result = vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &graphicsPipeline))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateGraphicsPipelines(): %s", result.to!string.ptr);
        assert(0);
    }
}

void createFramebuffers()
{
    swapchainFramebuffers = new VkFramebuffer[swapchainImageViews.length];

    foreach(i, imageView ; swapchainImageViews)
    {
        VkImageView[1] attachments =
        [
            imageView,
        ];

        VkFramebufferCreateInfo info;
        info.renderPass = renderPass;
        info.attachmentCount = attachments.length;
        info.pAttachments = attachments.ptr;
        info.width = swapchainExtent.width;
        info.height = swapchainExtent.height;
        info.layers = 1;

        if(VkResult result = vkCreateFramebuffer(device, &info, null, &swapchainFramebuffers[i]))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateFramebuffer(): %s", result.to!string.ptr);
            assert(0);
        }
    }
}

void createCommandPool()
{
    auto queues = findGraphicsQueueIndex(physicalDevice);

    VkCommandPoolCreateInfo poolInfo;
    poolInfo.queueFamilyIndex = queues.graphicsQueue;

    if(VkResult result = vkCreateCommandPool(device, &poolInfo, null, &commandPool))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateCommandPool(): %s", result.to!string.ptr);
        assert(0);
    }
}

void createCommandBuffers()
{
    commandBuffers = new VkCommandBuffer[swapchainFramebuffers.length];

    VkCommandBufferAllocateInfo allocInfo;
    allocInfo.commandPool = commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = commandBuffers.length32;

    if(VkResult result = vkAllocateCommandBuffers(device, &allocInfo, commandBuffers.ptr))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkAllocateCommandBuffers(): %s", result.to!string.ptr);
        assert(0);
    }

    foreach(i, commandBuffer ; commandBuffers)
    {
        VkCommandBufferBeginInfo beginInfo;
        beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

        vkBeginCommandBuffer(commandBuffer, &beginInfo);

        VkRenderPassBeginInfo renderPassInfo = {};
        renderPassInfo.renderPass = renderPass;
        renderPassInfo.framebuffer = swapchainFramebuffers[i];
        renderPassInfo.renderArea.extent = swapchainExtent;

        VkClearValue clearColor;
        clearColor.color = VkClearColorValue([0.0f, 0.0f, 0.0f, 1.0f]);
        renderPassInfo.clearValueCount = 1;
        renderPassInfo.pClearValues = &clearColor;

        vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);

        VkBuffer[] vertexBuffers = [ vertexBuffer ];
        VkDeviceSize[] offsets = [ 0 ];
        vkCmdBindVertexBuffers(commandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
        vkCmdDraw(commandBuffer, vertices.length32, 1, 0, 0);
        vkCmdEndRenderPass(commandBuffer);

        if(VkResult result = vkEndCommandBuffer(commandBuffer))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkEndCommandBuffer(): %s", result.to!string.ptr);
            assert(0);
        }
    }
}

void createSemaphores()
{
    VkSemaphoreCreateInfo semaphoreInfo;

    if(VkResult result = vkCreateSemaphore(device, &semaphoreInfo, null, &imageAvailableSemaphore))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateSemaphore(): %s", result);
        assert(0);
    }

    if(VkResult result = vkCreateSemaphore(device, &semaphoreInfo, null, &renderFinishedSemaphore))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateSemaphore(): %s", result);
        assert(0);
    }
}

void drawFrame()
{
    vkQueueWaitIdle(presentQueue);

    uint imageIndex;
    switch(vkAcquireNextImageKHR(device, swapchain, ulong.max, imageAvailableSemaphore, VK_NULL_HANDLE, &imageIndex))
    {
    case VK_ERROR_OUT_OF_DATE_KHR:
        recreateSwapchain();
        return;
    default:
        assert(0);
    case VK_SUCCESS:
    case VK_SUBOPTIMAL_KHR:
    }

    VkSubmitInfo submitInfo;
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;

    VkSemaphore[1]          waitSemaphores = [ imageAvailableSemaphore ];
    VkPipelineStageFlags[1] waitStages     = [ VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT ];
    submitInfo.waitSemaphoreCount = waitSemaphores.length;
    submitInfo.pWaitSemaphores = waitSemaphores.ptr;
    submitInfo.pWaitDstStageMask = waitStages.ptr;

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffers[imageIndex];

    VkSemaphore[1] signalSemaphores = [ renderFinishedSemaphore ];
    submitInfo.signalSemaphoreCount = signalSemaphores.length;
    submitInfo.pSignalSemaphores = signalSemaphores.ptr;

    if(VkResult result = vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkQueueSubmit(): %s", result);
        assert(0);
    }

    VkPresentInfoKHR presentInfo;
    presentInfo.waitSemaphoreCount = signalSemaphores.length;
    presentInfo.pWaitSemaphores = signalSemaphores.ptr;

    VkSwapchainKHR[1] swapchains = [ swapchain ];
    presentInfo.swapchainCount = swapchains.length;
    presentInfo.pSwapchains = swapchains.ptr;
    presentInfo.pImageIndices = &imageIndex;

    vkQueuePresentKHR(presentQueue, &presentInfo);
}

void createVertexBuffer()
{
    VkBufferCreateInfo bufferInfo;
    bufferInfo.size = Vertex.sizeof * vertices.length;
    bufferInfo.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    if(VkResult result = vkCreateBuffer(device, &bufferInfo, null, &vertexBuffer))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateBuffer(): %s", result.to!string.ptr);
        assert(0);
    }

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(device, vertexBuffer, &memRequirements);

    VkMemoryAllocateInfo allocInfo ;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

    if(VkResult result = vkAllocateMemory(device, &allocInfo, null, &vertexBufferMemory))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkAllocateMemory(): %s", result.to!string.ptr);
        assert(0);
    }

    vkBindBufferMemory(device, vertexBuffer, vertexBufferMemory, 0);

    void* data;
    vkMapMemory(device, vertexBufferMemory, 0, bufferInfo.size, 0, &data);
    data[0 .. cast(uint)bufferInfo.size] = vertices[];
    vkUnmapMemory(device, vertexBufferMemory);
}

uint findMemoryType(uint typeFilter, VkMemoryPropertyFlags properties)
{
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

    foreach(uint i, ref type ; memProperties.memoryTypes[0 .. memProperties.memoryTypeCount])
    {
        if((typeFilter & (1 << i)) && (type.propertyFlags & properties) == properties)
        {
            return i;
        }
    }

    SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "No supported memory type.");
    assert(0);
}

// TODO split into initialize and initializeScenario ?
void load()
{
    int width  = 1920; // todo unhardcode
    int height = 810;



}

void loadShaders()
{
}

void render(ref World world, ref Camera camera)
{
    drawFrame();

}

@nogc nothrow
void doUi()
{

}


private:


enum DefaultTexture
{
    additive,
    multiplicative,
    detail,
    vector
}

struct SimpleWorldVertex
{
    Vec3 position;
    uint color = ~0;
}



void loadEnvironmentShaders()
{

}

void loadModelShaders()
{

}

void loadChicagoShaders()
{

}

void renderOpaqueStructureBsp(ref Camera camera, TagScenarioStructureBsp* sbsp, int lightmapIndex)
{
    assert(0);
}

void renderObject(ref Camera camera, int[] permutations, GObject.Lighting* lighting, TagGbxmodel* tagModel, Mat4x3[] matrices)
{
    assert(0);

}

struct ObjectLightingOptions
{
    bool calculateColorFromSides; // for example use this for an elevator
    bool brighterThanItShouldBe;
}

bool updateObjectLighting(ref World world, Vec3 position, ref GObject.Lighting lighting, ObjectLightingOptions options)
{
    // TODO(IMPLEMENTATION) this still needs work to be correct
    //                      at the very least Distant Light 1 doesn't seem to be 100% correct
    //                      reflection tint as well hasn't been checked

    assert(0);
}

static
void bindTexture2D(int textureIndex, DatumIndex i, int bitmapIndex, DefaultTexture defaultType)
{
    bindTexture(textureIndex, Cache.inst.globals.rasterizerData.default2d.index, bitmapIndex, i, defaultType);
}

static
void bindTextureCube(int textureIndex, DatumIndex i, int bitmapIndex, DefaultTexture defaultType)
{
    bindTexture(textureIndex, Cache.inst.globals.rasterizerData.defaultCubeMap.index, bitmapIndex, i, defaultType);
}

static
void bindTexture(
    int            textureIndex,
    DatumIndex     defaultIndex,
    int            bitmapIndex,
    DatumIndex     tagIndex,
    DefaultTexture defaultType)
{
    assert(0);
}

static
void loadPixelData(Tag.BitmapDataBlock* bitmap, byte[] buffer)
{
    assert(0);
}

void renderImGui()
{
    assert(0);
}
}

// End //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

private ubyte[][uint] gBitmapLoadedPixels;

private ubyte[] grabPixelDataFromBitmap(DatumIndex index, int bitmapIndex)
{
    assert(0);
}

