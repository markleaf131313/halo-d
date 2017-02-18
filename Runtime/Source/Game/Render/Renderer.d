
module Game.Render.Renderer;

import std.container.array;
import std.conv : to;
import std.file : readText;
import std.meta : AliasSeq;

import OpenGL;
import SDL2;
import ImGui;

import Game.Render.Camera;
import Game.Render.Framebuffer;
import Game.Render.ShaderPreprocessor;
import Game.Render.Shader;
import Game.Render.ShaderTypes;
import Game.Render.VertexArray;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World;



struct Renderer
{

@disable this(this);

void load()
{
    int width  = 1920; // todo unhardcode
    int height = 810;

    framebuffer = GLFramebuffer.make(width, height);

    framebuffer.attach(GL_COLOR_ATTACHMENT0, GL_RGBA8, GL_LINEAR);
    framebuffer.attach(GL_COLOR_ATTACHMENT1, GL_RGBA8, GL_LINEAR);
    framebuffer.attach(GL_COLOR_ATTACHMENT2, GL_RGBA16, GL_LINEAR);
    framebuffer.attach(GL_DEPTH_ATTACHMENT, GL_DEPTH_COMPONENT24, GL_LINEAR);

    framebuffer.finalize();


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
            structureVertexIndexOffsets[i][j] = cast(int)bspVertices.length;

            uint vertexCount       = material.vertexBuffers[0].count;
            TagBspVertex* vertices = material.uncompressedVertices.dataAs!TagBspVertex;

            bspVertices         ~= vertices[0 .. vertexCount];
            lightmapBspVertices ~= (cast(TagBspLightmapVertex*)&vertices[vertexCount])[0 .. vertexCount];
        }
    }

    sbspVertexArray = GLVertexArray.make();
    sbspVertexArray
        .attribFormat(0, 0, 3, GL_FLOAT, TagBspVertex.position.offsetof)
        .attribFormat(1, 0, 3, GL_FLOAT, TagBspVertex.normal.offsetof)
        .attribFormat(2, 0, 3, GL_FLOAT, TagBspVertex.binormal.offsetof)
        .attribFormat(3, 0, 3, GL_FLOAT, TagBspVertex.tangent.offsetof)
        .attribFormat(4, 0, 2, GL_FLOAT, TagBspVertex.coord.offsetof)
        .attribFormat(5, 1, 3, GL_FLOAT, TagBspLightmapVertex.normal.offsetof)
        .attribFormat(6, 1, 2, GL_FLOAT, TagBspLightmapVertex.coord.offsetof)
        .createBuffer(0, bspVertices.length * TagBspVertex.sizeof, bspVertices.ptr, GL_STATIC_DRAW)
        .createBuffer(1, lightmapBspVertices.length * TagBspLightmapVertex.sizeof,
            lightmapBspVertices.ptr, GL_STATIC_DRAW)
        .createBuffer(2, sbsp.surfaces.size * 6, sbsp.surfaces.ptr, GL_STATIC_DRAW)
        .vertexBuffer(0, 0, 0, TagBspVertex.sizeof)
        .vertexBuffer(1, 1, 0, TagBspLightmapVertex.sizeof)
        .elementBuffer(2);


    ubyte[] vertexData;
    ubyte[] indexData;

    Cache.inst.readModelVertexData(vertexData, indexData);

    modelVertexArray = GLVertexArray.make();
    modelVertexArray
        .attribFormat(0, 0, 3, GL_FLOAT, TagModelVertex.position.offsetof)
        .attribFormat(1, 0, 3, GL_FLOAT, TagModelVertex.normal.offsetof)
        .attribFormat(2, 0, 2, GL_FLOAT, TagModelVertex.uv.offsetof)
        .attribIFormat(3, 0, 2, GL_SHORT, TagModelVertex.node0.offsetof)
        .attribFormat(4, 0, 2, GL_FLOAT, TagModelVertex.weight.offsetof)
        .createBuffer(0, vertexData.length, vertexData.ptr, GL_STATIC_DRAW)
        .createBuffer(1, indexData.length, indexData.ptr, GL_STATIC_DRAW)
        .vertexBuffer(0, 0, 0, TagModelVertex.sizeof)
        .elementBuffer(1);

    simpleVertexArray = GLVertexArray.make();
    simpleVertexArray
        .attribFormat(0, 0, 2, GL_FLOAT, 0)
        .attribFormat(1, 0, 2, GL_FLOAT, 8)
        .createBuffer(0)
        .vertexBuffer(0, 0, 0, 16);

    simpleWorldVertexArray = GLVertexArray.make();
    simpleWorldVertexArray
        .attribFormat(0, 0, 3, GL_FLOAT, SimpleWorldVertex.position.offsetof)
        .attribFormat(1, 0, 3, GL_UNSIGNED_BYTE, SimpleWorldVertex.color.offsetof, true)
        .createBuffer(0)
        .vertexBuffer(0, 0, 0, SimpleWorldVertex.sizeof);


    imguiVertexArray = GLVertexArray.make();
    imguiVertexArray
        .attribFormat(0, 0, 2, GL_FLOAT, ImDrawVert.pos.offsetof)
        .attribFormat(1, 0, 2, GL_FLOAT, ImDrawVert.uv.offsetof)
        .attribFormat(2, 0, 4, GL_UNSIGNED_BYTE, ImDrawVert.col.offsetof, true)
        .createBuffer(0)
        .vertexBuffer(0, 0, 0, ImDrawVert.sizeof)
        .createBuffer(1)
        .elementBuffer(1);

    // todo make some sort of mesh class instead ?

    SimpleWorldVertex[] vertices;

    for(int i = 0; i < 128; ++i)
    {
        Renderer.SimpleWorldVertex v;

        float a = (i / 127.0f) * PI * 2;
        float b = ((i + 1) % 128 / 127.0f) * PI * 2;

        float c0 = cos(a); float s0 = sin(a);
        float c1 = cos(b); float s1 = sin(b);

        vertices ~= SimpleWorldVertex(Vec3(s0, 0, c0));
        vertices ~= SimpleWorldVertex(Vec3(s1, 0, c1));

        vertices ~= SimpleWorldVertex(Vec3(0, s0, c0));
        vertices ~= SimpleWorldVertex(Vec3(0, s1, c1));

        vertices ~= SimpleWorldVertex(Vec3(s0, c0, 0));
        vertices ~= SimpleWorldVertex(Vec3(s1, c1, 0));
    }

    sphereVertexArray = GLVertexArray.make();
    sphereVertexArray
        .attribFormat(0, 0, 3, GL_FLOAT, SimpleWorldVertex.position.offsetof)
        .attribFormat(1, 0, 3, GL_UNSIGNED_BYTE, SimpleWorldVertex.color.offsetof, true)
        .createBuffer(0, vertices.length * SimpleWorldVertex.sizeof, vertices.ptr, GL_STATIC_DRAW)
        .vertexBuffer(0, 0, 0, SimpleWorldVertex.sizeof);

    sphereVertexCount = cast(int)vertices.length;

}

