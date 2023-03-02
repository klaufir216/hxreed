package hxreed;

import haxe.io.Bytes;
import haxe.exceptions.ArgumentException;

class ReedSolomon {
    private var dataShardCount:Int;
    private var parityShardCount:Int;
    private var totalShardCount:Int;
    private var matrix:Matrix;
    private var codingLoop:CodingLoop;

    /**
     * Rows from the matrix for encoding parity, each one as its own
     * byte array to allow for efficient access while encoding.
     */
    private var parityRows:Array<Bytes>;
     
    public static function create(dataShardCount:Int, parityShardCount:Int): ReedSolomon {
        return new ReedSolomon(dataShardCount, parityShardCount,
            new InputOutputByteTableCodingLoop());
     }
    

    public function new(dataShardCount:Int, parityShardCount:Int, codingLoop:CodingLoop) {
        // We can have at most 256 shards total, as any more would
        // lead to duplicate rows in the Vandermonde matrix, which
        // would then lead to duplicate rows in the built matrix
        // below. Then any subset of the rows containing the duplicate
        // rows would be singular.
        if (256 < dataShardCount + parityShardCount) {
            throw new ArgumentException("dataShardCount + parityShardCount",
                "too many shards - max is 256");
        }

        this.dataShardCount = dataShardCount;
        this.parityShardCount = parityShardCount;
        this.codingLoop = codingLoop;
        this.totalShardCount = dataShardCount + parityShardCount;
        this.matrix = buildMatrix(dataShardCount, this.totalShardCount);
        this.parityRows = new Array<Bytes>();
        this.parityRows.resize(parityShardCount);
        for (i in 0...parityShardCount) {
            parityRows[i] = matrix.getRow(dataShardCount + i);
        }
    }

    /**
     * Returns the number of data shards.
     */
    public function getDataShardCount():Int {
        return dataShardCount;
    }

    /**
     * Returns the number of parity shards.
     */
    public function getParityShardCount():Int {
        return parityShardCount;
    }

    /**
     * Returns the total number of shards.
     */
    public function getTotalShardCount():Int {
        return totalShardCount;
    }

    /**
     * Encodes parity for a set of data shards.
     *
     * @param shards An array containing data shards followed by parity shards.
     *               Each shard is a byte array, and they must all be the same
     *               size.
     * @param offset The index of the first byte in each shard to encode.
     * @param byteCount The number of bytes to encode in each shard.
     *
     */
    public function encodeParity(shards:Array<Bytes>, offset:Int, byteCount:Int) {
        // check arguments
        checkBuffersAndSizes(shards, offset, byteCount);

        // Build the array of output buffers.
        var outputs = new Array<Bytes>();
        outputs.resize(parityShardCount);

        //                 src     srcPos          dst      dstPos  len
        //System.arraycopy(shards, dataShardCount, outputs, 0,      parityShardCount);
        for (dstIdx in 0...parityShardCount) {
            var srcIdx = dataShardCount + dstIdx;
            outputs[dstIdx] = shards[srcIdx];
        }

        codingLoop.codeSomeShards(
            parityRows,
            shards, dataShardCount,
            outputs, parityShardCount,
            offset, byteCount);
    }

    /**
     * Encodes parity for a set of data shards.
     *
     * @param shards An array containing data shards followed by parity shards.
     *               Each shard is a byte array, and they must all be the same
     *               size.
     * @param offset The index of the first byte in each shard to encode.
     * @param byteCount The number of bytes to encode in each shard.
     * @param tempBuffer A temporary buffer (the same size as each of the
     *                   shards) to use when computing parity.
     *
     */
    public function isParityCorrect(shards: Array<Bytes>, firstByte:Int, byteCount:Int, ?tempBuffer:Bytes):Bool {
        // Check arguments.
        checkBuffersAndSizes(shards, firstByte, byteCount);

        if (tempBuffer != null && tempBuffer.length < firstByte + byteCount) {
            throw new ArgumentException("tempBuffer", "tempBuffer.length < firstByte + byteCount");
        }

        // Build the array of buffers being checked.
        var toCheck = new Array<Bytes>();
        toCheck.resize(parityShardCount);

        //System.arraycopy(shards, dataShardCount, toCheck, 0, parityShardCount);
        for (dstIdx in 0...parityShardCount) {
            var srcIdx = dstIdx + dataShardCount;
            toCheck[dstIdx] = shards[srcIdx];
        }

        return codingLoop.checkSomeShards(
            parityRows,
            shards, dataShardCount,
            toCheck, parityShardCount,
            firstByte, byteCount,
            tempBuffer
        );
    }

