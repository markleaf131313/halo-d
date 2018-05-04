
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
import Game.Profiler;
import Game.Tags;
import Game.World;

struct Renderer
{

enum vkMinSupportedPushConstantSize = 128;

@disable this(this);

static void vkCheck(VkResult result, uint line = __LINE__)
{
    import std.conv : to;

    if(result != VK_SUCCESS)
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "Error (%d): %s", line, result.to!string.ptr);
    }
}

struct ImguiVertex
{
    static assert(this.sizeof == 0x14);

    Vec2 position;
    Vec2 coord;
    uint color;

    static VkVertexInputBindingDescription getBindingDescription()
    {
        VkVertexInputBindingDescription binding;

        binding.binding = 0;
        binding.stride = this.sizeof;
        binding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

        return binding;
    }

    static VkVertexInputAttributeDescription[3] getAttributeDescriptions()
    {
        VkVertexInputAttributeDescription[3] descs;

        descs[0].binding = 0;
        descs[0].location = 0;
        descs[0].format = VK_FORMAT_R32G32_SFLOAT;
        descs[0].offset = position.offsetof;

        descs[1].binding = 0;
        descs[1].location = 1;
        descs[1].format = VK_FORMAT_R32G32_SFLOAT;
        descs[1].offset = coord.offsetof;

        descs[2].binding = 0;
        descs[2].location = 2;
        descs[2].format = VK_FORMAT_R8G8B8A8_UNORM;
        descs[2].offset = color.offsetof;

        return descs;
    }
}

struct ImguiPushConstants
{
    static assert(this.sizeof <= vkMinSupportedPushConstantSize);

    Vec2 scale;
    Vec2 translate;
}

struct TexVertex
{
    Vec3 pos;
    Vec2 coord;

    static VkVertexInputBindingDescription getBindingDescription()
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
        descs[0].format = VK_FORMAT_R32G32B32_SFLOAT;
        descs[0].offset = pos.offsetof;

        descs[1].binding = 0;
        descs[1].location = 1;
        descs[1].format = VK_FORMAT_R32G32_SFLOAT;
        descs[1].offset = coord.offsetof;

        return descs;
    }

}

struct EnvPushConstants
{
    static assert(this.sizeof <= vkMinSupportedPushConstantSize);

    ColorArgb perpendicularColor;
    ColorArgb parallelColor;
    Vec2[5] uvScales;
    float specularColorControl;
    uint lightmapIndex;
}

struct EnvUnifomBuffer
{
    Mat4 projview;
    Vec3 eyePos;
}

struct ModelPushConstants
{
    static assert(this.sizeof <= vkMinSupportedPushConstantSize);

    struct DistantLight
    {
    align(16):
        ColorRgb color;
        Vec3 direction;
    }

align(16):
    Vec2[2] uvScales;
    ColorRgb perpendicularColor;
    ColorRgb parallelColor;

    ColorRgb ambientColor;

    DistantLight[2] distantLights;
}

struct ModelUniformBuffer
{
    Mat4[32] matrices; // TODO make Mat4x3
}

struct ChicagoPushConstants
{
    static assert(this.sizeof <= vkMinSupportedPushConstantSize);

    Vec4[4] uvTransforms = Vec4(0.0f);
    Vec4i   colorBlendFunc;
    Vec4i   alphaBlendFunc;
}

struct ShaderInstance
{
    VkDescriptorSet descriptorSet;
}

struct Texture
{
    VkImage        image;
    VkDeviceMemory imageMemory;
    VkImageView    imageView;
    VkSampler      sampler;
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

    VkExtent2D extent()
    {
        return VkExtent2D(width, height);
    }
}

struct FrameData
{
    struct UniformBuffer
    {
        VkDevice device;
        VkBuffer buffer;
        VkDeviceMemory bufferMemory;
        VkDescriptorSet descriptorSet;
        uint used;
        uint size;

        void* mapped;

        void mapMemory()
        {
            assert(mapped is null);
            vkMapMemory(device, bufferMemory, 0, size, 0, &mapped);
        }

        void unmapMemory()
        {
            // TODO flush memory, since it isn't coherent ?
            vkUnmapMemory(device, bufferMemory);
            mapped = null;
        }

        uint appendAligned(T)(ref T data, uint aligned = 0x100)
        {
            uint offset = (used + aligned - 1) & ~(aligned - 1);

            mapped[offset .. offset + sizeof32!T] = (&data)[0 .. 1];
            used = offset + sizeof32!T;

            return offset;
        }
    }

    struct Buffer
    {
        VkDevice device;
        VkBuffer buffer;
        VkDeviceMemory bufferMemory;
        uint used;

        uint append(T)(T[] data)
        {
            uint result = used;
            T* value;

            vkMapMemory(device, bufferMemory, used, data.length * sizeof32!T, 0, cast(void**)&value);
            value[0 .. data.length] = data[];
            vkUnmapMemory(device, bufferMemory);

            used += data.length * sizeof32!T;

            return result;
        }
    }

    VkImage       swapchainImage;
    VkImageView   swapchainImageView;
    VkFramebuffer swapchainFramebuffer;

    VkCommandBuffer commandBuffer;
    VkCommandBuffer offscreenCommandBuffer;
    VkFence         fence;

    UniformBuffer uniform;

    Buffer vertex;
    Buffer index;

    void clearDataBuffers()
    {
        uniform.used = 0;
        vertex.used = 0;
        index.used = 0;
    }
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

enum maxSwapFrames = 5;

bool hasTextureCompressionBc;

VkInstance               instance;
VkDebugReportCallbackEXT callback;
VkPhysicalDevice         physicalDevice;
VkDevice                 device;
VkSurfaceKHR             surface;

VkQueue                  graphicsQueue;
VkQueue                  presentQueue;

VkSwapchainKHR           swapchain;
VkFormat                 swapchainImageFormat;
VkExtent2D               swapchainExtent;
VkRenderPass             renderPass;
FixedArray!(FrameData, maxSwapFrames) frames;

VkCommandPool            commandPool;
VkDescriptorPool         descriptorPool;

VkBuffer                 sbspVertexBuffer;
VkDeviceMemory           sbspVertexBufferMemory;
VkBuffer                 lightmapVertexBuffer;
VkDeviceMemory           lightmapVertexBufferMemory;
VkBuffer                 sbspIndexBuffer;
VkDeviceMemory           sbspIndexBufferMemory;

VkBuffer                 modelVertexBuffer;
VkDeviceMemory           modelVertexBufferMemory;
VkBuffer                 modelIndexBuffer;
VkDeviceMemory           modelIndexBufferMemory;

VkBuffer                 envUnifomBuffer;
VkDeviceMemory           envUnifomBufferMemory;

VkDescriptorSetLayout    frameBufferDescriptorSetLayout;
uint                     sceneGlobalUniformOffset;

VkDescriptorSetLayout    lightmapDescriptorSetLayout;
VkDescriptorSet          lightmapDescriptorSet;

VkDescriptorSetLayout    sbspEnvDescriptorSetLayout;
VkPipelineLayout         sbspEnvPipelineLayout;
VkPipeline[3][3][3]      sbspEnvPipelines;

VkDescriptorSetLayout    chicagoModelDescriptorSetLayout;
VkPipelineLayout         chicagoModelPipelineLayout;
VkPipeline               chicagoModelPipeline;

VkDescriptorSetLayout    modelShaderDescriptorSetLayout;
VkPipelineLayout         modelShaderPipelineLayout;
VkPipeline[5][2][3][2]   modelShaderPipelines;

VkImage                  imguiImage;
VkDeviceMemory           imguiImageMemory;
VkImageView              imguiImageView;

VkDescriptorSetLayout    imguiDescriptorSetLayout;
VkDescriptorSet          imguiDescriptorSet;
VkPipelineLayout         imguiPipelineLayout;
VkPipeline               imguiPipeline;

uint                     imguiVertexBufferOffset;
uint                     imguiIndexBufferOffset;

VkDescriptorSetLayout    debugFrameBufferDescriptorSetLayout;
VkDescriptorSet          debugFrameBufferDescriptorSet;
VkPipelineLayout         debugFrameBufferPipelineLayout;
VkPipeline               debugFrameBufferPipeline;

FrameBuffer              offscreenFramebuffer;
VkSampler                colorSampler;

VkBuffer                 quadVertexBuffer;
VkDeviceMemory           quadVertexBufferMemory;

VkSemaphore              imageAvailableSemaphore;
VkSemaphore              offscreenFinishedSemaphore;
VkSemaphore              renderFinishedSemaphore;

static ShaderInstance[DatumIndex] shaderInstances; // TODO is static as hack to fix crashing.
FixedArray!(Texture, 1024) textureInstances; // TODO increase limit?

uint windowWidth = 1920;
uint windowHeight = 1080;

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

void transitionImageLayout(VkImage image, int mipmap, int layerCount, VkImageLayout oldLayout, VkImageLayout newLayout)
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
    barrier.subresourceRange.layerCount = layerCount;

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
    offscreenFramebuffer.width  = windowWidth / 2; // TODO unhardcode
    offscreenFramebuffer.height = windowHeight / 2;

    createAttachment(swapchainImageFormat, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.albedo);
    createAttachment(swapchainImageFormat, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, &offscreenFramebuffer.specular);
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
    sampler.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
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

    FixedArray!(VkDeviceQueueCreateInfo, 2) queueInfos;

    float priority = 1.0f;

    if(queues.graphicsQueue == queues.presentQueue) queueInfos.resize(1);
    else                                            queueInfos.resize(2);


    foreach(i, ref queueInfo ; queueInfos)
    {
        queueInfo.queueFamilyIndex = (i == 0) ? queues.graphicsQueue : queues.presentQueue;
        queueInfo.queueCount = 1;
        queueInfo.pQueuePriorities = &priority;
    }

    VkPhysicalDeviceFeatures capabilities;
    vkGetPhysicalDeviceFeatures(physicalDevice, &capabilities);

    hasTextureCompressionBc = (capabilities.textureCompressionBC == VK_TRUE);

    VkPhysicalDeviceFeatures features;
    features.textureCompressionBC = hasTextureCompressionBc;
    features.samplerAnisotropy = true;

    VkDeviceCreateInfo info;

    info.pQueueCreateInfos       = queueInfos.ptr;
    info.queueCreateInfoCount    = queueInfos.length;
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

        actualExtent.width  = clamp(actualExtent.width,  capabilities.minImageExtent.width,  capabilities.maxImageExtent.width);
        actualExtent.height = clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

        return actualExtent;
    }
}

void createSwapChain()
{
    SwapChainSupportDetails swapChainSupport = querySwapChainSupport(physicalDevice);

    VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
    VkPresentModeKHR   presentMode   = chooseSwapPresentMode(swapChainSupport.presentModes);
    VkExtent2D         extent        = chooseSwapExtent(swapChainSupport.capabilities);

    windowWidth  = extent.width;
    windowHeight = extent.height;

    uint imageCount = swapChainSupport.capabilities.minImageCount;

    VkSwapchainCreateInfoKHR info;
    info.surface = surface;
    info.minImageCount = imageCount;
    info.imageFormat = surfaceFormat.format;
    info.imageColorSpace = surfaceFormat.colorSpace;
    info.imageExtent = extent;
    info.imageArrayLayers = 1;
    info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

    if(swapChainSupport.capabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR)
    {
        swapChainSupport.capabilities.currentTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    }

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

    VkImage[maxSwapFrames] images;
    vkGetSwapchainImagesKHR(device, swapchain, &imageCount, null);
    vkGetSwapchainImagesKHR(device, swapchain, &imageCount, images.ptr);

    frames.resize(imageCount);

    foreach(int i, ref frame ; frames)
    {
        frame.swapchainImage = images[i];
    }
}