void loadShaders()
{
    loadEnvironmentShaders();
    loadModelShaders();
    loadChicagoShaders();
    simpleShader      = GLShader!void.make("simple", import("Simple.vert"), import("Simple.frag"));
    imguiShader       = GLShader!void.make("imgui",  import("Imgui.vert"),  import("Imgui.frag"));
    simpleWorldShader = GLShader!void.make("simpleWorld", import("SimpleWorld.vert"), import("SimpleWorld.frag"));
}

void render(ref World world, ref Camera camera)
{
    framebuffer.bind();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    TagScenario* scenario = Cache.inst.scenario();
    TagScenarioStructureBsp* sbsp = Cache.get!TagScenarioStructureBsp(scenario.structureBsps[0].structureBsp);

    // Render Sky ///////////////////////////////////////////////////////////////////////////////////////////////////////////

    modelVertexArray.bind();

    if(scenario.skies)
    {
        GObject.Lighting lighting; // TODO(HACK, REFACTOR) need to fill default color, most sky don't use this tho so..

        auto tagSky   = Cache.get!TagSky(scenario.skies[0].sky);
        auto tagModel = Cache.get!TagGbxmodel(tagSky.model);

        Mat4x3[TagConstants.Animation.maxNodes] matrices = Mat4x3(1.0f / 1024.0f);
        matrices[0][3] = camera.position;
        int[TagConstants.Model.maxRegions] permutations;

        renderObject(camera, permutations, &lighting, tagModel, matrices);

    }

    // Render structure Bsp /////////////////////////////////////////////////////////////////////////////////////////////////

    sbspVertexArray.bind();

    foreach(int i, ref lightmap ; sbsp.lightmaps)
    {
        if(lightmap.bitmap != indexNone)
        {
            renderOpaqueStructureBsp(camera, sbsp, i);
        }
    }

    modelVertexArray.bind();

    foreach(ref overseer ; world.objects)
    {
        Mat4x3[TagConstants.Animation.maxNodes] inversedMatrices = void;
        auto object = overseer.ptr;

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
                inversedMatrices[i] = transform.toMat4x3WithScale();
            }

            renderObject(camera, object.regionPermutationIndices,
                &object.cachedLighting.desired, tagModel, inversedMatrices);
        }
    }


    // Render Object Bounding Spheres ///////////////////////////////////////////////////////////////////////////////////////

    glBindVertexArray(0);

    simpleWorldShader.useProgram();
    sphereVertexArray.bind();

    foreach(ref overseer ; world.objects)
    {
        auto object = overseer.ptr;

        if(!object.flags.hidden)
        {
            if(object.type == TagEnums.ObjectType.biped)
            {
                Biped* biped = cast(Biped*)object;

                const tagBiped = Cache.get!TagBiped(biped.tagIndex);

                Vec3  position = biped.position;
                float radius = tagBiped.collisionRadius;
                float height = tagBiped.standingCollisionHeight
                    - (tagBiped.standingCollisionHeight - tagBiped.crouchingCollisionHeight)
                    * biped.crouchPercent;


                Vec3 capsuleBottomCenter = position + Vec3(0, 0, radius);
                float capsuleHeight      = height - radius * 2.0f;
                float capsuleRadius      = radius;


                float halfHeight = capsuleHeight * 0.5f;

                Vec3  center = capsuleBottomCenter + Vec3(0, 0, halfHeight);
                float r      = radius              + halfHeight;

                Transform transform = Transform(r, object.rotation.toMat3(),center);

                simpleWorldShader.setUniform(0, camera.viewproj * transform.toMat4());

                glDrawArrays(GL_LINES, 0, sphereVertexCount);

            }
            else
            {
                Transform transform = Transform(object.bound.radius, object.rotation.toMat3(), object.bound.center);

                simpleWorldShader.setUniform(0, camera.viewproj * transform.toMat4());

                glDrawArrays(GL_LINES, 0, sphereVertexCount);
            }
        }
    }

    foreach(ref particle ; world.particles)
    {
        Transform transform = Transform(particle.radius, Mat3(1), particle.position);

        simpleWorldShader.setUniform(0, camera.viewproj * transform.toMat4());

        glDrawArrays(GL_LINES, 0, sphereVertexCount);
    }

    // Mouse Hover Over Collision Surface Render ////////////////////////////////////////////////////////////////////////////

    World.LineResult line = void;
    World.LineOptions options;

    options.structure = true;
    options.objects   = true;
    options.surface.frontFacing = true;

    int x, y;
    SDL_GetMouseState(&x, &y);
    Vec3 start, end;

    // TODO(REFACTOR) remove hardcoded window size
    AliasSeq!(start, end) = camera.calculateRayFromMouse(Vec2(x, y), Vec2(1920, 810));

    if(!igIsMouseHoveringAnyWindow() && world.collideLine(null, start, end - start, options, line))
    {
        uint verticesCount = 0;
        SimpleWorldVertex[16] vertices = void;

        switch(line.collisionType) with(World.CollisionType)
        {
        case structure:
        {
            Tag.Bsp* bsp = world.getCurrentSbsp().collisionBsp;

            forEachEdgeInBspSurface!(delegate(int e, int v0, int v1) @nogc pure
            {
                vertices[verticesCount++] = SimpleWorldVertex(bsp.vertices[v0].point, ~0);
                vertices[verticesCount++] = SimpleWorldVertex(bsp.vertices[v1].point, ~0);
                return true;
            })(bsp, line.surface.index);

            simpleWorldShader.useProgram();
            simpleWorldVertexArray.bind();

            simpleWorldShader.setUniform(0, camera.viewproj);

            simpleWorldVertexArray
                .bufferData(0, verticesCount * simpleWorldVertexArray.sizeof, vertices.ptr, GL_STREAM_DRAW);

            glDisable(GL_DEPTH_TEST);
            glDrawArrays(GL_LINES, 0, verticesCount);
            glEnable(GL_DEPTH_TEST);

            glBindVertexArray(0);
            break;
        }
        case object:
        {
            auto tagCollision = Cache.get!TagModelCollisionGeometry(
                Cache.get!TagObject(line.model.object.tagIndex).collisionModel);

            auto node = &tagCollision.nodes[line.model.nodeIndex];
            const transform = &line.model.object.transforms[line.model.nodeIndex];

            Tag.Bsp* bsp = &node.bsps[line.model.bspIndex];

            forEachEdgeInBspSurface!(delegate(int e, int v0, int v1) @nogc pure
            {
                vertices[verticesCount++] = SimpleWorldVertex(*transform * bsp.vertices[v0].point, ~0);
                vertices[verticesCount++] = SimpleWorldVertex(*transform * bsp.vertices[v1].point, ~0);
                return true;
            })(bsp, line.surface.index);

            simpleWorldShader.useProgram();
            simpleWorldVertexArray.bind();

            simpleWorldShader.setUniform(0, camera.viewproj);

            simpleWorldVertexArray
                .bufferData(0, verticesCount * simpleWorldVertexArray.sizeof, vertices.ptr, GL_STREAM_DRAW);

            glDisable(GL_DEPTH_TEST);
            glDrawArrays(GL_LINES, 0, verticesCount);
            glEnable(GL_DEPTH_TEST);

            glBindVertexArray(0);

            break;
        }
        default:
        }
    }


    // Rendering "framebuffer" to the Default FrameBuffer ///////////////////////////////////////////////////////////////

    framebuffer.unbind();

    struct Vertex
    {
        Vec2 position;
        Vec2 uv;
    }

    immutable Vertex[4] vertices =
    [
        { Vec2(-1, -1), Vec2(0, 0) },
        { Vec2(-1, 1), Vec2(0, 1) },
        { Vec2(1, -1), Vec2(1, 0) },
        { Vec2(1, 1), Vec2(1, 1) }
    ];

    simpleShader.useProgram();

    simpleVertexArray.bind();
    simpleVertexArray.bufferData(0, Vertex.sizeof * vertices.length, vertices.ptr, GL_DYNAMIC_DRAW);

    framebuffer.bindAttachmentToUnit(GL_COLOR_ATTACHMENT0, 0);
    glUniform1i(0, 0);

    glDisable(GL_DEPTH_TEST);
    {
        glDrawArrays(GL_TRIANGLE_STRIP, 0, vertices.length);

        framebuffer.bindAttachmentToUnit(GL_COLOR_ATTACHMENT1, 0);

        glEnable(GL_BLEND);
        glBlendFunc(GL_DST_ALPHA, GL_ONE);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, vertices.length);
        glDisable(GL_BLEND);
    }
    glEnable(GL_DEPTH_TEST);

    // Rendering ImGui UI ///////////////////////////////////////////////////////////////////////////////////////////////////

    renderImGui();

}

