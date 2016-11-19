
module Game.Core.Math.Matrix_Test;

import Game.Core.Math.Matrix;


unittest
{
    assert(Mat2(Mat3(1, 2, 3, 4, 5, 6, 7, 8, 9)) == Mat2(1, 2, 4, 5));

    assert(Mat2(1, 2, 3, 5) * Mat2(7, 11, 13, 17) == Mat2(40, 69, 64, 111));
    assert(Mat2(1, 2, 3, 5) * Vec2(7, 11)         == Vec2(40, 69));

    assert(Mat3x2(1, 2, 3, 5, 7, 11) * Vec2(13, 17) == Vec2(71, 122));

    assert(Mat2(2, 4, 6, 8) / 2 == Mat2(1, 2, 3, 4));
    assert(2 * Mat2(1, 2, 3, 4) == Mat2(1, 2, 3, 4) * 2);

    assert(transpose(Mat2(1, 2, 3, 5)) == Mat2(1, 3, 2, 5));
}