package test;

import utest.Assert;
import hxreed.Galois;
using test.ArrayEquality;


class GaloisTest extends utest.Test {
    function testClosure() {
        for (a in 0...256) {
            for (b in 0...256) {
                var v1 = Galois.add(a, b);
                if (v1 < 0 || v1 > 255) {
                    Assert.fail("add is outside of field.");
                    return;
                }

                var v2 = Galois.subtract(a, b);
                if (v2 < 0 || v2 > 255) {
                    Assert.fail("subtract is outside of field.");
                    return;
                }
                
                var v3 = Galois.multiply(a, b);
                if (v3 < 0 || v3 > 255) {
                    Assert.fail("multiply is outside of field.");
                    return;
                }

                if (b > 0) {
                    var v4 = Galois.divide(a, b);
                    if (v4 < 0 || v4 > 255) {
                        Assert.fail("divide is outside of field. " + a + " / " + b + " => " + v4);
                        return;
                    }
                }
            }
        }
        Assert.pass();
    }

    function testAssociativity() {
        var result: Bool = true;
        for (a in 0...256) {
            for (b in 0...256) {
                for (c in 0...256) {
                    if (Galois.add(a, Galois.add(b, c)) != Galois.add(Galois.add(a,b), c)) {
                        Assert.fail("add failed");
                        return;
                    }

                    if (Galois.multiply(a, Galois.multiply(b, c)) != Galois.multiply(Galois.multiply(a,b), c)) {
                        Assert.fail("multiply failed");
                        return;
                    }
                }
            }
        }
        Assert.pass();
    }

    function testIdentity() {
        for (a in 0...256) {
            if (Galois.add(a, 0) != a) {
                Assert.fail("add identity fail.");
                return;
            }

            if (Galois.multiply(a, 1) != a) {
                Assert.fail("multiply identity fail.");
                return;
            }
        }
        Assert.pass();
    }

    function testInverse() {
        for (a in 0...256) {
            var b = Galois.subtract(0, a);
            if (Galois.add(a, b) != 0) {
                Assert.fail("add subtract inverse fail.");
                return;
            }

            if (a != 0) {
                b = Galois.divide(1, a);
                if (Galois.multiply(a, b) != 1) {
                    Assert.fail("multiply divide inverse fail.");
                    return;
                }
            }
        }
        Assert.pass();
    }

    function testCommutativity() {
        for (a in 0...256) {
            for (b in 0...256) {
                if (Galois.add(a, b) != Galois.add(b, a)) {
                    Assert.fail();
                    return;
                }

                if (Galois.multiply(a,b) != Galois.multiply(b, a)) {
                    Assert.fail();
                    return;
                }
            }
        }
        Assert.pass();
    }

    function testDistributivity() {
        for (a in 0...256) {
            for (b in 0...256) {
                for (c in 0...256) {
                    if (Galois.multiply(a, Galois.add(b, c))
                        != Galois.add(Galois.multiply(a, b), Galois.multiply(a,c))) {
                            Assert.fail();
                            return;
                        }
                }
            }
        }
        Assert.pass();
    }

    function testExp() {
        for (a in 0...256) {
            var power = 1;
            for (j in 0...256) {
                if (power != Galois.exp(a, j)) {
                    Assert.fail();
                    return;
                }
                power = Galois.multiply(power, a);
            }
        }
        Assert.pass();
    }

    function testGenerateLogTable() {
        var logTable = Galois.generateLogTable(Galois.GENERATING_POLYNOMIAL);
        Assert.isTrue(logTable.equals(Galois.LOG_TABLE));

		var expTable = Galois.generateExpTable(logTable);
        Assert.isTrue(expTable.equals(Galois.EXP_TABLE));

        var polynomials = [29,43,45,77,95,99,101,105,113,135,141,169,195,207,231,245];
        Assert.isTrue(polynomials.equals(Galois.allPossiblePolynomials()));
    }

    function testMultiplicationTable() {
        var table = Galois.MULTIPLICATION_TABLE;
        for (a in 0...256) {
            for (b in 0...256) {
                if (Galois.multiply(a, b) != table[a][b]) {
                    Assert.fail();
                    return;
                }
            }
        }
        Assert.pass();
    }

    function testWithPythonAnswers() {
        Assert.equals(12, Galois.multiply(3, 4));
        Assert.equals(21, Galois.multiply(7, 7));
        Assert.equals(41, Galois.multiply(23, 45));

        Assert.equals(4, Galois.exp(2,2));
        Assert.equals(235, Galois.exp(5, 20));
        Assert.equals(43, Galois.exp(13, 7));
        
    }


}