void cleanupSwapchain()
{
    // foreach(swapchainFramebuffer; swapchainFramebuffers)
    // {
    //     vkDestroyFramebuffer(device, swapchainFramebuffer, null);
    // }

    // vkFreeCommandBuffers(device, commandPool, commandBuffers.length, commandBuffers.ptr);

    // // vkDestroyPipeline(device, graphicsPipeline, null);
    // // vkDestroyPipelineLayout(device, pipelineLayout, null);
    // // vkDestroyRenderPass(device, renderPass, null);

    // foreach(swapchainImageView ; swapchainImageViews)
    // {
    //     vkDestroyImageView(device, swapchainImageView, null);
    // }

    // vkDestroySwapchainKHR(device, swapchain, null);
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
    foreach(ref frame ; frames)
    {
        VkImageViewCreateInfo info;

        info.image = frame.swapchainImage;
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

        if(VkResult result = vkCreateImageView(device, &info, null, &frame.swapchainImageView))
        {
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateImageView(): %s", result.to!string.ptr);
            assert(0);
        }
    }
}

auto createShaderModule(const(void)[] code)
{
    static struct Result
    {
        VkDevice device;
        VkShaderModule shader;

        @disable this(this);

        ~this()
        {
            if(shader)
            {
                vkDestroyShaderModule(device, shader, null);
            }
        }
    }

    VkShaderModuleCreateInfo info;
    info.codeSize = code.length;
    info.pCode = cast(const(uint)*)code.ptr;

    Result result = Result(device);
    if(VkResult res = vkCreateShaderModule(device, &info, null, &result.shader))
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

void createFrameData()
{
    foreach(ref frame ; frames)
    {
        const uint bufferSize = 0x10_0000;

        frame.uniform.size = bufferSize;
        frame.uniform.device = device;
        createBuffer(bufferSize, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
            frame.uniform.buffer, frame.uniform.bufferMemory);

        VkDescriptorSetLayout[1] layouts =
        [
            frameBufferDescriptorSetLayout,
        ];

        VkDescriptorSetAllocateInfo allocInfo;
        allocInfo.descriptorPool = descriptorPool;
        allocInfo.setLayouts = layouts;

        vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &frame.uniform.descriptorSet));

        VkDescriptorBufferInfo bufferInfo;
        bufferInfo.buffer = frame.uniform.buffer;
        bufferInfo.offset = 0;
        bufferInfo.range = 0x500; // TODO max size, make less static

        VkWriteDescriptorSet descriptorWrite;

        descriptorWrite.dstSet = frame.uniform.descriptorSet;
        descriptorWrite.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
        descriptorWrite.descriptorCount = 1;
        descriptorWrite.pBufferInfo = &bufferInfo;

        vkUpdateDescriptorSets(device, 1, &descriptorWrite, 0, null);

        // vertex buffer

        frame.vertex.device = device;
        createBuffer(0x10_0000, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, frame.vertex.buffer, frame.vertex.bufferMemory);

        // index buffer

        frame.index.device = device;
        createBuffer(0x5_0000, VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, frame.index.buffer, frame.index.bufferMemory);

        // fence

        VkFenceCreateInfo fenceCreateInfo;
        fenceCreateInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
        vkCreateFence(device, &fenceCreateInfo, null, &frame.fence);
    }
}

void updateUniformBuffer(ref FrameData frame, ref Camera camera)
{
    EnvUnifomBuffer uniform;

    uniform.projview = camera.viewproj;
    uniform.eyePos = camera.position;

    sceneGlobalUniformOffset = frame.uniform.appendAligned(uniform);
}

uint updateSkyModelUniformBuffer(ref FrameData frame, ref Camera camera)
{
    ModelUniformBuffer uniform;

    uniform.matrices = Mat4(1.0f / 1024.0f);
    uniform.matrices[0][3] = Vec4(camera.position, 1.0f);

    return frame.uniform.appendAligned(uniform);
}

void createFrameBufferDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[1] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, 1, VK_SHADER_STAGE_ALL_GRAPHICS),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindings = setLayoutBindings;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &frameBufferDescriptorSetLayout));
}

void createLightmapDescriptorSetLayout(TagScenarioStructureBsp* sbsp)
{
    auto tagBitmap = Cache.get!TagBitmap(sbsp.lightmapsBitmap.index);

    VkDescriptorSetLayoutBinding[1] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            tagBitmap.bitmaps.size, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

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

    FixedArray!(VkDescriptorImageInfo, 64) imageInfos;

    auto tagBitmap = Cache.get!TagBitmap(sbsp.lightmapsBitmap.index);

    foreach(uint i, ref tagBitmapData ; tagBitmap.bitmaps)
    {
        Texture* texture = findOrLoadTexture2D(sbsp.lightmapsBitmap.index, i, DefaultTexture.multiplicative);

        VkDescriptorImageInfo imageInfo;
        imageInfo.imageView = texture.imageView;
        imageInfo.sampler = texture.sampler;
        imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

        imageInfos.add(imageInfo);
    }

    VkWriteDescriptorSet desc;
    desc.dstSet = lightmapDescriptorSet;
    desc.dstBinding = 0;
    desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    desc.descriptorCount = imageInfos.length;
    desc.pImageInfo = imageInfos.ptr;

    vkUpdateDescriptorSets(device, 1, &desc, 0, null);
}

void createEnvDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[7] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(2, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(3, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(4, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(5, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(6, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &sbspEnvDescriptorSetLayout));
}

void createBaseSbspEnvPipeline()
{
    static const(void)[][3][3][3] createEnvFragBinaries()
    {
        import std.conv : to;

        const(void)[][3][3][3] result;

        static foreach(type   ; 0 .. 2)
        static foreach(detail ; 0 .. 2)
        static foreach(micro  ; 0 .. 2)
        {
            result[type][detail][micro]
                = mixin("import(\"Env-frag-" ~ type.to!string ~ "-" ~ detail.to!string ~ "-" ~ micro.to!string ~ ".spv\")");
        }

        return result;
    }

    static immutable void[][3][3][3] fragBinaries = createEnvFragBinaries();
    static immutable void[] vertBinary = import("Env-vert.spv");

    auto vertShader = createShaderModule(vertBinary);

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShader.shader;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].pName = "main";

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
        VkVertexInputAttributeDescription(6, 1, VK_FORMAT_R32G32_SFLOAT,    TagBspLightmapVertex.coord.offsetof),
    ];

    vertexInputInfo.vertexBindingDescriptionCount   = bindingDesc.length32;
    vertexInputInfo.pVertexBindingDescriptions      = bindingDesc.ptr;
    vertexInputInfo.vertexAttributeDescriptionCount = attributeDescs.length32;
    vertexInputInfo.pVertexAttributeDescriptions    = attributeDescs.ptr;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    VkViewport viewport;
    viewport.width = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);

    VkRect2D scissor;
    scissor.extent = swapchainExtent;

    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.cullMode = VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo multisampling;

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
    colorBlending.attachments = colorBlendAttachments;

    VkDynamicState[2] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.dynamicStates = dynamicStates;

    VkPipelineDepthStencilStateCreateInfo depthStencilState;
    depthStencilState.depthTestEnable = true;
    depthStencilState.depthWriteEnable = true;
    depthStencilState.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;

    VkDescriptorSetLayout[3] descriptorSetLayouts =
    [
        frameBufferDescriptorSetLayout,
        sbspEnvDescriptorSetLayout,
        lightmapDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_ALL_GRAPHICS, 0, EnvPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayouts = descriptorSetLayouts;
    pipelineLayoutInfo.pushConstantRanges = pushConstantRanges;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &sbspEnvPipelineLayout));

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.flags = VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT;
    pipelineInfo.shaderStages = shaderStages;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pDepthStencilState = &depthStencilState;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = sbspEnvPipelineLayout;

    pipelineInfo.renderPass = offscreenFramebuffer.renderPass;

    foreach(type   ; 0 .. 2)
    foreach(detail ; 0 .. 2)
    foreach(micro  ; 0 .. 2)
    {
        auto fragShader = createShaderModule(fragBinaries[type][detail][micro]);
        shaderStages[1].module_ = fragShader.shader;

        vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo,
            null, &sbspEnvPipelines[type][detail][micro]));
    }
}

void createSbspEnvPipelines()
{
    createBaseSbspEnvPipeline();
}

void createModelShaderDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[4] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(2, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(3, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &modelShaderDescriptorSetLayout));
}

void createModelShaderPipelines()
{
    import Game.Render.Pipeline;

    static auto createModelFragBinaries()
    {
        import std.conv : to;

        const(void)[][5][2][3][2] result;

        static foreach(mask    ; 0 .. 5)
        static foreach(invert  ; 0 .. 2)
        static foreach(detail  ; 0 .. 3)
        static foreach(reflect ; 0 .. 2)
        {
            result[reflect][detail][invert][mask] = mixin("import(\"Model-frag-" ~ mask.to!string ~ "-"
                ~ invert.to!string ~ "-" ~ detail.to!string ~ "-" ~ reflect.to!string ~ ".spv\")");
        }

        return result;
    }

    static immutable fragBinaries = createModelFragBinaries();
    static immutable void[] vertBinary = import("Model-vert.spv");

    Pipeline pipeline;

    pipeline.inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
    pipeline.rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    pipeline.rasterizer.cullMode  = VK_CULL_MODE_BACK_BIT;
    pipeline.rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;

    VkViewport viewport;
    viewport.width  = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);

    VkRect2D scissor;
    scissor.extent = swapchainExtent;

    pipeline.viewportState.viewportCount = 1;
    pipeline.viewportState.pViewports = &viewport;
    pipeline.viewportState.scissorCount = 1;
    pipeline.viewportState.pScissors = &scissor;

    auto vertShader = createShaderModule(vertBinary);

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShader.shader;
    shaderStages[0].pName = "main";

    VkPipelineColorBlendAttachmentState[4] colorBlendAttachments;

    foreach(ref colorBlendAttachment ; colorBlendAttachments)
    {
        colorBlendAttachment.colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT |
            VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT |
            VK_COLOR_COMPONENT_A_BIT;
    }

    pipeline.colorBlending.attachments = colorBlendAttachments;

    VkVertexInputBindingDescription[1] bindingDesc =
    [
        VkVertexInputBindingDescription(0, TagModelVertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX),
    ];

    VkVertexInputAttributeDescription[5] attributeDescs =
    [
        VkVertexInputAttributeDescription(0, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.position.offsetof),
        VkVertexInputAttributeDescription(1, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.normal.offsetof),
        VkVertexInputAttributeDescription(2, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.coord.offsetof),
        VkVertexInputAttributeDescription(3, 0, VK_FORMAT_R32G32_SINT,      TagModelVertex.node0.offsetof),
        VkVertexInputAttributeDescription(4, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.weight.offsetof),
    ];

    pipeline.vertexInputInfo.vertexBindingDescriptions   = bindingDesc;
    pipeline.vertexInputInfo.vertexAttributeDescriptions = attributeDescs;

    VkDynamicState[2] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    pipeline.dynamicState.dynamicStates = dynamicStates;

    pipeline.depthStencilState.depthTestEnable = true;
    pipeline.depthStencilState.depthWriteEnable = true;
    pipeline.depthStencilState.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;

    // Pipeline Layout

    VkDescriptorSetLayout[3] descriptorSetLayouts =
    [
        frameBufferDescriptorSetLayout,
        modelShaderDescriptorSetLayout,
        frameBufferDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_ALL_GRAPHICS, 0, ModelPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayouts = descriptorSetLayouts;
    pipelineLayoutInfo.pushConstantRanges = pushConstantRanges;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &modelShaderPipelineLayout));

    // Create Pipeline

    VkGraphicsPipelineCreateInfo info = pipeline.makeCreateInfo();

    info.shaderStages = shaderStages;
    info.layout = modelShaderPipelineLayout;
    info.renderPass = offscreenFramebuffer.renderPass;

    foreach(mask    ; 0 .. 5)
    foreach(invert  ; 0 .. 2)
    foreach(detail  ; 0 .. 3)
    foreach(reflect ; 0 .. 2)
    {
        auto fragShader = createShaderModule(fragBinaries[reflect][detail][invert][mask]);

        shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        shaderStages[1].module_ = fragShader.shader;
        shaderStages[1].pName = "main";

        vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &info,
            null, &modelShaderPipelines[reflect][detail][invert][mask]));
    }

}

