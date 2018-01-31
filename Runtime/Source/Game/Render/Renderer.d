
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

static void vkCheck(VkResult result, uint line = __LINE__)
{
    import std.conv : to;

    if(result != VK_SUCCESS)
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "Error (%d): %s", line, result.to!string.ptr);
    }
}

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

struct EnvPushConstants
{
    // 128 bytes is minimal support of Vulkan Push Constants
    static assert(this.sizeof <= 128);

    Vec2[5] uvScales;
    Vec4 perpendicularColor;
    Vec4 parallelColor;
    float specularColorControl;
}

struct EnvUnifomBuffer
{
    Mat4 projview;
    Vec3 eyePos;
}

struct ShaderInstance
{
    VkDescriptorSet descriptorSet;
}

struct SwapChainSupportDetails
{
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR[]     formats;
    VkPresentModeKHR[]       presentModes;
}

struct FrameBufferAttachment
{
    VkImage image;
    VkDeviceMemory mem;
    VkImageView view;
    VkFormat format;
}

struct FrameBuffer
{
    uint width;
    uint height;
    VkFramebuffer frameBuffer;
    FrameBufferAttachment albedo, specular, position, normal;
    FrameBufferAttachment depth;
    VkRenderPass renderPass;
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

FixedArray!(VkImage, 3)       swapchainImages;
FixedArray!(VkImageView, 3)   swapchainImageViews;
FixedArray!(VkFramebuffer, 3) swapchainFramebuffers;

VkRenderPass             renderPass;

VkCommandPool            commandPool;
VkCommandBuffer[]        commandBuffers;

VkBuffer                 vertexBuffer;
VkDeviceMemory           vertexBufferMemory;

VkBuffer                 sbspVertexBuffer;
VkDeviceMemory           sbspVertexBufferMemory;
VkBuffer                 lightmapVertexBuffer;
VkDeviceMemory           lightmapVertexBufferMemory;
VkBuffer                 sbspIndexBuffer;
VkDeviceMemory           sbspIndexBufferMemory;

VkDescriptorPool         descriptorPool;

VkBuffer                 envUnifomBuffer;
VkDeviceMemory           envUnifomBufferMemory;

VkDescriptorSetLayout    sceneGlobalsDescriptorSetLayout;
VkDescriptorSet          sceneGlobalsDescriptorSet;

VkDescriptorSetLayout    lightmapDescriptorSetLayout;
VkDescriptorSet          lightmapDescriptorSet;

VkDescriptorSetLayout    sbspEnvDescriptorSetLayout;
VkPipelineLayout         sbspEnvPipelineLayout;
VkPipeline[3][3][3]      sbspEnvPipelines;

FrameBuffer              offscreenFramebuffer;
VkSampler                colorSampler;

VkSemaphore              imageAvailableSemaphore;
VkSemaphore              renderFinishedSemaphore;

ShaderInstance[DatumIndex] shaderInstances;

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

VkCommandBuffer beginSingleTimeCommands()
{
    VkCommandBufferAllocateInfo allocInfo;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandPool = commandPool;
    allocInfo.commandBufferCount = 1;

    VkCommandBuffer commandBuffer;
    vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer);

    VkCommandBufferBeginInfo beginInfo;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

    vkBeginCommandBuffer(commandBuffer, &beginInfo);

    return commandBuffer;
}

void endSingleTimeCommands(VkCommandBuffer commandBuffer)
{
    vkEndCommandBuffer(commandBuffer);

    VkSubmitInfo submitInfo;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;

    vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
    vkQueueWaitIdle(graphicsQueue);

    vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer);
}

void transitionImageLayout(VkImage image, int mipmap, VkImageLayout oldLayout, VkImageLayout newLayout)
{
    VkCommandBuffer command = beginSingleTimeCommands();
    scope(exit) endSingleTimeCommands(command);

    VkImageMemoryBarrier barrier;
    barrier.oldLayout = oldLayout;
    barrier.newLayout = newLayout;
    barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = image;
    barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.baseMipLevel = mipmap;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.layerCount = 1;

    VkPipelineStageFlags sourceStage;
    VkPipelineStageFlags destinationStage;

    if(oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
    {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

        sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destinationStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
    }
    else if(oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
    {
        barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

        sourceStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
        destinationStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    }
    else
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "Invalid transition.");
        assert(0);
    }

    vkCmdPipelineBarrier(
        command,
        sourceStage, destinationStage,
        0,
        0, null,
        0, null,
        1, &barrier
    );
}