@nogc nothrow
void doUi()
{
    static immutable const(char*)[] attachments = ["Attachment 0", "Attachment 1", "Attachment 2", "Depth Attachment"];
    static immutable indices = [ GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_DEPTH_ATTACHMENT ];

    igBegin("Renderer");
    igCombo("attachments", &uiSelectedAttachment, attachments.ptr, attachments.length);

    igPushStyleVar(ImGuiStyleVar.Alpha, 1.0f);
    igImage(cast(void*)framebuffer.getTexture(indices[uiSelectedAttachment]), ImVec2(1920.0f / 2, 810.0f / 2), ImVec2(0,1), ImVec2(1,0));
    igPopStyleVar();
    igEnd();
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

GLFramebuffer framebuffer;

Array!(Array!uint) structureVertexIndexOffsets;

GLVertexArray sbspVertexArray;
GLVertexArray modelVertexArray;
GLVertexArray simpleVertexArray;
GLVertexArray simpleWorldVertexArray;
GLVertexArray imguiVertexArray;
GLVertexArray sphereVertexArray;
int sphereVertexCount;

ShaderEnvironment[3][3][3] envShaders;
ShaderModel[5][3][2][2]    modelShaders;
ShaderChicago              chicagoShader;
GLShader!void              simpleShader;
GLShader!void              imguiShader;
GLShader!void              simpleWorldShader;

int uiSelectedAttachment;

void loadEnvironmentShaders()
{
    string vertexSource   = readText("shaders/environment.vert");
    string fragmentSource = readText("shaders/environment.frag");

    ShaderPreprocessor preprocessor;
    vertexSource = preprocessor.setSourceToProcess(vertexSource).generateSource();
    preprocessor.setSourceToProcess(fragmentSource);

    for(int i = 0; i < 3; ++i)
    for(int j = 0; j < 3; ++j)
    for(int k = 0; k < 3; ++k)
    {
        preprocessor.clearDefines();

        preprocessor.addDefine("TYPE "         ~ to!string(i));
        preprocessor.addDefine("FUNCT_DETAIL " ~ to!string(j));
        preprocessor.addDefine("FUNCT_MICRO "  ~ to!string(k));

        envShaders[i][j][k] = ShaderEnvironment.make("environment", vertexSource, preprocessor.generateSource());
    }
}

void loadModelShaders()
{
    string vertexSource   = readText("shaders/model.vert");
    string fragmentSource = readText("shaders/model.frag");

    ShaderPreprocessor preprocessor;
    vertexSource = preprocessor.setSourceToProcess(vertexSource).generateSource();
    preprocessor.setSourceToProcess(fragmentSource);

    for(int i = 0; i < 2; ++i)
    for(int j = 0; j < 2; ++j)
    for(int k = 0; k < 3; ++k)
    for(int l = 0; l < 5; ++l)
    {
        preprocessor.clearDefines();

        preprocessor.addDefine("DETAIL_AFTER_REFLECTION " ~ (i ? "true" : "false"));
        preprocessor.addDefine("MASK_INVERT "             ~ (j ? "true" : "false"));
        preprocessor.addDefine("DETAIL_FUNCTION "         ~ to!string(k));
        preprocessor.addDefine("MASK "                    ~ to!string(l));

        modelShaders[i][j][k][l] = ShaderModel.make("model", vertexSource, preprocessor.generateSource());
    }
}

void loadChicagoShaders()
{
    string vertexSource   = readText("shaders/chicago.vert");
    string fragmentSource = readText("shaders/chicago.frag");

    ShaderPreprocessor preprocessor;
    vertexSource   = preprocessor.setSourceToProcess(vertexSource).generateSource();
    fragmentSource = preprocessor.setSourceToProcess(fragmentSource).generateSource();

    chicagoShader = ShaderChicago.make("chicago", vertexSource, fragmentSource);
}

void renderOpaqueStructureBsp(ref Camera camera, TagScenarioStructureBsp* sbsp, int lightmapIndex)
{
    auto lightmap = &sbsp.lightmaps[lightmapIndex];

    if(lightmap.bitmap == indexNone)
        return;

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
            auto prog = &envShaders[shader.type][shader.detailMapFunction][shader.microDetailMapFunction];

            prog.useProgram();

            Vec2[5] scales =
            [
                Vec2(1.0f),
                Vec2(shader.primaryDetailMapScale),
                Vec2(shader.secondaryDetailMapScale),
                Vec2(shader.microDetailMapScale),
                Vec2(shader.bumpMapScale)
            ];

            bindTexture2D(0, shader.baseMap.index,            0, DefaultTexture.multiplicative);
            bindTexture2D(1, shader.primaryDetailMap.index,   0, DefaultTexture.detail);
            bindTexture2D(2, shader.secondaryDetailMap.index, 0, DefaultTexture.detail);
            bindTexture2D(3, shader.microDetailMap.index,     0, DefaultTexture.detail);
            bindTexture2D(4, sbsp.lightmapsBitmap.index, lightmap.bitmap, DefaultTexture.multiplicative);
            bindTexture2D(5, shader.bumpMap.index,            0, DefaultTexture.vector);
            bindTexture2D(6, shader.reflectionCubeMap.index,  0, DefaultTexture.additive);

            prog.viewproj.set(camera.viewproj);
            prog.eyePos.set(camera.position);
            prog.uvscales.set(scales);

            prog.perpendicularColor.set(ColorArgb(1.0f, shader.perpendicularColor) * shader.perpendicularBrightness);
            prog.parallelColor.set(ColorArgb(1.0f, shader.parallelColor) * shader.parallelBrightness);

            if(shader.reflectionType == TagEnums.ShaderEnvironmentReflectionType.bumpedCubeMap
                && shader.reflectionCubeMap)
            {
                prog.specularColorControl.set(1.0f); // todo remove this variable, use shader macro instead
            }
            else
            {
                prog.specularColorControl.set(0.0f);
            }

            prog.basemap.set(0);
            prog.d0map.set(1);
            prog.d1map.set(2);
            prog.micromap.set(3);
            prog.lightmap.set(4);
            prog.bumpmap.set(5);
            prog.cubemap.set(6);

            glDrawElementsBaseVertex(GL_TRIANGLES, material.surfaceCount * 3,
                GL_UNSIGNED_SHORT, cast(void*)(material.surfaces * 6), vertexOffset);

            break;
        default:
            continue;
        }

    }
}

