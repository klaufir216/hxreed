package test;

import haxe.io.Bytes;
import hxreed.Matrix;
import utest.Assert;


class MatrixTest extends utest.Test {
    function testIdentity() {
        Assert.equals("[[1, 0, 0], [0, 1, 0], [0, 0, 1]]",
            Matrix.identity(3).toString());
    }

    function testBigString() {
        Assert.equals(
            "01 00 \n00 01 \n", Matrix.identity(2).toBigString()
        );
    }

    function testMultiply() {
        var m1 = Matrix.fromArray([[1,2], [3,4]]);
        var m2 = Matrix.fromArray([[5,6], [7,8]]);
        var actual = m1.times(m2);
        var expected = Matrix.fromArray([[11,22], [19,42]]);
        Assert.isTrue(actual.equals(expected));
    }

    function testInverse() {
        var m = Matrix.fromArray(
            [[56, 23, 98], [3, 100, 200], [45, 201, 123]]);

        var mInvExpected = Matrix.fromArray(
            [[175, 133, 33], [130, 13, 245], [112, 35, 126]]);
        Assert.isTrue(m.invert().equals(mInvExpected));

        Assert.isTrue(
            Matrix.identity(3).equals(
                m.times(m.invert())
            )
        );
    }

    function testInverse2() {
        var m = Matrix.fromArray(
            [
                [1, 0, 0, 0, 0],
                [0, 1, 0, 0, 0],
                [0, 0, 0, 1, 0],
                [0, 0, 0, 0, 1],
                [7, 7, 6, 6, 1]
            ]
        );

        var mInvExpected = Matrix.fromArray(
            [
                [1, 0, 0, 0, 0],
                [0, 1, 0, 0, 0],
                [123, 123, 1, 122, 122],
                [0, 0, 1, 0, 0],
                [0, 0, 0, 1, 0]
            ]
        );

        Assert.isTrue(m.invert().equals(mInvExpected));

        Assert.isTrue(
            Matrix.identity(5).equals(m.times(m.invert())));
    }


}