void createAttachment(VkFormat format, VkImageUsageFlagBits usage, FrameBufferAttachment* attachment)
{
    VkImageAspectFlags aspectMask;
    VkImageLayout imageLayout;

    attachment.format = format;

    if(usage & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
    {
        aspectMask  = VK_IMAGE_ASPECT_COLOR_BIT;
        imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    }

    if(usage & VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT)
    {
        aspectMask  = VK_IMAGE_ASPECT_DEPTH_BIT | VK_IMAGE_ASPECT_STENCIL_BIT;
        imageLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
    }

    VkImageCreateInfo image;

    image.imageType = VK_IMAGE_TYPE_2D;
    image.format = format;
    image.extent.width = offscreenFramebuffer.width;
    image.extent.height = offscreenFramebuffer.height;
    image.extent.depth = 1;
    image.mipLevels = 1;
    image.arrayLayers = 1;
    image.samples = VK_SAMPLE_COUNT_1_BIT;
    image.tiling = VK_IMAGE_TILING_OPTIMAL;
    image.usage = usage | VK_IMAGE_USAGE_SAMPLED_BIT;


    vkCreateImage(device, &image, null, &attachment.image);

    VkMemoryRequirements memReqs;
    vkGetImageMemoryRequirements(device, attachment.image, &memReqs);

    VkMemoryAllocateInfo memAlloc;
    memAlloc.allocationSize = memReqs.size;
    memAlloc.memoryTypeIndex = findMemoryType(memReqs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

    vkAllocateMemory(device, &memAlloc, null, &attachment.mem);
    vkBindImageMemory(device, attachment.image, attachment.mem, 0);

    VkImageViewCreateInfo imageView;
    imageView.viewType = VK_IMAGE_VIEW_TYPE_2D;
    imageView.format = format;
    imageView.subresourceRange.aspectMask = aspectMask;
    imageView.subresourceRange.baseMipLevel = 0;
    imageView.subresourceRange.levelCount = 1;
    imageView.subresourceRange.baseArrayLayer = 0;
    imageView.subresourceRange.layerCount = 1;
    imageView.image = attachment.image;

    vkCreateImageView(device, &imageView, null, &attachment.view);
}

VkFormat findSupportedFormat(VkFormat[] candidates, VkImageTiling tiling, VkFormatFeatureFlags features)
{
    foreach(VkFormat format ; candidates)
    {
        VkFormatProperties props;
        vkGetPhysicalDeviceFormatProperties(physicalDevice, format, &props);

        if(tiling == VK_IMAGE_TILING_LINEAR && (props.linearTilingFeatures & features) == features)
        {
            return format;
        }
        else if(tiling == VK_IMAGE_TILING_OPTIMAL && (props.optimalTilingFeatures & features) == features)
        {
            return format;
        }
    }

    assert(0);
}

VkFormat findDepthFormat()
{
    VkFormat[3] formats = [ VK_FORMAT_D32_SFLOAT, VK_FORMAT_D32_SFLOAT_S8_UINT, VK_FORMAT_D24_UNORM_S8_UINT ];
    return findSupportedFormat(formats, VK_IMAGE_TILING_OPTIMAL, VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT);
}

void createOffscreenFramebuffer()
{
    offscreenFramebuffer.width = 1920;
    offscreenFramebuffer.height = 1080;

    createAttachment(VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.albedo);
    createAttachment(VK_FORMAT_R8G8B8A8_UNORM, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.specular);
    createAttachment(VK_FORMAT_R16G16B16A16_SFLOAT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.position);
    createAttachment(VK_FORMAT_R16G16B16A16_SFLOAT, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.normal);

    VkFormat attDepthFormat = findDepthFormat();

    createAttachment(attDepthFormat, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, &offscreenFramebuffer.depth);

    VkAttachmentDescription[5] attachmentDescs;

    foreach(i, ref attachmentDesc ; attachmentDescs)
    {
        attachmentDesc.samples        = VK_SAMPLE_COUNT_1_BIT;
        attachmentDesc.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
        attachmentDesc.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
        attachmentDesc.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachmentDesc.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;

        if(i == attachmentDescs.length - 1)
        {
            attachmentDesc.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            attachmentDesc.finalLayout   = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
        }
        else
        {
            attachmentDesc.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            attachmentDesc.finalLayout   = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        }
    }

    // Formats
    attachmentDescs[0].format = offscreenFramebuffer.albedo.format;
    attachmentDescs[1].format = offscreenFramebuffer.specular.format;
    attachmentDescs[2].format = offscreenFramebuffer.position.format;
    attachmentDescs[3].format = offscreenFramebuffer.normal.format;
    attachmentDescs[4].format = offscreenFramebuffer.depth.format;

    VkAttachmentReference[4] colorReferences =
    [
        VkAttachmentReference(0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL),
        VkAttachmentReference(1, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL),
        VkAttachmentReference(2, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL),
        VkAttachmentReference(3, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL),
    ];

    VkAttachmentReference depthReference;
    depthReference.attachment = 4;
    depthReference.layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    VkSubpassDescription subpass;
    subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.pColorAttachments = colorReferences.ptr;
    subpass.colorAttachmentCount = colorReferences.length32;
    subpass.pDepthStencilAttachment = &depthReference;

    VkSubpassDependency[2] dependencies;

    dependencies[0].srcSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[0].dstSubpass = 0;
    dependencies[0].srcStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
    dependencies[0].dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependencies[0].srcAccessMask = VK_ACCESS_MEMORY_READ_BIT;
    dependencies[0].dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    dependencies[0].dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT;

    dependencies[1].srcSubpass = 0;
    dependencies[1].dstSubpass = VK_SUBPASS_EXTERNAL;
    dependencies[1].srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependencies[1].dstStageMask = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
    dependencies[1].srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    dependencies[1].dstAccessMask = VK_ACCESS_MEMORY_READ_BIT;
    dependencies[1].dependencyFlags = VK_DEPENDENCY_BY_REGION_BIT;

    VkRenderPassCreateInfo renderPassInfo;
    renderPassInfo.pAttachments = attachmentDescs.ptr;
    renderPassInfo.attachmentCount = attachmentDescs.length32;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = dependencies.length32;
    renderPassInfo.pDependencies = dependencies.ptr;

    vkCreateRenderPass(device, &renderPassInfo, null, &offscreenFramebuffer.renderPass);

    VkImageView[5] attachments =
    [
        offscreenFramebuffer.albedo.view,
        offscreenFramebuffer.specular.view,
        offscreenFramebuffer.position.view,
        offscreenFramebuffer.normal.view,
        offscreenFramebuffer.depth.view,
    ];

    VkFramebufferCreateInfo fbufCreateInfo;
    fbufCreateInfo.renderPass = offscreenFramebuffer.renderPass;
    fbufCreateInfo.pAttachments = attachments.ptr;
    fbufCreateInfo.attachmentCount = attachments.length32;
    fbufCreateInfo.width = offscreenFramebuffer.width;
    fbufCreateInfo.height = offscreenFramebuffer.height;
    fbufCreateInfo.layers = 1;
    vkCreateFramebuffer(device, &fbufCreateInfo, null, &offscreenFramebuffer.frameBuffer);

    VkSamplerCreateInfo sampler;
    sampler.magFilter = VK_FILTER_NEAREST;
    sampler.minFilter = VK_FILTER_NEAREST;
    sampler.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
    sampler.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeV = sampler.addressModeU;
    sampler.addressModeW = sampler.addressModeU;
    sampler.mipLodBias = 0.0f;
    sampler.maxAnisotropy = 1.0f;
    sampler.minLod = 0.0f;
    sampler.maxLod = 1.0f;
    sampler.borderColor = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
    vkCreateSampler(device, &sampler, null, &colorSampler);
}

void createBuffer(
    VkDeviceSize          size,
    VkBufferUsageFlags    usage,
    VkMemoryPropertyFlags properties,
    ref VkBuffer          buffer,
    ref VkDeviceMemory    bufferMemory)
{
    VkBufferCreateInfo bufferInfo;
    bufferInfo.size = size;
    bufferInfo.usage = usage;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    if(VkResult result = vkCreateBuffer(device, &bufferInfo, null, &buffer))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateBuffer(): %s", result.to!string.ptr);
        assert(0);
    }

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(device, buffer, &memRequirements);

    VkMemoryAllocateInfo allocInfo;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, properties);

    if(VkResult result = vkAllocateMemory(device, &allocInfo, null, &bufferMemory))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkAllocateMemory(): %s", result.to!string.ptr);
        assert(0);
    }

    vkBindBufferMemory(device, buffer, bufferMemory, 0);
}

