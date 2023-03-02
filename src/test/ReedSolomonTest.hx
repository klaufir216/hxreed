package test;

import hxreed.AllCodingLoops;
import utest.Assert;
import haxe.io.Bytes;
import hxreed.ReedSolomon;

using test.ArrayEquality;


class ReedSolomonTest extends utest.Test {
    function testZeroSizeEncode() {
        var codec = ReedSolomon.create(2,1);
        var shards = new Array<Bytes>(); shards.resize(3);
        for (i in 0...3) shards[i] = Bytes.alloc(0);
        codec.encodeParity(shards, 0, 0);
        Assert.pass();
    }

    function testOneEncode() {
        for (codingLoop in AllCodingLoops.ALL_CODING_LOOPS) {
            var codec = new ReedSolomon(5, 5, codingLoop);
            var shards = new Array<Bytes>(); shards.resize(10);
            for (i in 0...10) shards[i] = Bytes.alloc(2);
            shards[0].set(0, 0); shards[0].set(1, 1);
            shards[1].set(0, 4); shards[1].set(1, 5);
            shards[2].set(0, 2); shards[2].set(1, 3);
            shards[3].set(0, 6); shards[3].set(1, 7);
            shards[4].set(0, 8); shards[4].set(1, 9);
            codec.encodeParity(shards, 0, 2);
            
            Assert.isTrue(
                shards[5].get(0) == 12 && shards[5].get(1) == 13
                && shards[6].get(0) == 10 && shards[6].get(1) == 11
                && shards[7].get(0) == 14 && shards[7].get(1) == 15
                && shards[8].get(0) == 90 && shards[8].get(1) == 91
                && shards[9].get(0) == 94 && shards[9].get(1) == 95
             );

             Assert.isTrue(codec.isParityCorrect(shards, 0, 2));
             shards[8].set(0, shards[8].get(0)+1);
             Assert.isFalse(codec.isParityCorrect(shards, 0, 2));
        }
    }

    /** Return a random integer between ['from' and 'to'), [inclusive, exclusive). */
    public static inline function randInt(start:Int, end:Int):Int
    {
        return start + Math.floor(((end - start) * Math.random()));
    }

    function testBigEncodeDecode() {
        var dataCount = 64;
        var parityCount = 64;
        var shardSize = 200;
        var dataShards = new Array<Bytes>(); dataShards.resize(dataCount);
        for (i in 0...dataCount) {
            dataShards[i] = Bytes.alloc(shardSize);
        }
        for (shard in dataShards) {
            for (i in 0...shard.length) {
                shard.set(i, randInt(0, 256));
            }
        }
        runEncodeDecode(dataCount, parityCount, dataShards);
             
    }

    @Ignore
    function runEncodeDecode(dataCount:Int, parityCount:Int, dataShards:Array<Bytes>) {
        var totalCount = dataCount + parityCount;
        var shardLength = dataShards[0].length;

        // Make the list of data and parity shards.
        if (dataCount != dataShards.length)
            Assert.fail("dataCount != dataShards.length");

        var dataLength = dataShards[0].length;
        var allShards = new Array<Bytes>(); allShards.resize(totalCount);
        for (i in 0...dataCount) {
            allShards[i] = Bytes.alloc(dataLength);
            allShards[i].blit(0, dataShards[i], 0, dataLength);
        }

        for (i in dataCount...totalCount) {
            allShards[i] = Bytes.alloc(dataLength);
        }

        // Encode.
        var codec:ReedSolomon = ReedSolomon.create(dataCount, parityCount);
        codec.encodeParity(allShards, 0, dataLength);

        // Make a copy to decode with.
        var testShards = new Array<Bytes>(); testShards.resize(totalCount);
        var shardPresent = new Array<Bool>();
        for (i in 0...totalCount) {
            testShards[i] = Bytes.alloc(shardLength);
            testShards[i].blit(0, allShards[i], 0, shardLength);
            shardPresent[i] = true;
        }

        // Decode with 0, 1, ..., 5 shards missing.
        var success = true;
        for (numberMissing in 0...(parityCount+1)) {
            trace(numberMissing, "/", parityCount+1);
            if (!tryAllSubsetsMissing(codec, allShards, testShards, shardPresent, numberMissing)) {
                Assert.fail("tryAllSubsetsMissing failed.");
            }
        }
        Assert.pass();
    }