void createChicagoModelDescriptorSetLayout()
{
    VkDescriptorSetLayoutBinding[4] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(2, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(3, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &chicagoModelDescriptorSetLayout));
}

void createChicagoModelPipeline()
{
    import Game.Render.Pipeline;

    static immutable void[] fragBinary = import("Chicago-frag.spv");
    static immutable void[] vertBinary = import("Chicago-vert.spv");

    Pipeline pipeline;

    pipeline.inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
    pipeline.rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    pipeline.rasterizer.cullMode  = VK_CULL_MODE_BACK_BIT;
    pipeline.rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;

    VkViewport viewport;
    viewport.width  = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);

    VkRect2D scissor;
    scissor.extent = swapchainExtent;

    pipeline.viewportState.viewportCount = 1;
    pipeline.viewportState.pViewports = &viewport;
    pipeline.viewportState.scissorCount = 1;
    pipeline.viewportState.pScissors = &scissor;

    auto vertShader = createShaderModule(vertBinary);
    auto fragShader = createShaderModule(fragBinary);

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShader.shader;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module_ = fragShader.shader;
    shaderStages[1].pName = "main";

    VkPipelineColorBlendAttachmentState[4] colorBlendAttachments;

    foreach(ref colorBlendAttachment ; colorBlendAttachments)
    {
        colorBlendAttachment.blendEnable = VK_TRUE;
        colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
        colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD;

        colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
        colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD;

        colorBlendAttachment.colorWriteMask =
            VK_COLOR_COMPONENT_R_BIT |
            VK_COLOR_COMPONENT_G_BIT |
            VK_COLOR_COMPONENT_B_BIT |
            VK_COLOR_COMPONENT_A_BIT;
    }

    pipeline.colorBlending.attachments = colorBlendAttachments;

    VkVertexInputBindingDescription[1] bindingDesc =
    [
        VkVertexInputBindingDescription(0, TagModelVertex.sizeof, VK_VERTEX_INPUT_RATE_VERTEX),
    ];

    VkVertexInputAttributeDescription[5] attributeDescs =
    [
        VkVertexInputAttributeDescription(0, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.position.offsetof),
        VkVertexInputAttributeDescription(1, 0, VK_FORMAT_R32G32B32_SFLOAT, TagModelVertex.normal.offsetof),
        VkVertexInputAttributeDescription(2, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.coord.offsetof),
        VkVertexInputAttributeDescription(3, 0, VK_FORMAT_R32G32_SINT,      TagModelVertex.node0.offsetof),
        VkVertexInputAttributeDescription(4, 0, VK_FORMAT_R32G32_SFLOAT,    TagModelVertex.weight.offsetof),
    ];

    pipeline.vertexInputInfo.vertexBindingDescriptions   = bindingDesc;
    pipeline.vertexInputInfo.vertexAttributeDescriptions = attributeDescs;

    VkDynamicState[2] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    pipeline.dynamicState.dynamicStates = dynamicStates;

    // Pipeline Layout

    VkDescriptorSetLayout[3] descriptorSetLayouts =
    [
        frameBufferDescriptorSetLayout,
        chicagoModelDescriptorSetLayout,
        frameBufferDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_ALL_GRAPHICS, 0, ChicagoPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayouts = descriptorSetLayouts;
    pipelineLayoutInfo.pushConstantRanges = pushConstantRanges;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &chicagoModelPipelineLayout));

    // Create Pipeline

    VkGraphicsPipelineCreateInfo info = pipeline.makeCreateInfo();

    info.shaderStages = shaderStages;
    info.layout = chicagoModelPipelineLayout;
    info.renderPass = offscreenFramebuffer.renderPass;

    vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &info, null, &chicagoModelPipeline));
}

void createFramebuffers()
{
    foreach(ref frame ; frames)
    {
        VkImageView[1] attachments =
        [
            frame.swapchainImageView,
        ];

        VkFramebufferCreateInfo info;
        info.renderPass = renderPass;
        info.attachmentCount = attachments.length;
        info.pAttachments = attachments.ptr;
        info.width = swapchainExtent.width;
        info.height = swapchainExtent.height;
        info.layers = 1;

        if(VkResult result = vkCreateFramebuffer(device, &info, null, &frame.swapchainFramebuffer))
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
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    poolInfo.queueFamilyIndex = queues.graphicsQueue;

    if(VkResult result = vkCreateCommandPool(device, &poolInfo, null, &commandPool))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkCreateCommandPool(): %s", result.to!string.ptr);
        assert(0);
    }
}

void createDescriptorPool()
{
    VkDescriptorPoolSize[3] poolSize =
    [
        VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1024),
        VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 256),
        VkDescriptorPoolSize(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC, 256),
    ];

    VkDescriptorPoolCreateInfo poolInfo;
    poolInfo.poolSizeCount = poolSize.length32;
    poolInfo.pPoolSizes = poolSize.ptr;
    poolInfo.maxSets = 1024;

    vkCheck(vkCreateDescriptorPool(device, &poolInfo, null, &descriptorPool));
}

void createCommandBuffers()
{
    VkCommandBufferAllocateInfo allocInfo;
    allocInfo.commandPool = commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = 1;

    foreach(ref frame ; frames)
    {
        vkCheck(vkAllocateCommandBuffers(device, &allocInfo, &frame.commandBuffer));
        vkCheck(vkAllocateCommandBuffers(device, &allocInfo, &frame.offscreenCommandBuffer));
    }
}

void createSemaphores()
{
    VkSemaphoreCreateInfo semaphoreInfo;

    vkCheck(vkCreateSemaphore(device, &semaphoreInfo, null, &imageAvailableSemaphore));
    vkCheck(vkCreateSemaphore(device, &semaphoreInfo, null, &offscreenFinishedSemaphore));
    vkCheck(vkCreateSemaphore(device, &semaphoreInfo, null, &renderFinishedSemaphore));
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

void createModelVertexBuffer()
{
    ubyte[] vertexData;
    ubyte[] indexData;

    Cache.inst.readModelVertexData(vertexData, indexData);

    createVertexBuffer(cast(TagModelVertex[])vertexData, modelVertexBuffer, modelVertexBufferMemory);

    // index

    uint bufferSize = indexData.length32;

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
    data[0 .. bufferSize] = indexData;
    vkUnmapMemory(device, stagingBufferMemory);

    createBuffer(bufferSize, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, modelIndexBuffer, modelIndexBufferMemory);

    copyBuffer(stagingBuffer, modelIndexBuffer, bufferSize);

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

void createImguiTexture()
{
    auto io = igGetIO();

    ubyte* pixels;
    int width;
    int height;
    io.Fonts.GetTexDataAsRGBA32(&pixels, &width, &height);

    uint bufferSize = width * height * 4;

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
    data[0 .. bufferSize] = pixels[0 .. bufferSize];
    vkUnmapMemory(device, stagingBufferMemory);

    VkImageCreateInfo imageInfo;

    imageInfo.imageType     = VK_IMAGE_TYPE_2D;
    imageInfo.extent.width  = width;
    imageInfo.extent.height = height;
    imageInfo.extent.depth  = 1;
    imageInfo.mipLevels     = 1;
    imageInfo.arrayLayers   = 1;
    imageInfo.format        = VK_FORMAT_R8G8B8A8_UNORM;
    imageInfo.tiling        = VK_IMAGE_TILING_OPTIMAL;
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    imageInfo.usage         = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
    imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT;
    imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;

    vkCheck(vkCreateImage(device, &imageInfo, null, &imguiImage));

    VkMemoryRequirements memRequirements;
    vkGetImageMemoryRequirements(device, imguiImage, &memRequirements);

    VkMemoryAllocateInfo allocInfo;
    allocInfo.allocationSize  = memRequirements.size;
    allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

    vkAllocateMemory(device, &allocInfo, null, &imguiImageMemory);
    vkBindImageMemory(device, imguiImage, imguiImageMemory, 0);


    // TODO optimize, too many command buffers being used here
    //      each transition uses it's own one time buffer, entire process can use one command buffer

    transitionImageLayout(imguiImage, 0, 1, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

    VkCommandBuffer commandBuffer = beginSingleTimeCommands();

    VkBufferImageCopy region;
    region.bufferOffset                = 0;
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.mipLevel   = 0;
    region.imageSubresource.layerCount = 1;
    region.imageExtent                 = VkExtent3D(width, height, 1);

    vkCmdCopyBufferToImage(commandBuffer, stagingBuffer, imguiImage,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
    endSingleTimeCommands(commandBuffer);

    transitionImageLayout(imguiImage, 0, 1, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

    VkImageViewCreateInfo viewCreateInfo;

    viewCreateInfo.image = imguiImage;
    viewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    viewCreateInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
    viewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    viewCreateInfo.subresourceRange.baseMipLevel = 0;
    viewCreateInfo.subresourceRange.levelCount = 1;
    viewCreateInfo.subresourceRange.baseArrayLayer = 0;
    viewCreateInfo.subresourceRange.layerCount = 1;

    vkCheck(vkCreateImageView(device, &viewCreateInfo, null, &imguiImageView));
}

void createImguiDescriptorSet()
{
    VkDescriptorSetLayoutBinding[1] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &imguiDescriptorSetLayout));

    VkDescriptorSetLayout[1] layouts =
    [
        imguiDescriptorSetLayout,
    ];

    VkDescriptorSetAllocateInfo allocInfo;
    allocInfo.descriptorPool = descriptorPool;
    allocInfo.descriptorSetCount = layouts.length32;
    allocInfo.pSetLayouts = layouts.ptr;

    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &imguiDescriptorSet));

    FixedArray!(VkDescriptorImageInfo, 1) imageInfos;
    FixedArray!(VkWriteDescriptorSet, 1)  descriptorWrites;

    VkDescriptorImageInfo imageInfo;
    imageInfo.imageView = imguiImageView;
    imageInfo.sampler = colorSampler;
    imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

    imageInfos.add(imageInfo);

    VkWriteDescriptorSet desc;
    desc.dstSet = imguiDescriptorSet;
    desc.dstBinding = 0;
    desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    desc.descriptorCount = 1;
    desc.pImageInfo = imageInfos.ptr;

    descriptorWrites.add(desc);

    vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);
}