uint debugCallback(
    VkDebugReportFlagsEXT      flags,
    VkDebugReportObjectTypeEXT objectType,
    ulong                      object,
    size_t                     location,
    int                        messageCode,
    const(char)*               pLayerPrefix,
    const(char)*               pMessage,
    void*                      pUserData)
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
    features.textureCompressionBC = true;

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

    swapchainImages.resize(imageCount);
    vkGetSwapchainImagesKHR(device, swapchain, &imageCount, swapchainImages.ptr);
}

void cleanupSwapchain()
{
    foreach(swapchainFramebuffer; swapchainFramebuffers)
    {
        vkDestroyFramebuffer(device, swapchainFramebuffer, null);
    }

    vkFreeCommandBuffers(device, commandPool, commandBuffers.length32, commandBuffers.ptr);

    // vkDestroyPipeline(device, graphicsPipeline, null);
    // vkDestroyPipelineLayout(device, pipelineLayout, null);
    // vkDestroyRenderPass(device, renderPass, null);

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
    // createImageViews();
    // createRenderPass();
    // createGraphicsPipeline();
    // createFramebuffers();
    // createCommandBuffers();
}

void createImageViews()
{
    swapchainImageViews.resize(swapchainImages.length);

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

// void createRenderPass()
// {
//     VkSubpassDependency dependency;
//     dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
//     dependency.dstSubpass = 0;
//     dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
//     dependency.srcAccessMask = 0;
//     dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
//     dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

//     VkAttachmentDescription colorAttachment;
//     colorAttachment.format = swapchainImageFormat;
//     colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
//     colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
//     colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
//     colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
//     colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

//     VkAttachmentReference colorAttachmentRef;
//     colorAttachmentRef.attachment = 0;
//     colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

//     VkSubpassDescription subpass;
//     subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
//     subpass.colorAttachmentCount = 1;
//     subpass.pColorAttachments = &colorAttachmentRef;


//     VkRenderPassCreateInfo renderPassInfo;
//     renderPassInfo.attachmentCount = 1;
//     renderPassInfo.pAttachments = &colorAttachment;
//     renderPassInfo.subpassCount = 1;
//     renderPassInfo.pSubpasses = &subpass;
//     renderPassInfo.dependencyCount = 1;
//     renderPassInfo.pDependencies = &dependency;

//     if(VkResult result = vkCreateRenderPass(device, &renderPassInfo, null, &renderPass))
//     {
//         SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateRenderPass(): %s", result.to!string.ptr);
//         assert(0);
//     }

// }

void createDescriptorPool()
{
    VkDescriptorPoolSize[2] poolSize =
    [
        VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 256),
        VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 256),
    ];

    VkDescriptorPoolCreateInfo poolInfo;
    poolInfo.poolSizeCount = poolSize.length32;
    poolInfo.pPoolSizes = poolSize.ptr;
    poolInfo.maxSets = 128;

    vkCheck(vkCreateDescriptorPool(device, &poolInfo, null, &descriptorPool));

}