    @Ignore
    function tryAllSubsetsMissing(
        codec:ReedSolomon,
        allShards:Array<Bytes>, testShards:Array<Bytes>,
        shardPresent:Array<Bool>, numberMissing:Int):Bool {
            var shardLength = allShards[0].length;
            var subsets:Array<Array<Int>> = allSubsets(numberMissing, 0, 10);
            for (subset in subsets) {
                // Get rid of the shards specified by this subset.
                for (missingShard in subset) {
                    clearBytes(testShards[missingShard]);
                    shardPresent[missingShard] = false;
                }

                // Reconstruct the missing shards
                codec.decodeMissing(testShards, shardPresent, 0, shardLength);

                // Check the results.  After checking, the contents of testShards
                // is ready for the next test, the next time through the loop.
                if (!checkShards(allShards, testShards)) {
                    return false;
                }

                // Put the "present" flags back
                for (i in 0...codec.getTotalShardCount()) {
                    shardPresent[i] = true;
                }
            }
            return true;
        }

    @Ignore
    function computeParityShards(dataShards: Array<Bytes>, codec: ReedSolomon) {
        var shardSize = dataShards[0].length;
        var totalShardCount = codec.getTotalShardCount();
        var dataShardCount = codec.getDataShardCount();
        var parityShardCount = codec.getParityShardCount();
        var parityShards = new Array<Bytes>();
        parityShards.resize(parityShardCount);
        for (i in 0...shardSize) {
            parityShards[i] = Bytes.alloc(shardSize);
        }

        var allShards = new Array<Bytes>();
        allShards.resize(totalShardCount);

        for (iShard in 0...totalShardCount) {
            if (iShard < dataShardCount) {
                allShards[iShard] = dataShards[iShard];
            } else {
                allShards[iShard] = parityShards[iShard - dataShardCount];                
            }
        }

        codec.encodeParity(allShards, 0, shardSize);
        var tempBuffer = Bytes.alloc(shardSize);
        allShards[parityShardCount - 1].set(0, allShards[parityShardCount - 1].get(0) + 1);
        var mustBeFalse1 = codec.isParityCorrect(allShards, 0, shardSize);
        var mustBeFalse2 = codec.isParityCorrect(allShards, 0, shardSize, tempBuffer);
        allShards[parityShardCount - 1].set(0, allShards[parityShardCount - 1].get(0) - 1);
        var mustBeTrue1 = codec.isParityCorrect(allShards, 0, shardSize);
        var mustBeTrue2 = codec.isParityCorrect(allShards, 0, shardSize, tempBuffer);
        Assert.isTrue(
            !mustBeFalse1 && !mustBeFalse2
            && mustBeTrue1 && mustBeTrue2
        );
    }

    @Ignore
    function clearBytes(data: Bytes) {
        data.fill(0, data.length, 0);
    }

    @Ignore
    function checkShards(expectedShards:Array<Bytes>, actualShards:Array<Bytes>):Bool {
        if (expectedShards.length != actualShards.length) {
            trace("expectedShards.length != actualShards.length");
            return false;
        }

        var success = true;

        for (i in 0...expectedShards.length) {
            success = success && (expectedShards[i].compare(actualShards[i]) == 0);
        }
        return success;
    }

    @Ignore
    public function allSubsets(n:Int, min:Int, max:Int):Array<Array<Int>> {
        var result:Array<Array<Int>> = new Array<Array<Int>>();
        if (n == 0) {
            result.push([]);
        } else {
            for (i in min...(max-n)) { // TODO: this should be: (max+n), but then tests run forever
                var prefix = [i];
                for (suffix in allSubsets(n-1, i+1, max)) {
                    result.push(appendIntArrays(prefix, suffix));
                }
            }
        }
        return result;
    }

    @Ignore
    function appendIntArrays(a:Array<Int>, b:Array<Int>):Array<Int> {
        var result = new Array<Int>();
        result.resize(a.length + b.length);
        var rIdx:Int = 0;
        for (i in 0...a.length)
            result[rIdx++] = a[i];
        for (i in 0...b.length)
            result[rIdx++] = b[i];
        return result;
    }
}