void createImguiPipeline()
{
    auto vertShader = createShaderModule(import("Imgui-vert.spv"));
    auto fragShader = createShaderModule(import("Imgui-frag.spv"));

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShader.shader;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module_ = fragShader.shader;
    shaderStages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vertexInputInfo;

    VkVertexInputBindingDescription[1] bindingDesc = [ ImguiVertex.getBindingDescription() ];
    VkVertexInputAttributeDescription[3] attributeDescs = ImguiVertex.getAttributeDescriptions();

    vertexInputInfo.vertexBindingDescriptionCount   = bindingDesc.length32;
    vertexInputInfo.pVertexBindingDescriptions      = bindingDesc.ptr;
    vertexInputInfo.vertexAttributeDescriptionCount = attributeDescs.length32;
    vertexInputInfo.pVertexAttributeDescriptions    = attributeDescs.ptr;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;

    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    inputAssembly.primitiveRestartEnable = VK_FALSE;

    VkViewport viewport;
    viewport.width = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);

    VkRect2D scissor;
    scissor.extent = swapchainExtent;

    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.cullMode = VK_CULL_MODE_NONE;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo multisampling;
    multisampling.sampleShadingEnable = VK_FALSE;

    VkPipelineColorBlendAttachmentState[1] colorBlendAttachments;

    foreach(ref colorBlendAttachment ; colorBlendAttachments)
    {
        colorBlendAttachment.blendEnable = VK_TRUE;
        colorBlendAttachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
        colorBlendAttachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        colorBlendAttachment.colorBlendOp = VK_BLEND_OP_ADD;

        colorBlendAttachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
        colorBlendAttachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
        colorBlendAttachment.alphaBlendOp = VK_BLEND_OP_ADD;

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

    VkDynamicState[3] dynamicStates =
    [
        VK_DYNAMIC_STATE_VIEWPORT,
        VK_DYNAMIC_STATE_SCISSOR,
        VK_DYNAMIC_STATE_LINE_WIDTH,
    ];

    VkPipelineDynamicStateCreateInfo dynamicState;
    dynamicState.dynamicStateCount = dynamicStates.length;
    dynamicState.pDynamicStates = dynamicStates.ptr;

    VkPipelineDepthStencilStateCreateInfo depthStencilState;

    VkDescriptorSetLayout[1] descriptorSetLayouts =
    [
        imguiDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_VERTEX_BIT, 0, ImguiPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayouts = descriptorSetLayouts;
    pipelineLayoutInfo.pushConstantRanges = pushConstantRanges;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &imguiPipelineLayout));

    VkGraphicsPipelineCreateInfo pipelineInfo;
    pipelineInfo.shaderStages = shaderStages;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &inputAssembly;
    pipelineInfo.pDepthStencilState = &depthStencilState;
    pipelineInfo.pViewportState = &viewportState;
    pipelineInfo.pRasterizationState = &rasterizer;
    pipelineInfo.pMultisampleState = &multisampling;
    pipelineInfo.pColorBlendState = &colorBlending;
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = imguiPipelineLayout;

    pipelineInfo.renderPass = renderPass; // TODO renderpass?
    pipelineInfo.subpass = 0;

    vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &imguiPipeline));
}

void updateImguiBuffers(ref FrameData frame, ImDrawData* drawData)
{
    auto io = igGetIO();

    uint vertexSize = drawData.TotalVtxCount * sizeof32!ImguiVertex;
    uint indexSize = drawData.TotalIdxCount  * sizeof32!ImDrawIdx;


    foreach(int i, ImDrawList* cmdList ; drawData.CmdLists[0 .. drawData.CmdListsCount])
    {
        uint offset = frame.vertex.append(cmdList.VtxBuffer[]);

        if(i == 0)
        {
            imguiVertexBufferOffset = offset;
        }
    }

    foreach(int i, ImDrawList* cmdList ; drawData.CmdLists[0 .. drawData.CmdListsCount])
    {
        uint offset = frame.index.append(cmdList.IdxBuffer[]);

        if(i == 0)
        {
            imguiIndexBufferOffset = offset;
        }
    }
}

void createDebugFrameBufferPipeline()
{
    auto vertShader = createShaderModule(import("DebugFrameBuffer-vert.spv"));
    auto fragShader = createShaderModule(import("DebugFrameBuffer-frag.spv"));

    VkPipelineShaderStageCreateInfo[2] shaderStages;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module_ = vertShader.shader;
    shaderStages[0].pName = "main";

    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module_ = fragShader.shader;
    shaderStages[1].pName = "main";

    VkPipelineVertexInputStateCreateInfo vertexInputInfo;

    VkVertexInputBindingDescription[1] bindingDesc = [ TexVertex.getBindingDescription() ];
    VkVertexInputAttributeDescription[2] attributeDescs = TexVertex.getAttributeDescriptions();

    vertexInputInfo.vertexBindingDescriptionCount   = bindingDesc.length32;
    vertexInputInfo.pVertexBindingDescriptions      = bindingDesc.ptr;
    vertexInputInfo.vertexAttributeDescriptionCount = attributeDescs.length32;
    vertexInputInfo.pVertexAttributeDescriptions    = attributeDescs.ptr;

    VkPipelineInputAssemblyStateCreateInfo inputAssembly;
    inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;

    VkViewport viewport;
    viewport.width = float(swapchainExtent.width);
    viewport.height = float(swapchainExtent.height);

    VkRect2D scissor;
    scissor.extent = swapchainExtent;

    VkPipelineViewportStateCreateInfo viewportState;
    viewportState.viewportCount = 1;
    viewportState.pViewports = &viewport;
    viewportState.scissorCount = 1;
    viewportState.pScissors = &scissor;

    VkPipelineRasterizationStateCreateInfo rasterizer;
    rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
    rasterizer.cullMode = VK_CULL_MODE_FRONT_BIT;
    rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE;

    VkPipelineMultisampleStateCreateInfo multisampling;

    VkPipelineColorBlendAttachmentState[1] colorBlendAttachments;

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
    dynamicState.dynamicStates = dynamicStates;

    VkPipelineDepthStencilStateCreateInfo depthStencilState;

    VkDescriptorSetLayout[1] descriptorSetLayouts =
    [
        debugFrameBufferDescriptorSetLayout,
    ];

    VkPushConstantRange[1] pushConstantRanges =
    [
        VkPushConstantRange(VK_SHADER_STAGE_ALL_GRAPHICS, 0, EnvPushConstants.sizeof),
    ];

    VkPipelineLayoutCreateInfo pipelineLayoutInfo;
    pipelineLayoutInfo.setLayouts = descriptorSetLayouts;
    pipelineLayoutInfo.pushConstantRanges = pushConstantRanges;

    vkCheck(vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &debugFrameBufferPipelineLayout));

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
    pipelineInfo.pDynamicState = &dynamicState;
    pipelineInfo.layout = debugFrameBufferPipelineLayout;

    pipelineInfo.renderPass = renderPass; // TODO renderpass?
    pipelineInfo.subpass = 0;

    vkCheck(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &pipelineInfo, null, &debugFrameBufferPipeline));
}

void createDebugFrameBufferDescriptorSet()
{
    VkDescriptorSetLayoutBinding[4] setLayoutBindings =
    [
        VkDescriptorSetLayoutBinding(0, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(1, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(2, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
        VkDescriptorSetLayoutBinding(3, VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 1, VK_SHADER_STAGE_FRAGMENT_BIT),
    ];

    VkDescriptorSetLayoutCreateInfo descriptorLayout;
    descriptorLayout.bindingCount = setLayoutBindings.length32;
    descriptorLayout.pBindings = setLayoutBindings.ptr;

    vkCheck(vkCreateDescriptorSetLayout(device, &descriptorLayout, null, &debugFrameBufferDescriptorSetLayout));

    VkDescriptorSetLayout[1] layouts =
    [
        debugFrameBufferDescriptorSetLayout,
    ];

    VkDescriptorSetAllocateInfo allocInfo;
    allocInfo.descriptorPool = descriptorPool;
    allocInfo.descriptorSetCount = layouts.length32;
    allocInfo.pSetLayouts = layouts.ptr;

    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &debugFrameBufferDescriptorSet));

    FixedArray!(VkDescriptorImageInfo, 4) imageInfos;
    FixedArray!(VkWriteDescriptorSet, 4)  descriptorWrites;

    FrameBufferAttachment*[4] attachments =
    [
        &offscreenFramebuffer.albedo,
        &offscreenFramebuffer.specular,
        &offscreenFramebuffer.position,
        &offscreenFramebuffer.normal,
    ];

    foreach(uint i, attachment ; attachments)
    {

        VkDescriptorImageInfo imageInfo;
        imageInfo.imageView = attachment.view;
        imageInfo.sampler = colorSampler;
        imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

        imageInfos.add(imageInfo);

        VkWriteDescriptorSet desc;
        desc.dstSet = debugFrameBufferDescriptorSet;
        desc.dstBinding = i;
        desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        desc.descriptorCount = 1;
        desc.pImageInfo = &imageInfos[i];

        descriptorWrites.add(desc);
    }

    vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);
}

void createQuad()
{
    TexVertex[4] vertices =
    [
        TexVertex(Vec3(-1.0f, -1.0f, 0), Vec2(0.0f, 1.0f)),
        TexVertex(Vec3(-1.0f,  1.0f, 0), Vec2(0.0f, 0.0f)),
        TexVertex(Vec3( 1.0f, -1.0f, 0), Vec2(1.0f, 1.0f)),
        TexVertex(Vec3( 1.0f,  1.0f, 0), Vec2(1.0f, 0.0f)),
    ];

    createVertexBuffer(vertices, quadVertexBuffer, quadVertexBufferMemory);

}

void initialize(SDL_Window* window, TagScenarioStructureBsp* sbsp)
{
    createInstance(window);
    setupDebugCallback();
    createSurface(window);
    pickPhysicalDevice();
    createLogicalDevice();

    createCommandPool();
    createDescriptorPool();

    // TODO These should be one function, and/or allow for separate
    //      number of command buffers from swapchain images
    createFrameBufferDescriptorSetLayout();
    createSwapChain();
    createImageViews();
    createFrameData();
    createRenderPass();
    createFramebuffers();
    createCommandBuffers();

    createOffscreenFramebuffer();

    createLightmapDescriptorSetLayout(sbsp);

    createEnvDescriptorSetLayout();
    createSbspEnvPipelines();

    createModelShaderDescriptorSetLayout();
    createModelShaderPipelines();

    createSbspVertexBuffer();
    createLightmapDescriptorSet(sbsp);

    createModelVertexBuffer();

    createChicagoModelDescriptorSetLayout();
    createChicagoModelPipeline();

    createImguiTexture();
    createImguiDescriptorSet();
    createImguiPipeline();

    createDebugFrameBufferDescriptorSet();
    createDebugFrameBufferPipeline();
    createQuad();

    createSemaphores();
}