void createEnvUniformBuffer()
{
    createBuffer(EnvUnifomBuffer.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, envUnifomBuffer, envUnifomBufferMemory);
}

void updateUniformBuffer(ref Camera camera)
{
    EnvUnifomBuffer uniform;

    uniform.projview = camera.viewproj;
    uniform.eyePos = camera.position;

    void* data;
    vkMapMemory(device, envUnifomBuffer, 0, EnvUnifomBuffer.sizeof, 0, &data);
    data[0 .. EnvUnifomBuffer.sizeof] = (&uniform)[0 .. 1];
    vkUnmapMemory(device, envUnifomBuffer);
}

void createUniformDescriptorSet()
{
    VkDescriptorSetLayout[1] layouts =
    [
        sceneGlobalsDescriptorSetLayout,
    ];

    VkDescriptorSetAllocateInfo allocInfo;
    allocInfo.descriptorPool = descriptorPool;
    allocInfo.descriptorSetCount = layouts.length32;
    allocInfo.pSetLayouts = layouts.ptr;

    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &sceneGlobalsDescriptorSet));

    VkDescriptorBufferInfo bufferInfo;
    bufferInfo.buffer = envUnifomBuffer;
    bufferInfo.offset = 0;
    bufferInfo.range = EnvUnifomBuffer.sizeof;

    VkWriteDescriptorSet descriptorWrite;

    descriptorWrite.dstSet = sceneGlobalsDescriptorSet;
    descriptorWrite.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    descriptorWrite.descriptorCount = 1;
    descriptorWrite.pBufferInfo = &bufferInfo;

    vkUpdateDescriptorSets(device, 1, &descriptorWrite, 0, null);
}

void createSceneGlobalsDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[1] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 0, VK_SHADER_STAGE_ALL_GRAPHICS),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &sceneGlobalsDescriptorSetLayout));
}

void createEnvDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[7] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(2, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(3, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(4, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(5, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(6, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &sbspEnvDescriptorSetLayout));
}

void createLightmapDescriptorSetLayout(TagScenarioStructureBsp* sbsp)
{
    FixedArray!(VkDescriptorSetLayoutBinding, 96) setLayoutBindings;

    auto tagBitmap = Cache.get!TagBitmap(sbsp.lightmapsBitmap.index);

    foreach(i ; 0 .. tagBitmap.bitmaps.size)
    {
        setLayoutBindings.add(
            VkDescriptorSetLayoutBinding(i, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 0, VK_SHADER_STAGE_FRAGMENT_BIT));
    }

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &lightmapDescriptorSetLayout));
}