void renderObject(ref Camera camera, int[] permutations, GObject.Lighting* lighting, TagGbxmodel* tagModel, Mat4x3[] matrices)
{
    foreach(i, ref region ; tagModel.regions)
    {
        // todo pixel cutoff

        int geometryIndex = region.permutations[permutations[i]].superHigh;
        auto geometry = &tagModel.geometries[geometryIndex];

        foreach(ref part ; geometry.parts)
        {
            auto baseShader = Cache.get!TagShader(tagModel.shaders[part.shaderIndex].shader);

            switch(baseShader.shaderType)
            {
            case TagEnums.ShaderType.model:
                auto shader = cast(TagShaderModel*)baseShader;

                int maskIndex = (shader.detailMask + 1) / 2;
                int invert    = ((shader.detailMask + 1) % 2) == 0;

                auto prog = &modelShaders[shader.flags.detailAfterReflection][invert][shader.detailFunction][maskIndex];
                prog.useProgram();

                Vec2[2] scales =
                [
                    Vec2(shader.mapUScale * tagModel.baseMapUScale, shader.mapVScale * tagModel.baseMapVScale),
                    Vec2(shader.detailMapScale)
                ];

                ColorRgb colorPerpendicular = shader.perpendicularTintColor * shader.perpendicularBrightness;
                ColorRgb colorParallel      = shader.parallelTintColor      * shader.parallelBrightness;

                prog.viewproj.set(camera.viewproj);
                prog.eyePosition.set(camera.position);
                prog.uvscales.set(scales);
                prog.perpendicularColor.set(colorPerpendicular);
                prog.parallelColor.set(colorParallel);

                prog.ambientColor.set(lighting.ambientColor);

                prog.distantLight0_color.set(lighting.distantLight[0].color);
                prog.distantLight0_direction.set(lighting.distantLight[0].direction);

                prog.distantLight1_color.set(lighting.distantLight[1].color);
                prog.distantLight1_direction.set(lighting.distantLight[1].direction);

                if(part.flags.zoner)
                {
                    Mat4x3[TagConstants.Model.maxPartLocalNodes] localNodes = void;

                    for(int j = 0; j < part.localNodeCount; ++j)
                    {
                        localNodes[j] = matrices[part.localNodes[j].nodeIndex];
                    }

                    prog.nodes.set(localNodes.ptr, part.localNodeCount);
                }
                else
                {
                    prog.nodes.set(matrices.ptr, tagModel.nodes.size);
                }

                prog.diffusemap.set(0);
                prog.multimap.set(1);
                prog.detailmap.set(2);
                prog.cubemap.set(3);

                bindTexture2D  (0, shader.baseMap.index,           0, DefaultTexture.multiplicative);
                bindTexture2D  (1, shader.multipurposeMap.index,   0, DefaultTexture.additive);
                bindTexture2D  (2, shader.detailMap.index,         0, DefaultTexture.detail);
                bindTextureCube(3, shader.reflectionCubeMap.index, 0, DefaultTexture.vector);

                glDrawElementsBaseVertex(GL_TRIANGLE_STRIP, part.indexCount + 2, GL_UNSIGNED_SHORT,
                    cast(void*)part.indexOffset, part.vertexOffset / cast(int)TagModelVertex.sizeof);

                break;
            case TagEnums.ShaderType.chicago:
            case TagEnums.ShaderType.chicagoExtended:

                auto shader = cast(TagShaderTransparentChicagoExtended*)baseShader;

                if(shader.firstMapType != 0)
                {
                    // todo implement other types
                    // only support 2d texture for now
                    continue;
                }

                chicagoShader.useProgram();

                switch(shader.framebufferBlendFunction)
                {
                case TagEnums.FramebufferBlendFunction.alphaBlend:
                    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                    break;
                case TagEnums.FramebufferBlendFunction.add:
                    glBlendFunc(GL_ONE, GL_ONE);
                    break;
                default: glBlendFunc(GL_ONE, GL_ZERO);
                }

                if(part.flags.zoner)
                {
                    Mat4x3[TagConstants.Model.maxPartLocalNodes] localNodes = void;

                    for(int j = 0; j < part.localNodeCount; ++j)
                    {
                        localNodes[j] = matrices[part.localNodes[j].nodeIndex];
                    }

                    chicagoShader.nodes.set(localNodes.ptr, part.localNodeCount);
                }
                else
                {
                    chicagoShader.nodes.set(matrices.ptr, tagModel.nodes.size);
                }

                Vec4[4] uvs = Vec4(0.0f);
                Vec4i colorFunc;
                Vec4i alphaFunc;

                foreach(int s, ref stage ; shader.fourStageMaps)
                {
                    colorFunc[s] = stage.colorFunction;
                    alphaFunc[s] = stage.alphaFunction;

                    if(s == shader.fourStageMaps.size - 1)
                    {
                        colorFunc[s] = 0;
                        alphaFunc[s] = 0;
                    }

                    uvs[s].zw = Vec2(stage.mapUScale, stage.mapVScale);

                    bindTexture2D(s, stage.map.index, 0, DefaultTexture.additive);
                }

                chicagoShader.viewproj.set(camera.viewproj);
                chicagoShader.uvs.set(uvs);

                chicagoShader.colorBlendFunc.set(colorFunc);
                chicagoShader.alphaBlendFunc.set(alphaFunc);

                chicagoShader.tex0.set(0);
                chicagoShader.tex1.set(1);
                chicagoShader.tex2.set(2);
                chicagoShader.tex3.set(3);

                glEnable(GL_BLEND);
                glDisable(GL_DEPTH_TEST);

                glDrawElementsBaseVertex(GL_TRIANGLE_STRIP, part.indexCount + 2, GL_UNSIGNED_SHORT,
                    cast(void*)part.indexOffset, part.vertexOffset / cast(int)TagModelVertex.sizeof);

                glDisable(GL_BLEND);
                glEnable(GL_DEPTH_TEST);

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

        ColorRgb diffuseColor  = baseBitmap.pixelColorAt(baseMapPixels, uv);
        ColorRgb lightmapColor = lightmapBitmap.pixelColorAt(lightmapPixels, lmUv);

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

    if(bitmap.glTexture != indexNone)
    {
        glBindTextureUnit(textureIndex, bitmap.glTexture);
    }
}

static
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

        uint texture;

        glCreateTextures(GL_TEXTURE_2D, 1, &texture);
        bitmap.glTexture = texture;

        uint width  = bitmap.width;
        uint height = bitmap.height;

        glTextureStorage2D(texture, bitmap.mipmapCount + 1, pixelFormatGLFormat(bitmap.format), width, height);

        glTextureParameteri(texture, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTextureParameteri(texture, GL_TEXTURE_WRAP_T, GL_REPEAT);

        if(bitmap.mipmapCount == 0)
        {
            glTextureParameteri(texture, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        }
        else
        {
            glTextureParameteri(texture, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MAX_LEVEL, bitmap.mipmapCount);
        }

        uint offset = 0;

        for(int i = 0; i < bitmap.mipmapCount + 1; ++i)
        {
            if(width  == 0) width  = 1;
            if(height == 0) height = 1;

            uint size = pixelFormatSize(bitmap.format, width, height);

            pixelFormatCopyGpu2D(bitmap.format, texture, i, width, height, &buffer[offset]);

            offset += size;

            width  >>= 1;
            height >>= 1;
        }

        break;
    case TagEnums.BitmapType.cubeMap:

        uint texture;
        glCreateTextures(GL_TEXTURE_CUBE_MAP, 1, &texture);

        bitmap.glTexture = texture;

        uint width  = bitmap.width;
        uint height = bitmap.height;

        glTextureStorage2D(texture, bitmap.mipmapCount + 1, pixelFormatGLFormat(bitmap.format), width, height);

        glTextureParameteri(texture, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTextureParameteri(texture, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTextureParameteri(texture, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

        if(bitmap.mipmapCount == 0)
        {
            glTextureParameteri(texture, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        }
        else
        {
            glTextureParameteri(texture, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTextureParameteri(texture, GL_TEXTURE_MAX_LEVEL, bitmap.mipmapCount);
        }

        uint offset = 0;

        for(int i = 0; i < bitmap.mipmapCount + 1; ++i)
        {
            static immutable sides = [ 0, 2, 1, 3, 4, 5 ];

            if(width  == 0) width  = 1;
            if(height == 0) height = 1;

            uint size = pixelFormatSize(bitmap.format, width, height);

            foreach(index, mapTo ; sides)
            {
                pixelFormatCopyGpu3D(bitmap.format, texture, i, width, height, mapTo, &buffer[offset + size * index]);
            }

            offset += size * 6;

            height >>= 1;
            width  >>= 1;
        }

        break;
    }
}

void renderImGui()
{
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glEnable(GL_SCISSOR_TEST);

    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    imguiShader.useProgram();
    imguiVertexArray.bind();

    ImDrawData* drawData = igGetDrawData();

    if(drawData is null)
        return;

    auto io = igGetIO();
    const float width = io.DisplaySize.x;
    const float height = io.DisplaySize.y;

    Mat4 ortho = orthogonalMatrix(0.0f, width, height, 0.0f);

    imguiShader.setUniform(0, ortho);

    foreach(i ; 0 .. drawData.CmdListsCount)
    {
        ImDrawList* cmdList = drawData.CmdLists[i];
        uint idxBufferOffset;

        auto countVertices = cmdList.VtxBuffer.Size;
        auto countIndices  = cmdList.IdxBuffer.Size;

        // TODO(PERFORMANCE, ?) shouldn't create gpu buffer like this every draw ?

        imguiVertexArray
            .createBuffer(0, countVertices * ImDrawVert.sizeof, &cmdList.VtxBuffer[0], GL_STREAM_DRAW)
            .vertexBuffer(0, 0, 0, ImDrawVert.sizeof);

        imguiVertexArray
            .createBuffer(1, countIndices * ImDrawIdx.sizeof, &cmdList.IdxBuffer[0], GL_STREAM_DRAW)
            .elementBuffer(1);

        foreach(j ; 0 .. cmdList.CmdBuffer.Size)
        {
            const cmd = &cmdList.CmdBuffer[j];

            if(cmd.UserCallback)
            {
                cmd.UserCallback(cmdList, cmd);
            }
            else
            {
                glBindTextureUnit(0, cast(uint)cmd.TextureId);
                glScissor(
                    cast(int)cmd.ClipRect.x,
                    cast(int)(io.DisplaySize.y - cmd.ClipRect.w),
                    cast(int)(cmd.ClipRect.z - cmd.ClipRect.x),
                    cast(int)(cmd.ClipRect.w - cmd.ClipRect.y));
                glDrawElements(GL_TRIANGLES, cmd.ElemCount, GL_UNSIGNED_SHORT, cast(void*)idxBufferOffset);
            }

            idxBufferOffset += cmd.ElemCount * 2;
        }

    }

    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