void render(ref World world, ref Camera camera)
{
    mixin ProfilerObject.ScopedMarker;

    uint imageIndex;
    switch(vkAcquireNextImageKHR(device, swapchain, ulong.max, imageAvailableSemaphore, VK_NULL_HANDLE, &imageIndex))
    {
    case VK_ERROR_OUT_OF_DATE_KHR:
        assert(0);
        recreateSwapchain();
        return;
    default:
        assert(0);
    case VK_SUCCESS:
    case VK_SUBOPTIMAL_KHR:
    }


    auto frame = &frames[imageIndex];
    auto commandBuffer = frame.commandBuffer;
    auto frameBuffer   = frame.swapchainFramebuffer;
    auto offscreenCommandBuffer = frame.offscreenCommandBuffer;
    auto fence = frame.fence;

    {
        mixin ProfilerObject.ScopedMarker!"Fence";
        VkResult result = vkWaitForFences(device, 1, &fence, true, 1000000000);
        switch(result)
        {
        default:
            SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkWaitForFences(): %s", result.to!string.ptr);
            break;
        case VK_SUCCESS:
        }
        vkResetFences(device, 1, &fence);
    }

    frame.clearDataBuffers();
    frame.uniform.mapMemory();

    updateImguiBuffers(*frame, igGetDrawData());

    // Build Command Buffer

    VkCommandBufferBeginInfo beginInfo;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;

    vkBeginCommandBuffer(offscreenCommandBuffer, &beginInfo);

    VkRenderPassBeginInfo renderPassInfo;
    renderPassInfo.renderPass = offscreenFramebuffer.renderPass;
    renderPassInfo.framebuffer = offscreenFramebuffer.frameBuffer;
    renderPassInfo.renderArea.extent = offscreenFramebuffer.extent;

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

    vkCmdBeginRenderPass(offscreenCommandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

    updateUniformBuffer(*frame, camera);

    VkViewport viewport;
    viewport.width  = offscreenFramebuffer.width;
    viewport.height = offscreenFramebuffer.height;

    vkCmdSetViewport(offscreenCommandBuffer, 0, 1, &viewport);

    TagScenario* scenario = Cache.inst.scenario();
    TagScenarioStructureBsp* sbsp = world.getCurrentSbsp;

    // Render sky

    if(scenario.skies)
    {
        uint skyUniformBufferOffset = updateSkyModelUniformBuffer(*frame, camera);

        VkBuffer[1] vertexBuffers = [ modelVertexBuffer ];
        VkDeviceSize[1] offsets = [ 0 ];
        vkCmdBindVertexBuffers(offscreenCommandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
        vkCmdBindIndexBuffer(offscreenCommandBuffer, modelIndexBuffer, 0, VK_INDEX_TYPE_UINT16);

        GObject.Lighting lighting; // TODO(HACK, REFACTOR) need to fill default color, most sky don't use this tho so..

        auto tagSky   = Cache.get!TagSky(scenario.skies[0].sky);
        auto tagModel = Cache.get!TagGbxmodel(tagSky.model);

        int[TagConstants.Model.maxRegions] permutations;

        renderObject(*frame, skyUniformBufferOffset, offscreenCommandBuffer, permutations, &lighting, tagModel);

    }

    // Render Structure Bsp

    {
        VkBuffer[2] vertexBuffers = [ sbspVertexBuffer, lightmapVertexBuffer ];
        VkDeviceSize[2] offsets = [ 0, 0 ];
        vkCmdBindVertexBuffers(offscreenCommandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
        vkCmdBindIndexBuffer(offscreenCommandBuffer, sbspIndexBuffer, 0, VK_INDEX_TYPE_UINT16);
    }

    foreach(int i, ref lightmap ; sbsp.lightmaps)
    {
        if(lightmap.bitmap != indexNone)
        {
            renderOpaqueStructureBsp(*frame, offscreenCommandBuffer, camera, sbsp, i);
        }
    }

    // Render Objects

    {
        mixin ProfilerObject.ScopedMarker!"Objects";

        VkBuffer[1] vertexBuffers = [ modelVertexBuffer ];
        VkDeviceSize[1] offsets = [ 0 ];
        vkCmdBindVertexBuffers(offscreenCommandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
        vkCmdBindIndexBuffer(offscreenCommandBuffer, modelIndexBuffer, 0, VK_INDEX_TYPE_UINT16);

        foreach(ref object ; world.objects)
        {
            ModelUniformBuffer buffer = void;

            if(!object.flags.hidden)
            {
                auto tagObject = Cache.get!TagObject(object.tagIndex);
                auto tagModel  = Cache.get!TagGbxmodel(tagObject.model);

                if(tagModel is null)
                {
                    continue;
                }

                updateObjectLighting(world, object.bound.center /* is this position or bound? */,
                    object.cachedLighting.desired, ObjectLightingOptions(false, false)); // todo implement flags

                foreach(i, ref node ; tagModel.nodes)
                {
                    // todo remove cast, make actual type
                    Transform transform = object.transforms[i] * *cast(Transform*)&node.inverseScale;
                    buffer.matrices[i] = Mat4(transform.toMat4x3WithScale());
                }

                uint bufferOffset = frame.uniform.appendAligned(buffer);

                renderObject(*frame, bufferOffset, offscreenCommandBuffer, object.regionPermutationIndices,
                    &object.cachedLighting.desired, tagModel);
            }
        }
    }

    frame.uniform.unmapMemory();

    vkCmdEndRenderPass(offscreenCommandBuffer);
    vkCheck(vkEndCommandBuffer(offscreenCommandBuffer));

    VkSubmitInfo submitInfo;

    VkSemaphore[1]          waitSemaphores = [ imageAvailableSemaphore ];
    VkPipelineStageFlags[1] waitStages     = [ VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT ];
    submitInfo.waitSemaphoreCount = waitSemaphores.length;
    submitInfo.pWaitSemaphores = waitSemaphores.ptr;
    submitInfo.pWaitDstStageMask = waitStages.ptr;

    VkSemaphore[1] signalSemaphores = [ offscreenFinishedSemaphore ];
    submitInfo.signalSemaphoreCount = signalSemaphores.length;
    submitInfo.pSignalSemaphores = signalSemaphores.ptr;

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &offscreenCommandBuffer;

    if(VkResult result = vkQueueSubmit(graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkQueueSubmit(): %s", result.to!string.ptr);
        assert(0);
    }

    // Render offscreen framebuffer to swapchain framebuffer

    vkBeginCommandBuffer(commandBuffer, &beginInfo);

    renderPassInfo.renderPass = renderPass;
    renderPassInfo.framebuffer = frameBuffer;
    renderPassInfo.renderArea.extent = swapchainExtent;

    vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

    {
        VkBuffer[1] vertexBuffers = [ quadVertexBuffer ];
        VkDeviceSize[1] offsets = [ 0 ];
        vkCmdBindVertexBuffers(commandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
    }

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, debugFrameBufferPipeline);

    VkDescriptorSet[1] decriptorSets =
    [
        debugFrameBufferDescriptorSet
    ];

    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
        debugFrameBufferPipelineLayout, 0, decriptorSets.length32, decriptorSets.ptr, 0, null);

    viewport.width  = windowWidth;
    viewport.height = windowHeight;
    vkCmdSetViewport(commandBuffer, 0, 1, &viewport);

    vkCmdDraw(commandBuffer, 4, 1, 0, 0);

    renderImGui(*frame, commandBuffer);

    vkCmdEndRenderPass(commandBuffer);
    vkCheck(vkEndCommandBuffer(commandBuffer));

    waitSemaphores[0] = offscreenFinishedSemaphore;
    signalSemaphores[0] = renderFinishedSemaphore;

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;

    if(VkResult result = vkQueueSubmit(graphicsQueue, 1, &submitInfo, fence))
    {
        SDL_LogDebug(SDL_LOG_CATEGORY_ERROR, "vkQueueSubmit(): %s", result.to!string.ptr);
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

void renderOpaqueStructureBsp(
    ref FrameData            frame,
    VkCommandBuffer          commandBuffer,
    ref Camera               camera,
    TagScenarioStructureBsp* sbsp,
    int                      lightmapIndex)
{
    import std.typecons : Tuple, tuple;

    auto lightmap = &sbsp.lightmaps[lightmapIndex];

    if(lightmap.bitmap == indexNone)
    {
        return;
    }

    foreach(i, ref material ; lightmap.materials)
    {
        if(material.shader.isIndexNone())
        {
            continue;
        }

        TagShader* baseShader = Cache.get!TagShader(material.shader);
        uint vertexOffset = structureVertexIndexOffsets[lightmapIndex][i];

        switch(baseShader.shaderType) with(TagEnums.ShaderType)
        {
        case environment:
            auto shader = cast(TagShaderEnvironment*)baseShader;

            ShaderInstance* shaderInstance = material.shader.index in shaderInstances;

            if(shaderInstance is null)
            {
                ShaderInstance instance;

                VkDescriptorSetLayout[1] layouts =
                [
                    sbspEnvDescriptorSetLayout,
                ];

                VkDescriptorSetAllocateInfo allocInfo;
                allocInfo.descriptorPool = descriptorPool;
                allocInfo.setLayouts = layouts;

                vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &instance.descriptorSet));

                FixedArray!(VkDescriptorImageInfo, 6) imageInfos;
                FixedArray!(VkWriteDescriptorSet, 6) descriptorWrites;

                Tuple!(DatumIndex, DefaultTexture)[6] textures =
                [
                    tuple(shader.baseMap.index,            DefaultTexture.multiplicative),
                    tuple(shader.primaryDetailMap.index,   DefaultTexture.detail),
                    tuple(shader.secondaryDetailMap.index, DefaultTexture.detail),
                    tuple(shader.microDetailMap.index,     DefaultTexture.detail),
                    tuple(shader.bumpMap.index,            DefaultTexture.vector),
                    tuple(shader.reflectionCubeMap.index,  DefaultTexture.additive),
                ];

                foreach(uint j, ref tex ; textures)
                {
                    Texture* texture =
                        (j == 5) ? findOrLoadTextureCubemap(tex[0], 0, tex[1]) : findOrLoadTexture2D(tex[0], 0, tex[1]);

                    VkDescriptorImageInfo imageInfo;
                    imageInfo.imageView = texture.imageView;
                    imageInfo.sampler = texture.sampler;
                    imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

                    imageInfos.add(imageInfo);

                    VkWriteDescriptorSet desc;
                    desc.dstSet = instance.descriptorSet;
                    desc.dstBinding = j;
                    desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                    desc.descriptorCount = 1;
                    desc.pImageInfo = &imageInfos[j];

                    descriptorWrites.add(desc);
                }

                vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);

                shaderInstances[material.shader.index] = instance;
                shaderInstance = &shaderInstances[material.shader.index];
            }

            vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
                sbspEnvPipelines[shader.type][shader.detailMapFunction][shader.microDetailMapFunction]);

            VkDescriptorSet[3] decriptorSets =
            [
                frame.uniform.descriptorSet,
                shaderInstance.descriptorSet,
                lightmapDescriptorSet,
            ];

            uint[1] descriptorOffsets =
            [
                sceneGlobalUniformOffset,
            ];

            vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, sbspEnvPipelineLayout, 0,
                decriptorSets.length32, decriptorSets.ptr,
                descriptorOffsets.length32, descriptorOffsets.ptr);

            EnvPushConstants pushConstants;

            pushConstants.uvScales =
            [
                Vec2(1.0f),
                Vec2(shader.primaryDetailMapScale),
                Vec2(shader.secondaryDetailMapScale),
                Vec2(shader.microDetailMapScale),
                Vec2(shader.bumpMapScale),
            ];

            pushConstants.perpendicularColor = ColorArgb(1.0f, shader.perpendicularColor) * shader.perpendicularBrightness;
            pushConstants.parallelColor      = ColorArgb(1.0f, shader.parallelColor)      * shader.parallelBrightness;
            pushConstants.lightmapIndex      = lightmap.bitmap;

            if(shader.reflectionType == TagEnums.ShaderEnvironmentReflectionType.bumpedCubeMap
                && shader.reflectionCubeMap)
            {
                pushConstants.specularColorControl = 1.0f; // todo remove this variable, use shader macro instead
            }
            else
            {
                pushConstants.specularColorControl = 0.0f;
            }

            vkCmdPushConstants(commandBuffer, sbspEnvPipelineLayout,
                VK_SHADER_STAGE_ALL_GRAPHICS, 0, EnvPushConstants.sizeof, &pushConstants);

            vkCmdDrawIndexed(commandBuffer, material.surfaceCount * 3, 1, material.surfaces * 3, vertexOffset, 0);

            break;
        default:
            continue;
        }
    }

}

void renderObject(
    ref FrameData     frame,
    uint              uniformBufferOffset,
    VkCommandBuffer   commandBuffer,
    int[]             permutations,
    GObject.Lighting* lighting,
    TagGbxmodel*      tagModel)
{
    foreach(i, ref region ; tagModel.regions)
    {
        // todo pixel cutoff

        int geometryIndex = region.permutations[permutations[i]].superHigh;
        auto geometry = &tagModel.geometries[geometryIndex];

        foreach(ref part ; geometry.parts)
        {
            auto tagShaderIndex = tagModel.shaders[part.shaderIndex].shader.index;
            auto baseShader = Cache.get!TagShader(tagShaderIndex);

            if(part.flags.zoner)
            {
                continue; // TODO support local nodes
            }

            ShaderInstance* shaderInstance = tagShaderIndex in shaderInstances;

            switch(baseShader.shaderType)
            {
            case TagEnums.ShaderType.chicago:
            case TagEnums.ShaderType.chicagoExtended:

                auto shader = cast(TagShaderTransparentChicagoExtended*)baseShader;

                if(shader.firstMapType != 0)
                {
                    // todo implement other types
                    // only support 2d texture for now
                    continue;
                }

                if(shaderInstance is null)
                {
                    ShaderInstance instance;

                    VkDescriptorSetLayout[1] layouts =
                    [
                        chicagoModelDescriptorSetLayout,
                    ];

                    VkDescriptorSetAllocateInfo allocInfo;
                    allocInfo.descriptorPool = descriptorPool;
                    allocInfo.setLayouts = layouts;

                    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &instance.descriptorSet));

                    FixedArray!(VkDescriptorImageInfo, 4) imageInfos;
                    FixedArray!(VkWriteDescriptorSet, 4) descriptorWrites;

                    Texture*[4] textures;

                    foreach(int stageIndex ; 0 .. 4)
                    {
                        DatumIndex mapIndex = stageIndex < shader.fourStageMaps.size
                            ? shader.fourStageMaps[stageIndex].map.index
                            : DatumIndex();

                        Texture** texture = &textures[stageIndex];
                        *texture = findOrLoadTexture2D(mapIndex, 0, DefaultTexture.additive);

                        VkDescriptorImageInfo imageInfo;
                        imageInfo.imageView = (*texture).imageView;
                        imageInfo.sampler = (*texture).sampler;
                        imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

                        imageInfos.add(imageInfo);

                        VkWriteDescriptorSet desc;
                        desc.dstSet = instance.descriptorSet;
                        desc.dstBinding = stageIndex;
                        desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                        desc.descriptorCount = 1;
                        desc.pImageInfo = &imageInfos[stageIndex];

                        descriptorWrites.add(desc);
                    }

                    vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);

                    shaderInstances[tagShaderIndex] = instance;
                    shaderInstance = &shaderInstances[tagShaderIndex];
                }


                ChicagoPushConstants pushConstants;

                foreach(int s, ref stage ; shader.fourStageMaps)
                {
                    if(s != shader.fourStageMaps.size - 1)
                    {
                        pushConstants.colorBlendFunc[s] = stage.colorFunction;
                        pushConstants.alphaBlendFunc[s] = stage.alphaFunction;
                    }

                    pushConstants.uvTransforms[s].zw = Vec2(stage.mapUScale, stage.mapVScale);
                }

                vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, chicagoModelPipeline);

                VkDescriptorSet[3] decriptorSets =
                [
                    frame.uniform.descriptorSet,
                    shaderInstance.descriptorSet,
                    frame.uniform.descriptorSet,
                ];

                uint[2] descriptorOffsets =
                [
                    sceneGlobalUniformOffset,
                    uniformBufferOffset,
                ];

                vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, chicagoModelPipelineLayout, 0,
                    decriptorSets.length32, decriptorSets.ptr, descriptorOffsets.length32, descriptorOffsets.ptr);

                vkCmdPushConstants(commandBuffer, chicagoModelPipelineLayout, VK_SHADER_STAGE_ALL_GRAPHICS,
                    0, ChicagoPushConstants.sizeof, &pushConstants);

                vkCmdDrawIndexed(commandBuffer, part.indexCount + 2, 1,
                    part.indexOffset / 2, part.vertexOffset / cast(uint)TagModelVertex.sizeof, 0);

                break;
            case TagEnums.ShaderType.model:
                auto shader = cast(TagShaderModel*)baseShader;

                if(shaderInstance is null)
                {
                    ShaderInstance instance;

                    VkDescriptorSetLayout[1] layouts =
                    [
                        modelShaderDescriptorSetLayout,
                    ];

                    VkDescriptorSetAllocateInfo allocInfo;
                    allocInfo.descriptorPool = descriptorPool;
                    allocInfo.setLayouts = layouts;

                    vkCheck(vkAllocateDescriptorSets(device, &allocInfo, &instance.descriptorSet));

                    FixedArray!(VkDescriptorImageInfo, 4) imageInfos;
                    FixedArray!(VkWriteDescriptorSet, 4) descriptorWrites;

                    Tuple!(DatumIndex, DefaultTexture)[4] textures =
                    [
                        tuple(shader.baseMap.index,           DefaultTexture.multiplicative),
                        tuple(shader.multipurposeMap.index,   DefaultTexture.additive),
                        tuple(shader.detailMap.index,         DefaultTexture.detail),
                        tuple(shader.reflectionCubeMap.index, DefaultTexture.vector),
                    ];

                    foreach(uint j, ref tex ; textures)
                    {
                        Texture* texture =
                            (j == 3)
                            ? findOrLoadTextureCubemap(tex[0], 0, tex[1])
                            : findOrLoadTexture2D(tex[0], 0, tex[1]);

                        VkDescriptorImageInfo imageInfo;
                        imageInfo.imageView = texture.imageView;
                        imageInfo.sampler = texture.sampler;
                        imageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;

                        imageInfos.add(imageInfo);

                        VkWriteDescriptorSet desc;
                        desc.dstSet = instance.descriptorSet;
                        desc.dstBinding = j;
                        desc.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
                        desc.descriptorCount = 1;
                        desc.pImageInfo = &imageInfos[j];

                        descriptorWrites.add(desc);
                    }

                    vkUpdateDescriptorSets(device, descriptorWrites.length, descriptorWrites.ptr, 0, null);

                    shaderInstances[tagShaderIndex] = instance;
                    shaderInstance = &shaderInstances[tagShaderIndex];
                }

                int maskIndex = (shader.detailMask + 1) / 2;
                int invert    = ((shader.detailMask + 1) % 2) == 0;

                ModelPushConstants pushConstants;

                pushConstants.uvScales[0]
                    = Vec2(shader.mapUScale * tagModel.baseMapUScale,shader.mapVScale * tagModel.baseMapVScale);
                pushConstants.uvScales[1] = Vec2(shader.detailMapScale);

                pushConstants.perpendicularColor = shader.perpendicularTintColor * shader.perpendicularBrightness;
                pushConstants.parallelColor      = shader.parallelTintColor      * shader.parallelBrightness;

                pushConstants.ambientColor = lighting.ambientColor;

                foreach(int j, ref light ; pushConstants.distantLights)
                {
                    light.color     = lighting.distantLight[j].color;
                    light.direction = lighting.distantLight[j].direction;
                }

                vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
                    modelShaderPipelines[shader.flags.detailAfterReflection][shader.detailFunction][invert][maskIndex]);

                VkDescriptorSet[3] decriptorSets =
                [
                    frame.uniform.descriptorSet,
                    shaderInstance.descriptorSet,
                    frame.uniform.descriptorSet,
                ];

                uint[2] descriptorOffsets =
                [
                    sceneGlobalUniformOffset,
                    uniformBufferOffset,
                ];

                vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, modelShaderPipelineLayout, 0,
                    decriptorSets.length32, decriptorSets.ptr, descriptorOffsets.length32, descriptorOffsets.ptr);

                vkCmdPushConstants(commandBuffer, modelShaderPipelineLayout, VK_SHADER_STAGE_ALL_GRAPHICS,
                    0, pushConstants.sizeof, &pushConstants);

                vkCmdDrawIndexed(commandBuffer, part.indexCount + 2, 1,
                    part.indexOffset / 2, part.vertexOffset / cast(uint)TagModelVertex.sizeof, 0);

                break;
            default:
            }
        }
    }

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

    auto sbsp = world.getCurrentSbsp();

    lighting.pointLightCount = 0;

    if(sbsp.defaultAmbientColor == ColorRgb(0.0f))
    {
        lighting.ambientColor = ColorRgb(0.2f);

        lighting.distantLightCount = 2;

        lighting.distantLight[0].color     = ColorRgb(1.0f);
        lighting.distantLight[0].direction = Vec3(-1.0f / sqrt(3.0f));

        lighting.distantLight[1].color     = ColorRgb(0.4f, 0.4f, 0.5f);
        lighting.distantLight[1].direction = Vec3(0, 0, 1);

        lighting.reflectionTint = ColorArgb(0.5f, 1.0f, 1.0f, 1.0f);
        lighting.shadowVector   = Vec3(0, 0, -1);
        lighting.shadowColor    = ColorRgb(0);
    }
    else
    {
        lighting.ambientColor = sbsp.defaultAmbientColor;

        lighting.distantLightCount = 2;

        lighting.distantLight[0].color     = sbsp.defaultDistantLight0Color;
        lighting.distantLight[0].direction = sbsp.defaultDistantLight0Direction;

        lighting.distantLight[1].color     = sbsp.defaultDistantLight1Color;
        lighting.distantLight[1].direction = sbsp.defaultDistantLight1Direction;

        lighting.reflectionTint = sbsp.defaultReflectionTint;
        lighting.shadowVector   = sbsp.defaultShadowVector;
        lighting.shadowColor    = sbsp.defaultShadowColor;

    }

    const(Vec3)* segments;
    int          segmentCount;

    if(options.calculateColorFromSides)
    {
        immutable Vec3[4] directions =
        [
            Vec3(-10, 0, 0),
            Vec3( 10, 0, 0),
            Vec3(0, -10, 0),
            Vec3(0,  10, 0),
        ];

        segments     = directions.ptr;
        segmentCount = directions.length;
    }
    else
    {
        immutable Vec3[1] directions = [ Vec3(0, 0, -10) ];

        segments     = directions.ptr;
        segmentCount = directions.length;
    }

    bool result = false;

    foreach(ref const(Vec3) segment ; segments[0 .. segmentCount])
    {
        World.RenderSurfaceResult renderResult;

        if(!world.collideRenderLine(position, segment, renderResult))
        {
            continue;
        }

        auto lightmap = &sbsp.lightmaps[renderResult.lightmapIndex];
        auto material = &lightmap.materials[renderResult.materialIndex];

        auto shader = Cache.get!TagShaderEnvironment(material.shader);

        if(shader.shaderType != TagEnums.ShaderType.environment
            || sbsp.lightmapsBitmap.isIndexNone()
            || lightmap.bitmap == indexNone
            || shader.baseMap.isIndexNone())
        {
            return false;
        }

        auto lightmapBitmap = Cache.get!TagBitmap(sbsp.lightmapsBitmap).bitmapAt(lightmap.bitmap);
        auto baseMap = Cache.get!TagBitmap(shader.baseMap);

        int baseBitmapIndex = material.shaderPermutation % baseMap.bitmaps.size;
        auto baseBitmap = baseMap.bitmapAt(baseBitmapIndex);

        if(!lightmapBitmap || !baseBitmap)
        {
            return false;
        }

        ubyte[] lightmapPixels = grabPixelDataFromBitmap(sbsp.lightmapsBitmap.index, lightmap.bitmap);
        ubyte[] baseMapPixels  = grabPixelDataFromBitmap(shader.baseMap.index, baseBitmapIndex);

        TagBspVertex*[3] vert;
        TagBspLightmapVertex*[3] lmVert;

        if(!renderResult.getSurfaceVertices(sbsp, vert) || !renderResult.getLightmapVertices(sbsp, lmVert))
        {
            return false;
        }

        Vec2 uv   = barycentricInterpolate(vert[0].coord, vert[1].coord, vert[2].coord, renderResult.coord);
        Vec2 lmUv = barycentricInterpolate(lmVert[0].coord, lmVert[1].coord, lmVert[2].coord, renderResult.coord);

        Vec3 normal = barycentricInterpolate(vert[0].normal, vert[1].normal, vert[2].normal, renderResult.coord);
        Vec3 lmNormal;
        float lmNormalLength;

        {
            Vec3 a = lmVert[0].normal; float aLength = normalize(a);
            Vec3 b = lmVert[1].normal; float bLength = normalize(b);
            Vec3 c = lmVert[2].normal; float cLength = normalize(c);

            lmNormal = barycentricInterpolate(a, b, c, renderResult.coord);
            lmNormalLength = barycentricInterpolate(aLength, bLength, cLength, renderResult.coord);
        }

        normalize(normal);
        normalize(lmNormal);

        ColorRgb diffuseColor  = baseBitmap.pixelColorAt(baseMapPixels, uv, 0.7f);
        ColorRgb lightmapColor = lightmapBitmap.pixelColorAt(lightmapPixels, lmUv, 0.0f);

        float c0 = dot(lightmapColor.asVector, Vec3(0.299f, 0.587f, 0.114f));

        lighting.ambientColor = ColorRgb(0.4f) * lightmapColor + ColorRgb(0.03f);

        lighting.distantLight[0].color     = lightmapColor;
        lighting.distantLight[0].direction = -lmNormal;
        lighting.distantLight[1].color     = diffuseColor * c0;
        lighting.distantLight[1].direction = normal;
        lighting.distantLightCount = 2;

        lighting.reflectionTint.a   = saturate(c0 * 1.5f + 0.25f);
        lighting.reflectionTint.rgb = saturate(lightmapColor * 2 + 0.25f) * saturate(diffuseColor * 3 + 0.5f);

        enum float littleSqrt1_2 = SQRT1_2 - 0.0001f;

        Vec2  flatNormal = (lmNormalLength ^^ 0.25f) * lighting.distantLight[0].direction.xy;
        float flatLength = length(flatNormal);

        if(flatLength >= littleSqrt1_2)
        {
            lighting.shadowVector.xy = flatNormal * (littleSqrt1_2 / flatLength);
            lighting.shadowVector.z  = -littleSqrt1_2;
        }
        else
        {
            lighting.shadowVector.xy = flatNormal;
            lighting.shadowVector.z  = -sqrt(1.0f - sqr(flatLength));
        }

        float additive = (1.0f - lmNormalLength) * 0.5f;
        lighting.shadowColor = clamp((additive + 1.0f) - lighting.distantLight[0].color, 0.03f, 1.0f);

        if(options.brighterThanItShouldBe)
        {
            static ColorRgb brighten(ColorRgb color, float adjustment)
            {
                float maximum = max(color.r, max(color.g, color.b));

                if(maximum == 0.0f)
                {
                    return color;
                }

                float adjustedMaximum = maximum * (1.0f + adjustment);

                if(adjustedMaximum <= 1.0f)
                {
                    if(adjustedMaximum >= adjustment)
                    {
                        return color * (1.0f + adjustment);
                    }

                    return color * (adjustment / maximum);
                }

                return color * (1.0f / maximum);
            }

            lighting.ambientColor          = brighten(lighting.ambientColor,          0.2f);
            lighting.distantLight[0].color = brighten(lighting.distantLight[0].color, 0.3f);
            lighting.distantLight[1].color = brighten(lighting.distantLight[1].color, 0.2f);
            lighting.reflectionTint.rgb    = brighten(lighting.reflectionTint.rgb,    0.5f);
            lighting.reflectionTint.a      = 1.0f;
        }

        return true;
    }

    return false;
}

