
module Game.Tags.Funcs.CameraTrack;

mixin template TagCameraTrack()
{
    private @nogc nothrow
    static float interpolateComponent(float a, float b, float c, float d, float increment, float first, float percent)
    {
        float dc = d - c;
        float cb = c - b;
        float ba = b - a;

        float e = dc - cb;
        float f = cb - ba;

        float g = void;

        g = (e - f)  * (percent - (first + (2 * increment))) / (3 * increment);
        g = (g + f)  * (percent - (first + increment)) / (2 * increment);
        g = (g + ba) * (percent - first) / increment;

        return g + a;
    }

    @nogc nothrow
    Vec3 calculateOffset(float pitch) const
    {
        import Game.Core.Math : PI, PI_2;

        float percent = (pitch + PI_2) / PI;
        int controlIndex = cast(int)(percent * (controlPoints.size - 1));

        for(int i = controlIndex; i > 0; --i)
        {
            if(i + 4 <= controlPoints.size)
            {
                if(i < controlIndex)
                {
                    controlIndex = i;
                    break;
                }
            }
        }

        float increment = 1.0f / (controlPoints.size - 1);
        float first = controlIndex * increment;

        immutable Vec3 p0 = controlPoints[controlIndex + 0].position;
        immutable Vec3 p1 = controlPoints[controlIndex + 1].position;
        immutable Vec3 p2 = controlPoints[controlIndex + 2].position;
        immutable Vec3 p3 = controlPoints[controlIndex + 3].position;

        return Vec3(
            interpolateComponent(p0.x, p1.x, p2.x, p3.x, increment, first, percent),
            interpolateComponent(p0.y, p1.y, p2.y, p3.y, increment, first, percent),
            interpolateComponent(p0.z, p1.z, p2.z, p3.z, increment, first, percent));

    }
}