void createLightmapDescriptorSet(TagScenarioStructureBsp* sbsp)
{
    VkDescriptorSetLayout[1] layouts =
    [
        lightmapDescriptorSetLayout,
    ];

    VkDescriptorSetAllocateInfo allocInfo;
    allocInfo.descriptorPool = descriptorPool;
    allocInfo.descriptorSetCount = layouts.length32;
    allocInfo.pSetLayouts = layouts.ptr;

    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &lightmapDescriptorSet));

    VkDescriptorBufferInfo bufferInfo;
    bufferInfo.buffer = envUnifomBuffer;
    bufferInfo.offset = 0;
    bufferInfo.range = EnvUnifomBuffer.sizeof;

    FixedArray!(VkWriteDescriptorSet, 96) descriptorWrites;

    auto tagBitmap = Cache.get!TagBitmap(sbsp.lightmapsBitmap.index);

    foreach(i, ref tagBitmapData ; tagBitmap.bitmaps)
    {
        // descriptorWrite.dstSet = lightmapDescriptorSet;
        // descriptorWrite.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        // descriptorWrite.descriptorCount = 1;
        // descriptorWrite.pBufferInfo = &bufferInfo;
    }

    assert(0);

    vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);
}

void createBaseSbspEnvPipeline(
    VkPipelineShaderStageCreateInfo[] shaderStages,
    ref VkPipelineLayout              pipelineLayout,
    ref VkPipeline                    graphicsPipeline)
{
    VkPipelineVertexInputStateCreateInfo vertexInputInfo;

    VkVertexInputBindingDescription[2] bindingDesc =
    [
        VkVertexInputBindingDescription(0, TagBspVertex.sizeof,         VK_VERTEX_INPUT_RATE_VERTEX),
        VkVertexInputBindingDescription(1, TagBspLightmapVertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX),
    ];

    VkVertexInputAttributeDescription[7] attributeDescs =
    [
        VkVertexInputAttributeDescription(0, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.position.offsetof),
        VkVertexInputAttributeDescription(1, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.normal.offsetof),
        VkVertexInputAttributeDescription(2, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.binormal.offsetof),
        VkVertexInputAttributeDescription(3, 0, VK_FORMAT_R32G32B32_SFLOAT, TagBspVertex.tangent.offsetof),
        VkVertexInputAttributeDescription(4, 0, VK_FORMAT_R32G32_SFLOAT,    TagBspVertex.coord.offsetof),
        VkVertexInputAttributeDescription(5, 1, VK_FORMAT_R32G32B32_SFLOAT, TagBspLightmapVertex.normal.offsetof),
        VkVertexInputAttributeDescription(6, 1, VK_FORMAT_R32G32_SFLOAT,    TagBspVertex.coord.offsetof),
    ];

    vertexInputInfo.vertexBindingDescriptionCount   = bindingDesc.length32;
    vertexInputInfo.pVertexBindingDescriptions      = bindingDesc.ptr;
    vertexInputInfo.vertexAttributeDescriptionCount = attributeDescs.length32;
    vertexInputInfo.pVertexAttributeDescriptions    = attributeDescs.ptr;

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

    VkPipelineColorBlendAttachmentState[4] colorBlendAttachments;

    foreach(ref colorBlendAttachment ; colorBlendAttachments)
    {
        colorBlendAttachment.colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT |
            VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT |
            VK_COLOR_COMPONENT_A_BIT;
    }

    VkPipelineColorBlendStateCreateInfo colorBlending;
    colorBlending.logicOpEnable = VK_FALSE;
    colorBlending.attachmentCount = colorBlendAttachments.length32;
    colorBlending.pAttachments = colorBlendAttachments.ptr;

    VkDynamicState[2] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.dynamicStateCount = dynamicStates.length;
    dynamicState.pDynamicStates = dynamicStates.ptr;

    VkPipelineDepthStencilStateCreateInfo depthStencilState;
    depthStencilState.depthTestEnable = true;
    depthStencilState.depthWriteEnable = true;
    depthStencilState.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;

    VkDescriptorSetLayout[2] descriptorSetLayouts =
    [
        sceneGlobalsDescriptorSetLayout,
        sbspEnvDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_ALL_GRAPHICS, 0, EnvPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayoutCount = descriptorSetLayouts.length32;
    pipelineLayoutInfo.pSetLayouts = descriptorSetLayouts.ptr;
    pipelineLayoutInfo.pushConstantRangeCount = pushConstantRanges.length32;
    pipelineLayoutInfo.pPushConstantRanges = pushConstantRanges.ptr;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &pipelineLayout));

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.flags = VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
    pipelineInfo.stageCount = shaderStages.length32;
    pipelineInfo.pStages = shaderStages.ptr;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pDepthStencilState = &depthStencilState;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.layout = pipelineLayout;

    pipelineInfo.renderPass = offscreenFramebuffer.renderPass;
    pipelineInfo.subpass = 0;

    vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &graphicsPipeline));

}