Texture* findOrLoadTexture2D(DatumIndex tagIndex, int bitmapIndex, DefaultTexture defaultType)
{
    return findOrLoadTexture(tagIndex, bitmapIndex, Cache.inst.globals.rasterizerData.default2d.index, defaultType);
}

Texture* findOrLoadTextureCubemap(DatumIndex tagIndex, int bitmapIndex, DefaultTexture defaultType)
{
    return findOrLoadTexture(tagIndex, bitmapIndex, Cache.inst.globals.rasterizerData.defaultCubeMap.index, defaultType);
}

Texture* findOrLoadTexture(DatumIndex tagIndex, int bitmapIndex, DatumIndex defaultIndex, DefaultTexture defaultType)
{
    Tag.BitmapDataBlock* bitmap;

    if(tagIndex == DatumIndex.none)  bitmap = &Cache.get!TagBitmap(defaultIndex).bitmaps[int(defaultType)];
    else                             bitmap = &Cache.get!TagBitmap(tagIndex).bitmaps[bitmapIndex];

    if(bitmap.glTexture == indexNone)
    {
        byte[] buffer = new byte[](bitmap.pixelsSize);

        if(bitmap.flags.externalPixelData) Cache.inst.bitmapCache.read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);
        else                               Cache.inst            .read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);

        Texture texture;

        if(loadPixelData(bitmap, buffer, texture))
        {
            bitmap.glTexture = textureInstances.add(texture);
            return &textureInstances[bitmap.glTexture];
        }
        else
        {
            bitmap.glTexture = indexNone - 1;
        }
    }
    else if(bitmap.glTexture != indexNone - 1)
    {
        return &textureInstances[bitmap.glTexture];
    }

    return null;
}

