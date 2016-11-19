
module Game.Render.VertexArray;

import OpenGL;

struct GLVertexArray
{
@disable this(this);

static GLVertexArray make()
{
    GLVertexArray result;
    glCreateVertexArrays(1, &result.object);
    return result;
}

private uint    object;
private uint[4] buffers;

~this()
{
    if(object)
    {
        glDeleteVertexArrays(1, &object);
    }

    foreach(buffer ; buffers)
    {
        if(buffer)
        {
            glDeleteBuffers(1, &buffer);
        }
    }
}

void bind()
{
    glBindVertexArray(object);
}

ref auto attribFormat(uint attrib, uint binding, uint size, uint type, uint offset, bool normalized = false)
{
    glEnableVertexArrayAttrib(object, attrib);
    glVertexArrayAttribBinding(object, attrib, binding);
    glVertexArrayAttribFormat(object, attrib, size, type, normalized, offset);
    return this;
}

ref auto attribIFormat(uint attrib, uint binding, uint size, uint type, uint offset)
{
    glEnableVertexArrayAttrib(object, attrib);
    glVertexArrayAttribBinding(object, attrib, binding);
    glVertexArrayAttribIFormat(object, attrib, size, type, offset);
    return this;
}


ref auto createBuffer(int index, uint size, const(void)* data, uint usage)
{
    if(buffers[index])
    {
        glDeleteBuffers(1, &buffers[index]);
    }

    glCreateBuffers(1, &buffers[index]);
    glNamedBufferData(buffers[index], size, data, usage);
    return this;
}

ref auto createBuffer(int index)
{
    if(buffers[index])
    {
        glDeleteBuffers(1, &buffers[index]);
    }

    glCreateBuffers(1, &buffers[index]);
    return this;
}

ref auto bufferData(int index, uint size, const(void)* data, uint usage)
{
    assert(buffers[index] != 0);
    glNamedBufferData(buffers[index], size, data, usage);
    return this;
}

ref auto vertexBuffer(int bufferIndex, int bindedIndex, uint offset, uint stride)
{
    glVertexArrayVertexBuffer(object, bindedIndex, buffers[bufferIndex], offset, stride);
    return this;
}

ref auto elementBuffer(int index)
{
    glVertexArrayElementBuffer(object, buffers[index]);
    return this;
}

}