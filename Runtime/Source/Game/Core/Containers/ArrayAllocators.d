
module Game.Core.Containers.ArrayAllocators;

import std.conv : to;

struct FixedArrayAllocator(int _inlinedSize)
{
    enum hasInlinedElements = true;
    enum inlinedSize = _inlinedSize;

    struct Def(Element)
    {
        static assert(Def.sizeof % Element.alignof == 0);
        static assert(Def.sizeof == (Element[inlinedSize]).sizeof);

        Element* allocation() const
        {
            return cast(Element*)data.ptr;
        }

        void resizeAllocation(int lastSize, int size)
        {
            assert(size <= inlinedSize);
        }

    private:
        align(Element.alignof) alias ElementAsBytes = byte[Element.sizeof];
        ElementAsBytes[inlinedSize] data;
    }

}