bool pixelFormatNeedsPreprocessing(TagEnums.BitmapPixelFormat format)
{
    switch(format) with(TagEnums)
    {
    case BitmapPixelFormat.dxt1:
    case BitmapPixelFormat.dxt3:
    case BitmapPixelFormat.dxt5:
        return !hasTextureCompressionBc;
    default:
    }

    return false;
}

static uint calculateProcessedSize(Tag.BitmapDataBlock* bitmap)
{
    uint result = 0;

    foreach(i ; 0 .. bitmap.mipmapCount + 1)
    {
        result += max(1, bitmap.width >> i) * max(1, bitmap.height >> i);
    }

    return result * 4;
}

auto copyPixelsToBuffer(Tag.BitmapDataBlock* bitmap, byte[] buffer)
{
    import Game.Render.Dxt;

    static struct Result
    {
        TagEnums.BitmapPixelFormat format;
        VkDevice device;
        VkBuffer buffer;
        VkDeviceMemory bufferMemory;

        @disable this(this);

        ~this()
        {
            if(buffer)       vkDestroyBuffer(device, buffer, null);
            if(bufferMemory) vkFreeMemory(device, bufferMemory, null);
       }
    }

    Result result = Result(bitmap.format, device);

    if(pixelFormatNeedsPreprocessing(bitmap.format))
    {
        result.format = TagEnums.BitmapPixelFormat.a8r8g8b8;
        uint dstBufferSize = calculateProcessedSize(bitmap);

        createBuffer(dstBufferSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            result.buffer, result.bufferMemory);

        void* data;
        vkMapMemory(device, result.bufferMemory, 0, dstBufferSize, 0, &data);

        ColorArgb8[] pixels = cast(ColorArgb8[])data[0 .. dstBufferSize];

        switch(bitmap.format) with(TagEnums)
        {
        case BitmapPixelFormat.dxt1:
            Dxt1Block[] blocks = cast(Dxt1Block[])buffer;

            foreach(m ; 0 .. bitmap.mipmapCount + 1)
            {
                uint width  = max(1, bitmap.width  >> m);
                uint height = max(1, bitmap.height >> m);

                uint xBlocks = max(1, width  / 4);
                uint yBlocks = max(1, height / 4);

                foreach(y ; 0 .. yBlocks)
                foreach(x ; 0 .. xBlocks)
                {
                    ColorArgb8[4][4] colors = void;

                    blocks[y * xBlocks + x].decode(colors);

                    foreach(j ; 0 .. min(4, height))
                    foreach(i ; 0 .. min(4, width))
                    {
                        auto c = colors[j][i];
                        pixels[width * (y * 4 + j) + (x * 4 + i)] = ColorArgb8(c.b, c.g, c.r, c.a);
                    }
                }

                blocks = blocks[xBlocks * yBlocks .. $];
                pixels = pixels[width * height .. $];
            }

            break;
        case BitmapPixelFormat.dxt3:
            Dxt3Block[] blocks = cast(Dxt3Block[])buffer;

            foreach(m ; 0 .. bitmap.mipmapCount + 1)
            {
                uint width  = max(1, bitmap.width  >> m);
                uint height = max(1, bitmap.height >> m);

                uint xBlocks = max(1, width  / 4);
                uint yBlocks = max(1, height / 4);

                foreach(y ; 0 .. yBlocks)
                foreach(x ; 0 .. xBlocks)
                {
                    ColorArgb8[4][4] colors = void;

                    blocks[y * xBlocks + x].decode(colors);

                    foreach(j ; 0 .. min(4, height))
                    foreach(i ; 0 .. min(4, width))
                    {
                        auto c = colors[j][i];
                        pixels[width * (y * 4 + j) + (x * 4 + i)] = ColorArgb8(c.b, c.g, c.r, c.a);
                    }
                }

                blocks = blocks[xBlocks * yBlocks .. $];
                pixels = pixels[width * height .. $];
            }
            break;
        case BitmapPixelFormat.dxt5:
            Dxt5Block[] blocks = cast(Dxt5Block[])buffer;

            foreach(m ; 0 .. bitmap.mipmapCount + 1)
            {
                uint width  = max(1, bitmap.width  >> m);
                uint height = max(1, bitmap.height >> m);

                uint xBlocks = max(1, width  / 4);
                uint yBlocks = max(1, height / 4);

                foreach(y ; 0 .. yBlocks)
                foreach(x ; 0 .. xBlocks)
                {
                    ColorArgb8[4][4] colors = void;

                    blocks[y * xBlocks + x].decode(colors);

                    foreach(j ; 0 .. min(4, height))
                    foreach(i ; 0 .. min(4, width))
                    {
                        auto c = colors[j][i];
                        pixels[width * (y * 4 + j) + (x * 4 + i)] = ColorArgb8(c.b, c.g, c.r, c.a);
                    }
                }

                blocks = blocks[xBlocks * yBlocks .. $];
                pixels = pixels[width * height .. $];
            }
            break;
        default:
            assert(0);
        }

        vkUnmapMemory(device, result.bufferMemory);
    }
    else
    {
        createBuffer(buffer.length32, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            result.buffer, result.bufferMemory);

        void* data;
        vkMapMemory(device, result.bufferMemory, 0, buffer.length32, 0, &data);
        data[0 .. buffer.length32] = buffer[];
        vkUnmapMemory(device, result.bufferMemory);
    }


    return result;
}

