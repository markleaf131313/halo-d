
module Game.Render.Renderer;

import std.container.array;
import std.conv : to;
import std.file : readText;
import std.meta : AliasSeq;

import SDL2;
import ImGui;

import Game.Render.Camera;

import Game.Cache;
import Game.Core;
import Game.Debug;
import Game.Tags;
import Game.World;



struct Renderer
{

@disable this(this);

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

