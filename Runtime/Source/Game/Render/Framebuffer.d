
module Game.Render.Framebuffer;

import OpenGL;

struct GLFramebuffer
{
@disable this(this);

static GLFramebuffer make(int width, int height)
{
    GLFramebuffer result;

    result.width  = width;
    result.height = height;

    glCreateFramebuffers(1, &result.object);

    return result;
}

~this()
{
    if(object) glDeleteFramebuffers(1, &object);
    if(depth)  glDeleteTextures(1, &depth);

    foreach(attachment ; attachments)
    {
        if(attachment)
        {
            glDeleteTextures(1, &attachment);
        }
    }
}

void attach(uint attachment, uint format, uint filter)
{
    uint* buffer;

    if(attachment == GL_DEPTH_ATTACHMENT)
    {
        buffer = &depth;
    }
    else if(attachment >= GL_COLOR_ATTACHMENT0 && attachment < GL_COLOR_ATTACHMENT10)
    {
        buffer = &attachments[attachment - GL_COLOR_ATTACHMENT0];
    }
    else
    {
        assert(0);
    }

    if(*buffer)
    {
        assert(0);
    }

    glCreateTextures(GL_TEXTURE_2D, 1, buffer);

    glTextureStorage2D(*buffer, 1, format, width, height);

    glTextureParameteri(*buffer, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTextureParameteri(*buffer, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTextureParameteri(*buffer, GL_TEXTURE_MIN_FILTER, filter);
    glTextureParameteri(*buffer, GL_TEXTURE_MAG_FILTER, filter);

    glNamedFramebufferTexture(object, attachment, *buffer, 0);

}

bool finalize()
{
    uint status = glCheckNamedFramebufferStatus(object, GL_FRAMEBUFFER);
    return status == GL_FRAMEBUFFER_COMPLETE;
}

void bind()
{
    uint[attachments.length] buffers;
    uint count;

    foreach(int i, attachment ; attachments)
    {
        if(attachment != 0)
        {
            buffers[count] = GL_COLOR_ATTACHMENT0 + i;
            count += 1;
        }
    }

    glNamedFramebufferDrawBuffers(object, count, buffers.ptr);
    glBindFramebuffer(GL_FRAMEBUFFER, object);
}

void unbind()
{
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void blitWithDefaultFramebuffer()
{
    int halfWidth  = width / 2;
    int halfHeight = height / 2;

    glNamedFramebufferReadBuffer(object, GL_COLOR_ATTACHMENT0);
    glBlitNamedFramebuffer(object, 0, 0, 0, width, height,
        0, 0, halfWidth, halfHeight, GL_COLOR_BUFFER_BIT, GL_NEAREST);

    glNamedFramebufferReadBuffer(object, GL_COLOR_ATTACHMENT1);
    glBlitNamedFramebuffer(object, 0, 0, 0, width, height,
        halfWidth, 0, width, halfHeight, GL_COLOR_BUFFER_BIT, GL_NEAREST);

    glNamedFramebufferReadBuffer(object, GL_COLOR_ATTACHMENT2);
    glBlitNamedFramebuffer(object, 0, 0, 0, width, height,
        0, halfHeight, halfWidth, height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
}

void bindAttachmentToUnit(uint attachment, uint unit)
{
    uint* buffer;

    if(attachment == GL_DEPTH_ATTACHMENT)
    {
        buffer = &depth;
    }
    else if(attachment >= GL_COLOR_ATTACHMENT0 && attachment < GL_COLOR_ATTACHMENT10)
    {
        buffer = &attachments[attachment - GL_COLOR_ATTACHMENT0];
    }
    else
    {
        assert(0);
    }

    glBindTextureUnit(unit, *buffer);
}

uint getTexture(uint attachment)
{
    if(attachment == GL_DEPTH_ATTACHMENT)
    {
        return depth;
    }
    else if(attachment >= GL_COLOR_ATTACHMENT0 && attachment < GL_COLOR_ATTACHMENT10)
    {
        return attachments[attachment - GL_COLOR_ATTACHMENT0];
    }
    else
    {
        assert(0);
    }
}

private:

uint object;
uint depth;
uint[10] attachments;
int width;
int height;

}