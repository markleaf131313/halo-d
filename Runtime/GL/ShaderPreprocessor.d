
module Game.Render.ShaderPreprocessor;

struct ShaderPreprocessor
{

ref ShaderPreprocessor setSourceToProcess(string source)
{
    import std.regex;

    static string includeReplace(Captures!string captures)
    {
        import std.file : readText;
        return readText("shaders/" ~ captures[1]);
    }

    auto versionMatch = matchFirst(source, regex(`^.*#version [0-9]+[^\n]*`, "s"));

    if(!versionMatch)
    {
        throw new Exception("Missing #version in shader source.");
    }

    preVersionSource = versionMatch.hit;
    processedSource = replaceAll!includeReplace(source[preVersionSource.length .. $], regex(`#include\("([^"]+)"\)`));

    return this;
}

string generateSource()
{
    string result;

    result = preVersionSource ~ "\n";

    foreach(define ; defines)
    {
        result ~= "#define " ~ define ~ "\n";
    }

    result ~= processedSource;

    return result;
}

void addDefine(string define)
{
    defines ~= define;
}

void clearDefines()
{
    defines.length = 0;
}

private:

string preVersionSource;
string processedSource;
string[] defines;

}