    public function decodeMissing(shards: Array<Bytes>, 
                                  shardPresent:Array<Bool>,
                                  offset:Int,
                                  byteCount:Int):Void {
        checkBuffersAndSizes(shards, offset, byteCount);

        // Quick check: are all of the shards present?  If so, there's
        // nothing to do.
        var numberPresent = 0;
        for (i in 0...totalShardCount) {
            if (shardPresent[i])
                numberPresent += 1;
        }

        if (numberPresent == totalShardCount)
            return;

        if (numberPresent < dataShardCount)
            throw new ArgumentException("dataShardCount", "Not enough shards present");
     
        // Pull out the rows of the matrix that correspond to the
        // shards that we have and build a square matrix.  This
        // matrix could be used to generate the shards that we have
        // from the original data.
        //
        // Also, pull out an array holding just the shards that
        // correspond to the rows of the submatrix.  These shards
        // will be the input to the decoding process that re-creates
        // the missing data shards.
        var subMatrix:Matrix = new Matrix(dataShardCount, dataShardCount);
        var subShards = new Array<Bytes>(); subShards.resize(dataShardCount);
        {
            var subMatrixRow = 0;
            for (matrixRow in 0...totalShardCount) {
                if (subMatrixRow >= dataShardCount) break;
                if (shardPresent[matrixRow]) {
                    for (c in 0...dataShardCount) {
                        subMatrix.set(subMatrixRow, c, matrix.get(matrixRow, c));
                    }
                    subShards[subMatrixRow] = shards[matrixRow];
                    subMatrixRow += 1;
                }

            }
        }
        // Invert the matrix, so we can go from the encoded shards
        // back to the original data.  Then pull out the row that
        // generates the shard that we want to decode.  Note that
        // since this matrix maps back to the orginal data, it can
        // be used to create a data shard, but not a parity shard.
        var dataDecodeMatrix = subMatrix.invert();

        // Re-create any data shards that were missing.
        //
        // The input to the coding is all of the shards we actually
        // have, and the output is the missing data shards.  The computation
        // is done using the special decode matrix we just built.
        var outputs:Array<Bytes> = new Array(); outputs.resize(parityShardCount);
        var matrixRows:Array<Bytes> = new Array(); outputs.resize(parityShardCount);
        var outputCount = 0;
        for (iShard in 0...dataShardCount) {
            if (!shardPresent[iShard]) {
                outputs[outputCount] = shards[iShard];
                matrixRows[outputCount] = dataDecodeMatrix.getRow(iShard);
                outputCount += 1;
            }
        }

        codingLoop.codeSomeShards(
            matrixRows,
            subShards, dataShardCount,
            outputs, outputCount,
            offset, byteCount
        );

        // Now that we have all of the data shards intact, we can
        // compute any of the parity that is missing.
        //
        // The input to the coding is ALL of the data shards, including
        // any that we just calculated.  The output is whichever of the
        // data shards were missing.
        outputCount = 0;
        for (iShard in dataShardCount...totalShardCount) {
            if (!shardPresent[iShard]) {
                outputs[outputCount] = shards[iShard];
                matrixRows[outputCount] = parityRows[iShard - dataShardCount];
                outputCount += 1;
            }
        }

        codingLoop.codeSomeShards(
            matrixRows,
            shards, dataShardCount,
            outputs, outputCount,
            offset, byteCount
        );
    }

    /**
     * Checks the consistency of arguments passed to public methods.
     */
     private function checkBuffersAndSizes(shards: Array<Bytes>, offset:Int, byteCount: Int) {
        // The number of buffers should be equal to the number of
        // data shards plus the number of parity shards.
        if (shards.length != totalShardCount) {
            throw new ArgumentException("shards",
            "wrong number of shards: " + shards.length);
        }

        // All of the shard buffers should be the same length.
        var shardLength:Int = shards[0].length;
        for (i in 1...shards.length) {
            if (shards[i].length != shardLength) {
                throw new ArgumentException("shards", 
                    "Shards are different sizes");
            }
        }

        // The offset and byteCount must be non-negative and fit in the buffers.
        if (offset < 0) {
            throw new ArgumentException("offset",
            "offset is negative: " + offset);
        }

        if (byteCount < 0) {
            throw new ArgumentException("byteCount",
                "byteCount is negative: " + byteCount);
        }

        if (shardLength < offset + byteCount) {
            throw new ArgumentException("offset + byteCount",
                "buffers to small: " + byteCount + offset);
        }
     }


    /**
     * Create the matrix to use for encoding, given the number of
     * data shards and the number of total shards.
     *
     * The top square of the matrix is guaranteed to be an identity
     * matrix, which means that the data shards are unchanged after
     * encoding.
     */
     private static function buildMatrix(dataShards:Int, totalShards:Int) {
        // Start with a Vandermonde matrix.  This matrix would work,
        // in theory, but doesn't have the property that the data
        // shards are unchanged after encoding.
        var vandermonde = vandermonde(totalShards, dataShards);

        // Multiple by the inverse of the top square of the matrix.
        // This will make the top square be the identity matrix, but
        // preserve the property that any square subset of rows is
        // invertible.
        var top = vandermonde.submatrix(0,0,dataShards, dataShards);
        return vandermonde.times(top.invert());
     }

    /**
     * Create a Vandermonde matrix, which is guaranteed to have the
     * property that any subset of rows that forms a square matrix
     * is invertible.
     *
     * @param rows Number of rows in the result.
     * @param cols Number of columns in the result.
     * @return A Matrix.
     */
     private static function vandermonde(rows:Int, cols:Int): Matrix {
        var result = new Matrix(rows, cols);
        for (r in 0...rows) {
            for (c in 0...cols) {
                result.set(r, c, Galois.exp(r, c));
            }
        }
        return result;
     }

}