void createSbspEnvPipelines()
{
    static const(void)[][3][3][3] createEnvFragBinaries()
    {
        import std.conv : to;

        const(void)[][3][3][3] result;

        static foreach(type ; 0 .. 2)
        static foreach(detail ; 0 .. 2)
        static foreach(micro ; 0 .. 2)
        {
            result[type][detail][micro]
                = mixin("import(\"Env-frag-" ~ type.to!string ~ "-" ~ detail.to!string ~ "-" ~ micro.to!string ~ ".spv\")");
        }

        return result;
    }

    static immutable void[][3][3][3] fragBinaries = createEnvFragBinaries();
    static immutable void[] vertBinary = import("Env-vert.spv");

    VkShaderModule vertShaderModule = createShaderModule(vertBinary);
    scope(exit) vkDestroyShaderModule(device, vertShaderModule, null);

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShaderModule;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].pName = "main";


    foreach(type ; 0 .. 2)
    foreach(detail ; 0 .. 2)
    foreach(micro ; 0 .. 2)
    {
        VkShaderModule fragShaderModule = createShaderModule(fragBinaries[type][detail][micro]);
        scope(exit) vkDestroyShaderModule(device, fragShaderModule, null);

        shaderStages[1].module_ = fragShaderModule;

        if(type == 0 && detail == 0 && micro == 0)
        {
            createBaseSbspEnvPipeline(shaderStages, sbspEnvPipelineLayout, sbspEnvPipelines[type][detail][micro]);
            break;
        }

        VkGraphicsPipelineCreateInfo pipelineInfo;
        pipelineInfo.flags = VK_PIPELINE_CREATE_DERIVATIVE_BIT;
        pipelineInfo.stageCount = shaderStages.length32;
        pipelineInfo.pStages = shaderStages.ptr;

        pipelineInfo.basePipelineHandle = sbspEnvPipelines[0][0][0];

        if(VkResult result = vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &sbspEnvPipelines[type][detail][micro]))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateGraphicsPipelines(): %s", result.to!string.ptr);
            assert(0);
        }
    }

}

// void createFramebuffers()
// {
//     swapchainFramebuffers = new VkFramebuffer[swapchainImageViews.length];

//     foreach(i, imageView ; swapchainImageViews)
//     {
//         VkImageView[1] attachments =
//         [
//             imageView,
//         ];

//         VkFramebufferCreateInfo info;
//         info.renderPass = renderPass;
//         info.attachmentCount = attachments.length;
//         info.pAttachments = attachments.ptr;
//         info.width = swapchainExtent.width;
//         info.height = swapchainExtent.height;
//         info.layers = 1;

//         if(VkResult result = vkCreateFramebuffer(device, &info, null, &swapchainFramebuffers[i]))
//         {
//             SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateFramebuffer(): %s", result.to!string.ptr);
//             assert(0);
//         }
//     }
// }

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

    vkCheck(vkAllocateCommandBuffers(device, &allocInfo, commandBuffers.ptr));
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

void createVertexBuffer(T)(T[] vertices, ref VkBuffer vertexBuffer, ref VkDeviceMemory vertexBufferMemory)
{
    uint bufferSize = cast(uint)T.sizeof * vertices.length32;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;
    createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, stagingBuffer, stagingBufferMemory);
    scope(exit)
    {
        vkDestroyBuffer(device, stagingBuffer, null);
        vkFreeMemory(device, stagingBufferMemory, null);
    }

    void* data;
    vkMapMemory(device, stagingBufferMemory, 0, bufferSize, 0, &data);
    data[0 .. bufferSize] = vertices[];
    vkUnmapMemory(device, stagingBufferMemory);

    createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, vertexBuffer, vertexBufferMemory);
    copyBuffer(stagingBuffer, vertexBuffer, bufferSize);

    vkBindBufferMemory(device, vertexBuffer, vertexBufferMemory, 0);
}