bool loadPixelData(Tag.BitmapDataBlock* bitmap, byte[] buffer, ref Texture texture)
{
    import Game.Render.Private.Pixels;

    if(bitmap.glTexture != indexNone || !pixelFormatSupported(bitmap.format))
    {
        return false;
    }

    switch(bitmap.type)
    {
    default:
        return false;
    case TagEnums.BitmapType.texture2d:

        auto staging = copyPixelsToBuffer(bitmap, buffer);


        VkImageCreateInfo imageInfo;

        imageInfo.imageType     = VK_IMAGE_TYPE_2D;
        imageInfo.extent.width  = bitmap.width;
        imageInfo.extent.height = bitmap.height;
        imageInfo.extent.depth  = 1;
        imageInfo.mipLevels     = bitmap.mipmapCount + 1;
        imageInfo.arrayLayers   = 1;
        imageInfo.format        = getPixelFormat(staging.format);
        imageInfo.tiling        = VK_IMAGE_TILING_OPTIMAL;
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage         = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
        imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT;
        imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;

        vkCreateImage(device, &imageInfo, null, &texture.image);

        VkMemoryRequirements memRequirements;
        vkGetImageMemoryRequirements(device, texture.image, &memRequirements);

        VkMemoryAllocateInfo allocInfo;
        allocInfo.allocationSize  = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        vkAllocateMemory(device, &allocInfo, null, &texture.imageMemory);
        vkBindImageMemory(device, texture.image, texture.imageMemory, 0);

        uint offset = 0;
        foreach(i ; 0 .. bitmap.mipmapCount + 1)
        {
            uint width  = max(1, bitmap.width  >> i);
            uint height = max(1, bitmap.height >> i);

            // TODO optimize, too many command buffers being used here
            //      each transition uses it's own one time buffer, entire process can use one command buffer

            transitionImageLayout(texture.image, i, 1, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

            VkCommandBuffer commandBuffer = beginSingleTimeCommands();

            VkBufferImageCopy region;
            region.bufferOffset                = offset;
            region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            region.imageSubresource.mipLevel   = i;
            region.imageSubresource.layerCount = 1;
            region.imageExtent                 = VkExtent3D(width, height, 1);

            vkCmdCopyBufferToImage(commandBuffer, staging.buffer, texture.image,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
            endSingleTimeCommands(commandBuffer);

            transitionImageLayout(texture.image, i, 1, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

            offset += pixelFormatSize(staging.format, width, height);
        }

        VkImageViewCreateInfo viewCreateInfo;

        viewCreateInfo.image = texture.image;
        viewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        viewCreateInfo.format = getPixelFormat(staging.format);
        viewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        viewCreateInfo.subresourceRange.baseMipLevel = 0;
        viewCreateInfo.subresourceRange.levelCount = bitmap.mipmapCount + 1;
        viewCreateInfo.subresourceRange.baseArrayLayer = 0;
        viewCreateInfo.subresourceRange.layerCount = 1;

        vkCheck(vkCreateImageView(device, &viewCreateInfo, null, &texture.imageView));

        // TODO don't create a new sampler for each texture, they can be reused.
        VkSamplerCreateInfo samplerInfo;
        samplerInfo.magFilter = VK_FILTER_LINEAR;
        samplerInfo.minFilter = VK_FILTER_LINEAR;
        samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_REPEAT;
        samplerInfo.anisotropyEnable = VK_TRUE;
        samplerInfo.maxAnisotropy = 16;

        samplerInfo.borderColor = VK_BORDER_COLOR_INT_OPAQUE_BLACK;
        samplerInfo.unnormalizedCoordinates = VK_FALSE;
        samplerInfo.compareEnable = VK_FALSE;
        samplerInfo.compareOp = VK_COMPARE_OP_ALWAYS;
        samplerInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
        samplerInfo.mipLodBias = 0.0f;
        samplerInfo.minLod = 0.0f;
        samplerInfo.maxLod = 10.0f;

        vkCheck(vkCreateSampler(device, &samplerInfo, null, &texture.sampler));

        return true;
    case TagEnums.BitmapType.cubeMap:
        VkBuffer stagingBuffer;
        VkDeviceMemory stagingBufferMemory;
        createBuffer(buffer.length32, VK_BUFFER_USAGE_TRANSFER_SRC_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, stagingBuffer, stagingBufferMemory);
        scope(exit)
        {
            vkDestroyBuffer(device, stagingBuffer, null);
            vkFreeMemory(device, stagingBufferMemory, null);
        }

        VkImageCreateInfo imageInfo;

        imageInfo.imageType     = VK_IMAGE_TYPE_2D;
        imageInfo.extent.width  = bitmap.width;
        imageInfo.extent.height = bitmap.height;
        imageInfo.extent.depth  = 1;
        imageInfo.mipLevels     = bitmap.mipmapCount + 1;
        imageInfo.arrayLayers   = 6;
        imageInfo.format        = getPixelFormat(bitmap.format);
        imageInfo.tiling        = VK_IMAGE_TILING_OPTIMAL;
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage         = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
        imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT;
        imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE;
        imageInfo.flags         = VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT;

        vkCreateImage(device, &imageInfo, null, &texture.image);

        VkMemoryRequirements memRequirements;
        vkGetImageMemoryRequirements(device, texture.image, &memRequirements);

        VkMemoryAllocateInfo allocInfo;
        allocInfo.allocationSize  = memRequirements.size;
        allocInfo.memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

        vkAllocateMemory(device, &allocInfo, null, &texture.imageMemory);
        vkBindImageMemory(device, texture.image, texture.imageMemory, 0);

        uint offset = 0;
        foreach(i ; 0 .. bitmap.mipmapCount + 1)
        {
            uint width  = max(1, bitmap.width  >> i);
            uint height = max(1, bitmap.height >> i);

            static immutable sides = [ 0, 2, 1, 3, 4, 5 ];

            // TODO optimize, too many command buffers being used here
            //      each transition uses it's own one time buffer, entire process can use one command buffer

            transitionImageLayout(texture.image, i, 6, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);

            foreach(face ; 0 .. 6)
            {
                uint size = pixelFormatSize(bitmap.format, width, height);

                void* data;
                vkMapMemory(device, stagingBufferMemory, 0, size, 0, &data);
                data[0 .. size] = buffer[offset .. offset + size];
                vkUnmapMemory(device, stagingBufferMemory);

                VkCommandBuffer commandBuffer = beginSingleTimeCommands();

                VkBufferImageCopy region;
                region.bufferOffset                = 0;
                region.imageExtent                 = VkExtent3D(width, height, 1);
                region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
                region.imageSubresource.mipLevel   = i;
                region.imageSubresource.layerCount = 1;
                region.imageSubresource.baseArrayLayer = sides[face];

                vkCmdCopyBufferToImage(commandBuffer, stagingBuffer, texture.image,
                    VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
                endSingleTimeCommands(commandBuffer);

                offset += size;
            }

            transitionImageLayout(texture.image, i, 6, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
        }

        VkImageViewCreateInfo viewCreateInfo;

        viewCreateInfo.image = texture.image;
        viewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_CUBE;
        viewCreateInfo.format = getPixelFormat(bitmap.format);
        viewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        viewCreateInfo.subresourceRange.baseMipLevel = 0;
        viewCreateInfo.subresourceRange.levelCount = bitmap.mipmapCount + 1;
        viewCreateInfo.subresourceRange.baseArrayLayer = 0;
        viewCreateInfo.subresourceRange.layerCount = 6;

        vkCheck(vkCreateImageView(device, &viewCreateInfo, null, &texture.imageView));

        // TODO don't create a new sampler for each texture, they can be reused.
        VkSamplerCreateInfo samplerInfo;
        samplerInfo.magFilter = VK_FILTER_LINEAR;
        samplerInfo.minFilter = VK_FILTER_LINEAR;
        samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        samplerInfo.anisotropyEnable = VK_TRUE;
        samplerInfo.maxAnisotropy = 16;

        samplerInfo.borderColor = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
        samplerInfo.unnormalizedCoordinates = VK_FALSE;
        samplerInfo.compareEnable = VK_FALSE;
        samplerInfo.compareOp = VK_COMPARE_OP_NEVER;
        samplerInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
        samplerInfo.mipLodBias = 0.0f;
        samplerInfo.minLod = 0.0f;
        samplerInfo.maxLod = 0.0f;

        vkCheck(vkCreateSampler(device, &samplerInfo, null, &texture.sampler));

        return true;
    }

    return false;
}

void renderImGui(ref FrameData frame, VkCommandBuffer commandBuffer)
{
    auto io = igGetIO();
    ImDrawData* drawData = igGetDrawData();

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, imguiPipeline);

    VkDescriptorSet[1] decriptorSets =
    [
        imguiDescriptorSet
    ];

    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS,
        imguiPipelineLayout, 0, decriptorSets.length32, decriptorSets.ptr, 0, null);

    VkBuffer[1] vertexBuffers = [ frame.vertex.buffer ];
    VkDeviceSize[1] offsets = [ imguiVertexBufferOffset ];

    vkCmdBindVertexBuffers(commandBuffer, 0, vertexBuffers.length32, vertexBuffers.ptr, offsets.ptr);
    vkCmdBindIndexBuffer(commandBuffer, frame.index.buffer, imguiIndexBufferOffset, VK_INDEX_TYPE_UINT16);

    ImguiPushConstants pushConstants;

    pushConstants.scale = 2.0f / io.DisplaySize;
    pushConstants.translate  = Vec2(-1.0f);

    vkCmdPushConstants(commandBuffer, imguiPipelineLayout,
        VK_SHADER_STAGE_VERTEX_BIT, 0, ImguiPushConstants.sizeof, &pushConstants);

    uint vertexOffset;
    uint indexOffset;
    foreach(ImDrawList* cmdList ; drawData.CmdLists[0 .. drawData.CmdListsCount])
    {
        foreach(ref ImDrawCmd cmd ; cmdList.CmdBuffer)
        {
            VkRect2D scissor;
            scissor.offset.x      = cast(int)max(cmd.ClipRect.x, 0.0f);
            scissor.offset.y      = cast(int)max(cmd.ClipRect.y, 0.0f);
            scissor.extent.width  = cast(uint)(cmd.ClipRect.z - cmd.ClipRect.x);
            scissor.extent.height = cast(uint)(cmd.ClipRect.w - cmd.ClipRect.y);

            vkCmdSetScissor(commandBuffer, 0, 1, &scissor);
            vkCmdDrawIndexed(commandBuffer, cmd.ElemCount, 1, indexOffset, vertexOffset, 0);

            indexOffset += cmd.ElemCount;
        }

        vertexOffset += cmdList.VtxBuffer.Size;
    }
}
}

// End //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

private ubyte[][uint] gBitmapLoadedPixels;

private ubyte[] grabPixelDataFromBitmap(DatumIndex index, int bitmapIndex)
{
    union Hash
    {
        uint value;
        struct
        {
            short tagIndex;
            short bitmapIndex;
        }
    }

    Hash hash;

    hash.tagIndex    = index.i;
    hash.bitmapIndex = cast(short)bitmapIndex;

    if(auto pixels = hash.value in gBitmapLoadedPixels)
    {
        return *pixels;
    }
    else
    {
        TagBitmap* tagBitmap = Cache.get!TagBitmap(index);
        auto       bitmap    = &tagBitmap.bitmaps[bitmapIndex];

        ubyte[] buffer = new ubyte[](bitmap.pixelsSize);

        if(bitmap.flags.externalPixelData) Cache.inst.bitmapCache.read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);
        else                               Cache.inst            .read(bitmap.pixelsOffset, buffer.ptr, bitmap.pixelsSize);

        gBitmapLoadedPixels[hash.value] = buffer;

        return buffer;
    }
}

