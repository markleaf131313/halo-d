
module Game.Tags.Funcs.Animation;

mixin template AnimationBlock()
{
    import Game.Core.Math;
    import Game.Tags : TagEnums;

    @nogc nothrow
    private static float normalizeShort(short v)
    {
        return v / float(short.max);
    }

    @nogc nothrow
    private static Quat extractQuat(void* buf)
    {
        short* b = cast(short*)buf;
        return Quat(-normalizeShort(b[0]), -normalizeShort(b[1]), -normalizeShort(b[2]), normalizeShort(b[3]));
    }

    @nogc nothrow
    bool decodeBase(int frame, Orientation* output) const
    {
        if(type != TagEnums.AnimationType.base)
        {
            return false;
        }

        // todo compressed animations

        if(nodeCount <= 0)
        {
            return true;
        }

        ulong rotationBits  = *cast(ulong*)nodeRotationFlagData.ptr;
        ulong translateBits = *cast(ulong*)nodeTransFlagData.ptr;
        ulong scaleBits     = *cast(ulong*)nodeScaleFlagData.ptr;

        ubyte* buffer        = frameData.dataAs!ubyte + frame * frameSize;
        ubyte* defaultBuffer = defaultData.dataAs!ubyte;

        for(int i = 0; i < nodeCount; ++i)
        {
            if(rotationBits & 1)
            {
                output[i].rotation = extractQuat(buffer);
                buffer += 8;
            }
            else
            {
                output[i].rotation = extractQuat(defaultBuffer);
                defaultBuffer += 8;
            }

            if(translateBits & 1)
            {
                output[i].position = *cast(Vec3*)buffer;
                buffer += Vec3.sizeof;
            }
            else
            {
                output[i].position = *cast(Vec3*)defaultBuffer;
                defaultBuffer += Vec3.sizeof;
            }

            if(scaleBits & 1)
            {
                output[i].scale = *cast(float*)buffer;
                buffer += float.sizeof;
            }
            else
            {
                output[i].scale = *cast(float*)defaultBuffer;
                defaultBuffer += float.sizeof;
            }

            rotationBits  >>= 1;
            translateBits >>= 1;
            scaleBits     >>= 1;
        }

        return true;
    }

    @nogc nothrow
    void decodeReplace(int frame, Orientation* output) const
    {
        ulong rotationBits  = *cast(ulong*)nodeRotationFlagData.ptr;
        ulong translateBits = *cast(ulong*)nodeTransFlagData.ptr;
        ulong scaleBits     = *cast(ulong*)nodeScaleFlagData.ptr;
        ubyte* buffer       = frameData.dataAs!ubyte + frame * frameSize;

        for(int i = 0; i < nodeCount; ++i)
        {
            if(rotationBits & 1)
            {
                output[i].rotation = extractQuat(buffer);
                buffer += 8;
            }

            if(translateBits & 1)
            {
                output[i].position = *cast(Vec3*)buffer;
                buffer += 12;
            }

            if(scaleBits & 1)
            {
                output[i].scale = *cast(float*)buffer;
                buffer += 4;
            }

            rotationBits  >>= 1;
            translateBits >>= 1;
            scaleBits     >>= 1;
        }
    }

    @nogc nothrow
    void decodeOverlay(int frame, Orientation* output) const
    {
        ulong rotationBits  = *cast(ulong*)nodeRotationFlagData.ptr;
        ulong translateBits = *cast(ulong*)nodeTransFlagData.ptr;
        ulong scaleBits     = *cast(ulong*)nodeScaleFlagData.ptr;
        ubyte* buffer       = frameData.dataAs!ubyte + frame * frameSize;

        for(int i = 0; i < nodeCount; ++i)
        {
            if(rotationBits & 1)
            {
                output[i].rotation *= extractQuat(buffer);
                buffer += 8;
            }

            if(translateBits & 1)
            {
                output[i].position += *cast(Vec3*)buffer;
                buffer += 12;
            }

            if(scaleBits & 1)
            {
                output[i].scale *= *cast(float*)buffer;
                buffer += 4;
            }

            rotationBits  >>= 1;
            translateBits >>= 1;
            scaleBits     >>= 1;
        }
    }

    @nogc nothrow
    void decodeOverlayMix(int frame0, int frame1, float alpha, Orientation* output) const
    {
        if(type != TagEnums.AnimationType.overlay)
        {
            return;
        }

        ulong rotationBits  = *cast(ulong*)nodeRotationFlagData.ptr;
        ulong translateBits = *cast(ulong*)nodeTransFlagData.ptr;
        ulong scaleBits     = *cast(ulong*)nodeScaleFlagData.ptr;

        ubyte* buffer1      = frameData.dataAs!ubyte + frame0 * frameSize;
        ubyte* buffer2      = frameData.dataAs!ubyte + frame1 * frameSize;

        for(int i = 0; i < nodeCount; ++i)
        {
            if(rotationBits & 1)
            {
                output[i].rotation *= slerp(extractQuat(buffer1), extractQuat(buffer2), alpha);

                buffer1 += 8;
                buffer2 += 8;
            }

            if(translateBits & 1)
            {
                output[i].position += mix(*cast(Vec3*)buffer1, *cast(Vec3*)buffer2, alpha);

                buffer1 += 12;
                buffer2 += 12;
            }

            if(scaleBits & 1)
            {
                // todo do scaling ?

                buffer1 += 4;
                buffer2 += 4;
            }

            rotationBits  >>= 1;
            translateBits >>= 1;
            scaleBits     >>= 1;
        }
    }

    static struct ScreenBounds
    {
    @nogc nothrow:

        this(T)(ref T b)
        {
            leftAngle       = b.leftYawPerFrame;
            leftFrameCount  = b.leftFrameCount;
            rightAngle      = b.rightYawPerFrame;
            rightFrameCount = b.rightFrameCount;

            upAngle        = b.upPitchPerFrame;
            upFrameCount   = b.upPitchFrameCount;
            downAngle      = b.downPitchPerFrame;
            downFrameCount = b.downPitchFrameCount;
        }

        float leftAngle;
        int   leftFrameCount;

        float rightAngle;
        int   rightFrameCount;

        float upAngle;
        int   upFrameCount;

        float downAngle;
        int   downFrameCount;
    }

    @nogc nothrow
    void decodeOverlayAim(T)(ref T b, float yaw, float pitch, Orientation* output) const
    {
        // aim animation is stored as a 2d array

        // this basically takes 4 frames blending the left/right for both upper and lower bound (using yaw)
        // then the up/down is blended from the two results to get the resulting aim animation overlay

        ScreenBounds bounds = b;

        if(type != TagEnums.AnimationType.overlay)
        {
            return;
        }

        int cols = 1 + bounds.leftFrameCount + bounds.rightFrameCount;
        int rows = 1 + bounds.upFrameCount   + bounds.downFrameCount;

        if(rows * cols > frameCount)
        {
            return;
        }

        enum calculatePercentFrame =
        function(float angle, float delta, ref int frame, ref float percent)
        {
            if(delta == 0.0f)
            {
                frame   = 0;
                percent = 0.0f;
            }
            else
            {
                float value = angle / delta;

                frame   = cast(int)value;
                percent = fmod(value, 1.0f);

                if(percent < 0.0f)
                {
                    frame -= 1;
                    percent += 1.0f;
                }
            }
        };

        enum clampFrame =
        function(int lower, int upper, ref int frame, ref float percent)
        {
            if(frame >= upper)
            {
                frame   = upper - 1;
                percent = 1.0f;
            }

            if(frame < lower)
            {
                frame   = lower;
                percent = 0.0f;
            }
        };

        int yawFrame;
        int pitchFrame;

        float yawPercent;
        float pitchPercent;

        float yawAngleDelta   = yaw   < 0.0f ? bounds.rightAngle : bounds.leftAngle;
        float pitchAngleDelta = pitch < 0.0f ? bounds.downAngle  : bounds.upAngle;

        calculatePercentFrame(yaw,   yawAngleDelta,   yawFrame,   yawPercent);
        calculatePercentFrame(pitch, pitchAngleDelta, pitchFrame, pitchPercent);

        clampFrame(-bounds.rightFrameCount, bounds.leftFrameCount, yawFrame,   yawPercent);
        clampFrame(-bounds.downFrameCount,  bounds.upFrameCount,   pitchFrame, pitchPercent);

        yawFrame   += bounds.rightFrameCount;
        pitchFrame += bounds.downFrameCount;

        ulong rotationBits  = *cast(ulong*)nodeRotationFlagData.ptr;
        ulong translateBits = *cast(ulong*)nodeTransFlagData.ptr;
        ulong scaleBits     = *cast(ulong*)nodeScaleFlagData.ptr;

        int frame0 = pitchFrame       * cols + yawFrame;
        int frame1 = pitchFrame       * cols + yawFrame + 1;
        int frame2 = (pitchFrame + 1) * cols + yawFrame;
        int frame3 = (pitchFrame + 1) * cols + yawFrame + 1;

        ubyte* bufferBotRight = frameData.dataAs!ubyte + frame0 * frameSize;
        ubyte* bufferBotLeft  = frameData.dataAs!ubyte + frame1 * frameSize;
        ubyte* bufferTopRight = frameData.dataAs!ubyte + frame2 * frameSize;
        ubyte* bufferTopLeft  = frameData.dataAs!ubyte + frame3 * frameSize;

        for(int i = 0; i < nodeCount; ++i)
        {
            if(rotationBits & 1)
            {
                // todo slerp these, no guarantee they all have the right directio nof quat ?

                Quat bl = extractQuat(bufferBotLeft);
                Quat br = extractQuat(bufferBotRight);

                Quat tl = extractQuat(bufferTopLeft);
                Quat tr = extractQuat(bufferTopRight);

                Quat blr = mix(br, bl, yawPercent);
                Quat tlr = mix(tr, tl, yawPercent);

                Quat mixed = mix(blr, tlr, pitchPercent);
                normalize(mixed);

                output[i].rotation *= mixed;

                bufferBotLeft  += 8;
                bufferBotRight += 8;
                bufferTopLeft  += 8;
                bufferTopRight += 8;
            }

            if(translateBits & 1)
            {
                // todo translate implement ?

                bufferBotLeft  += 12;
                bufferBotRight += 12;
                bufferTopLeft  += 12;
                bufferTopRight += 12;
            }

            if(scaleBits & 1)
            {
                // todo scale implement ?

                bufferBotLeft  += 4;
                bufferBotRight += 4;
                bufferTopLeft  += 4;
                bufferTopRight += 4;
            }

            rotationBits  >>= 1;
            translateBits >>= 1;
            scaleBits     >>= 1;
        }
    }


}