void copyBuffer(VkBuffer srcBuffer, VkBuffer dstBuffer, VkDeviceSize size)
{
    VkCommandBuffer commandBuffer = beginSingleTimeCommands();

    VkBufferCopy copyRegion;
    copyRegion.size = size;
    vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

    endSingleTimeCommands(commandBuffer);
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

void createSbspVertexBuffer()
{
    TagScenario* scenario = Cache.inst.scenario();
    TagScenarioStructureBsp* sbsp = Cache.get!TagScenarioStructureBsp(scenario.structureBsps[0].structureBsp);

    TagBspVertex[] bspVertices;
    TagBspLightmapVertex[] lightmapBspVertices;

    structureVertexIndexOffsets.length = sbsp.lightmaps.size;

    foreach(i, ref lightmap ; sbsp.lightmaps)
    {
        structureVertexIndexOffsets[i].length = lightmap.materials.size;

        foreach(j, ref material ; lightmap.materials)
        {
            structureVertexIndexOffsets[i][j] = bspVertices.length32;

            uint vertexCount       = material.vertexBuffers[0].count;
            TagBspVertex* vertices = material.uncompressedVertices.dataAs!TagBspVertex;

            bspVertices         ~= vertices[0 .. vertexCount];
            lightmapBspVertices ~= (cast(TagBspLightmapVertex*)&vertices[vertexCount])[0 .. vertexCount];
        }
    }

    createVertexBuffer(bspVertices, sbspVertexBuffer, sbspVertexBufferMemory);
    createVertexBuffer(lightmapBspVertices, lightmapVertexBuffer, lightmapVertexBufferMemory);

    // Index buffer

    uint bufferSize = cast(uint)sbsp.surfaces[0].sizeof * sbsp.surfaces.size;

    VkBuffer stagingBuffer;
    VkDeviceMemory stagingBufferMemory;
    createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        stagingBuffer, stagingBufferMemory);

    scope(exit)
    {
        vkDestroyBuffer(device, stagingBuffer, null);
        vkFreeMemory(device, stagingBufferMemory, null);
    }

    void* data;
    vkMapMemory(device, stagingBufferMemory, 0, bufferSize, 0, &data);
    data[0 .. bufferSize] = sbsp.surfaces[];
    vkUnmapMemory(device, stagingBufferMemory);

    createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, sbspIndexBuffer, sbspIndexBufferMemory);

    copyBuffer(stagingBuffer, sbspIndexBuffer, bufferSize);

}

void initialize(SDL_Window* window, TagScenarioStructureBsp* sbsp)
{
    createInstance(window);
    setupDebugCallback();
    createSurface(window);
    pickPhysicalDevice();
    createLogicalDevice();

    createSwapChain();
    createImageViews();
    // createRenderPass();
    createOffscreenFramebuffer();

    createDescriptorPool();

    createSceneGlobalsDescriptorSetLayout();
    createLightmapDescriptorSetLayout(sbsp);
    createEnvDescriptorSetLayout();

    createSbspEnvPipelines();

    createSbspVertexBuffer();
    createEnvUniformBuffer();
    createUniformDescriptorSet();
    createLightmapDescriptorSet(sbsp);

    createCommandPool();
    createSemaphores();
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

    VkSemaphore[1]          waitSemaphores = [ imageAvailableSemaphore ];
    VkPipelineStageFlags[1] waitStages     = [ VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT ];
    submitInfo.waitSemaphoreCount = waitSemaphores.length;
    submitInfo.pWaitSemaphores = waitSemaphores.ptr;
    submitInfo.pWaitDstStageMask = waitStages.ptr;

    auto commandBuffer = commandBuffers[imageIndex];

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;

    // Build Command Buffer

    VkCommandBufferBeginInfo beginInfo;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

    vkBeginCommandBuffer(commandBuffer, &beginInfo);

    VkRenderPassBeginInfo renderPassInfo;
    renderPassInfo.renderPass = offscreenFramebuffer.renderPass;
    renderPassInfo.framebuffer = offscreenFramebuffer.frameBuffer;
    renderPassInfo.renderArea.extent = swapchainExtent;

    VkClearValue[5] clearColors =
    [
        VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])),
        VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])),
        VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])),
        VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 0.0f])),
        VkClearValue(),
    ];

    clearColors[$ - 1].depthStencil = VkClearDepthStencilValue(1.0f, 0);

    renderPassInfo.clearValueCount = clearColors.length32;
    renderPassInfo.pClearValues = clearColors.ptr;

    vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

    updateUniformBuffer(camera);

    VkBuffer[2] vertexBuffers = [ sbspVertexBuffer, lightmapVertexBuffer ];
    VkDeviceSize[1] offsets = [ 0 ];
    vkCmdBindVertexBuffers(commandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
    vkCmdBindIndexBuffer(commandBuffer, sbspIndexBuffer, 0, VK_INDEX_TYPE_UINT16);

    auto sbsp = world.getCurrentSbsp;

    foreach(int i, ref lightmap ; sbsp.lightmaps)
    {
        if(lightmap.bitmap != indexNone)
        {
            renderOpaqueStructureBsp(camera, sbsp, i);
        }
    }

    vkCmdEndRenderPass(commandBuffer);
    vkCheck(vkEndCommandBuffer(commandBuffer));

    VkSemaphore[1] signalSemaphores = [ renderFinishedSemaphore ];
    submitInfo.signalSemaphoreCount = signalSemaphores.length;
    submitInfo.pSignalSemaphores = signalSemaphores.ptr;

    if(VkResult result = vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkQueueSubmit(): %s", result);
        assert(0);
    }

    // Queue Present for Swapchain

    VkPresentInfoKHR presentInfo;
    presentInfo.waitSemaphoreCount = signalSemaphores.length;
    presentInfo.pWaitSemaphores = signalSemaphores.ptr;

    VkSwapchainKHR[1] swapchains = [ swapchain ];
    presentInfo.swapchainCount = swapchains.length;
    presentInfo.pSwapchains = swapchains.ptr;
    presentInfo.pImageIndices = &imageIndex;

    vkQueuePresentKHR(presentQueue, &presentInfo);

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

Array!(Array!uint) structureVertexIndexOffsets;

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

void bindTexture2D(int textureIndex, DatumIndex i, int bitmapIndex, DefaultTexture defaultType)
{
    bindTexture(textureIndex, Cache.inst.globals.rasterizerData.default2d.index, bitmapIndex, i, defaultType);
}

void bindTextureCube(int textureIndex, DatumIndex i, int bitmapIndex, DefaultTexture defaultType)
{
    bindTexture(textureIndex, Cache.inst.globals.rasterizerData.defaultCubeMap.index, bitmapIndex, i, defaultType);
}

void bindTexture(
    int            textureIndex,
    DatumIndex     defaultIndex,
    int            bitmapIndex,
    DatumIndex     tagIndex,
    DefaultTexture defaultType)
{
    Tag.BitmapDataBlock* bitmap;

    if(tagIndex == DatumIndex.none)
    {
        bitmap = &Cache.get!TagBitmap(defaultIndex).bitmaps[int(defaultType)];
    }
    else
    {
        bitmap = &Cache.get!TagBitmap(tagIndex).bitmaps[bitmapIndex];
    }

    if(bitmap.glTexture == indexNone)
    {
        byte[] buffer = new byte[](bitmap.pixelsSize);

        if(bitmap.flags.externalPixelData) Cache.inst.bitmapCache.read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);
        else                               Cache.inst            .read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);

        loadPixelData(bitmap, buffer);
    }

    assert(0);
}

