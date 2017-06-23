
module Game.Render.Shader;

import std.stdio;
import std.conv : to;

import OpenGL;

import Game.Core;

struct ShaderUniform(T)
{
private uint location;

static if(is(T : V[size], V, int size))
{
    alias Type = V;

    void set(int size)(in ref V[size] values)
    {
        static assert(values.length <= size);
        setValues(values.ptr, values.length);
    }

    void set(in V* values, int length)
    {
        setValues(values, length);
    }
}
else
{
    alias Type = T;

    void set(T value)
    {
        setValues(&value, 1);
    }
}

private void setValues(in Type* values, int length)
{
            static if(is(Type == float))  glUniform1fv(location, length, values);
    else static if(is(Type == int))    glUniform1iv(location, length, values);
    else static if(is(Type == Mat4))   glUniformMatrix4fv(location, length, false, cast(float*)values);
    else static if(is(Type == Mat4x3)) glUniformMatrix4x3fv(location, length, false, cast(float*)values);
    else static if(isVector!Type)
    {
                static if(is(Type.Type == int))   enum typeIdentifier = "i";
        else static if(is(Type.Type == float)) enum typeIdentifier = "f";
        else static assert(false, "Unknown Vector component Type: " ~ T.Type.stringof);

        mixin("glUniform" ~ to!string(Type.size) ~ typeIdentifier ~ "v(location, length, &values[0].x);");

    }
    else static if(is(Type == ColorArgb))
    {
        foreach(int i, ref color ; values[0 .. length])
        {
            glUniform4f(location + i, color.r, color.g, color.b, color.a);
        }
    }
    else static if(is(Type == ColorRgb))
    {
        glUniform3fv(location, length, &values[0].r);
    }
    else
    {
        static assert(false, "Not a valid type (" ~ T.stringof ~ ") for ShaderUniform");
    }
}


}


struct GLShader(Uniforms)
{
@disable this(this);

static if(!is(Uniforms == void))
{
    alias uniforms this;
    Uniforms uniforms;
}

private uint program;

static GLShader make(string debugName, string vertexSource, string fragmentSource)
{
    static uint makeShader(string debugName, GLenum type, string source)
    {
        uint shader = glCreateShader(type);

        const(char*) p = cast(const(char*))source.ptr;
        int sourceLength = cast(int)source.length;

        glShaderSource(shader, 1, &p, &sourceLength);
        glCompileShader(shader);

        char[4128] log = void;
        int length = log.length;
        int compiled;

        glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
        glGetShaderInfoLog(shader, length, &length, log.ptr);

        if(!compiled)
        {
            string typeName = " Unknown";
            switch(type)
            {
            case GL_VERTEX_SHADER:   typeName = " Vertex Shader"; break;
            case GL_FRAGMENT_SHADER: typeName = " Fragment Shader"; break;
            default:
            }

            glDeleteShader(shader);
            throw new Exception(debugName ~ typeName ~ "\n" ~ to!string(log[0 .. length]));
        }

        if(length)
        {
            writeln(log[0 .. length]);
        }

        return shader;
    }

    uint vertex   = makeShader(debugName, GL_VERTEX_SHADER, vertexSource);     scope(exit) glDeleteShader(vertex);
    uint fragment = makeShader(debugName, GL_FRAGMENT_SHADER, fragmentSource); scope(exit) glDeleteShader(fragment);

    GLShader result = glCreateProgram();

    glAttachShader(result.program, vertex);
    glAttachShader(result.program, fragment);

    glLinkProgram(result.program);

    char[4128] log = void;
    int length = log.length;
    int linked = 0;

    glGetProgramiv(result.program, GL_LINK_STATUS, &linked);
    glGetProgramInfoLog(result.program, length, &length, log.ptr);

    if(!linked)
    {
        throw new Exception(debugName ~ "\n" ~ to!string(log[0 .. length]));
    }

    if(length)
    {
        writeln(log[0 .. length]);
    }

    static if(!is(Uniforms == void))
    {
        foreach(i, ref uniform ; result.uniforms.tupleof)
        {
            static if(is(typeof(uniform) : ShaderUniform!U, U))
            {
                uniform.location
                    = glGetUniformLocation(result.program, __traits(identifier, result.uniforms.tupleof[i]));
            }
        }
    }

    return result;
}

private this(uint p)
{
    program = p;
}

~this()
{
    if(program)
    {
        glDeleteProgram(program);
    }
}

void useProgram() const
{
    glUseProgram(program);
}

void setUniform(U)(uint location, U uniform)
{
    ShaderUniform!U loc;
    loc.location = location;
    loc.set(uniform);
}

}