void loadPixelData(Tag.BitmapDataBlock* bitmap, byte[] buffer)
{
    import Game.Render.Private.Pixels;

    if(bitmap.glTexture != indexNone || !pixelFormatSupported(bitmap.format))
    {
        return;
    }

    switch(bitmap.type)
    {
    default:
        bitmap.glTexture = 0;
        return;
    case TagEnums.BitmapType.texture2d:

        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        createBuffer(buffer.length32, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, stagingBuffer, stagingBufferMemory);
        scope(exit)
        {
            vkDestroyBuffer(device, stagingBuffer, null);
            vkFreeMemory(device, stagingBufferMemory, null);
        }

        void* data;
        vkMapMemory(device, stagingBufferMemory, 0, buffer.length32, 0, &data);
        data[0 .. buffer.length32] = buffer[];
        vkUnmapMemory(device, stagingBufferMemory);

        VkImage image;
        VkDeviceMemory imageMemory;

        VkImageCreateInfo imageInfo;

        imageInfo.imageType     = VK_IMAGE_TYPE_2D;
        imageInfo.extent.width  = bitmap.width;
        imageInfo.extent.height = bitmap.height;
        imageInfo.extent.depth  = 1;
        imageInfo.mipLevels     = bitmap.mipmapCount + 1;
        imageInfo.arrayLayers   = 1;
        imageInfo.format        = getPixelFormat(bitmap.format);
        imageInfo.tiling        = VK_IMAGE_TILING_OPTIMAL;
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage         = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
        imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT;
        imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;

        vkCreateImage(device, &imageInfo, null, &image);

        VkMemoryRequirements memRequirements;
        vkGetImageMemoryRequirements(device, image, &memRequirements);

        VkMemoryAllocateInfo allocInfo;
        allocInfo.allocationSize  = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        vkAllocateMemory(device, &allocInfo, null, &imageMemory);
        vkBindImageMemory(device, image, imageMemory, 0);

        uint offset = 0;
        foreach(i ; 0 .. bitmap.mipmapCount + 1)
        {
            uint width  = max(1, bitmap.width  << i);
            uint height = max(1, bitmap.height << i);

            transitionImageLayout(image, i, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

            VkCommandBuffer commandBuffer = beginSingleTimeCommands();

            VkBufferImageCopy region;
            region.bufferOffset                = offset;
            region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            region.imageSubresource.mipLevel   = i;
            region.imageSubresource.layerCount = 1;
            region.imageExtent                 = VkExtent3D(width, height, 1);

            vkCmdCopyBufferToImage(commandBuffer, stagingBuffer, image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
            endSingleTimeCommands(commandBuffer);

            transitionImageLayout(image, i, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

            offset += pixelFormatSize(bitmap.format, width, height);
        }

        VkImageViewCreateInfo viewCreateInfo;

        // create view

        assert(0); // Store vk image somewhere
        break;
    }

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

