package hxreed;

import haxe.io.Bytes;

class InputOutputByteTableCodingLoop extends CodingLoopBase {
    public function new() {}
    
    public function codeSomeShards(
        matrixRows: Array<Bytes>,
        inputs: Array<Bytes>, inputCount: Int,
        outputs: Array<Bytes>, outputCount: Int,
        offset: Int, byteCount: Int): Void {
            var table = Galois.MULTIPLICATION_TABLE;

            var iInput = 0;
            var inputShard: Bytes = inputs[iInput];
            for (iOutput in 0...outputCount) {
                var outputShard = outputs[iOutput];
                var matrixRow = matrixRows[iOutput];
                var multTableRow = table[matrixRow.get(iInput)];
                for (iByte in offset...(offset+byteCount)) {
                    outputShard.set(iByte, multTableRow[inputShard.get(iByte)]);
                }
            }

            for (iInput in 1...inputCount) {
                var inputShard = inputs[iInput];
                for (iOutput in 0...outputCount) {
                    var outputShard = outputs[iOutput];
                    var matrixRow = matrixRows[iOutput];
                    var multTableRow = table[matrixRow.get(iInput)];
                    for (iByte in offset...(offset+byteCount)) {
                        outputShard.set(iByte,
                            outputShard.get(iByte) ^
                            multTableRow[inputShard.get(iByte)]);
                    }
                }
            }
        }

    public override function checkSomeShards(
        matrixRows: Array<Bytes>,
        inputs: Array<Bytes>, inputCount: Int,
        toCheck: Array<Bytes>, checkCount: Int,
        offset: Int, byteCount: Int,
        tempBuffer: Bytes
     ): Bool {

        if (tempBuffer == null) {
            return super.checkSomeShards(
                matrixRows, 
                inputs, inputCount,
                toCheck, checkCount,
                offset, byteCount,
                null);
        }

        // This is actually the code from OutputInputByteTableCodingLoop.
        // Using the loops from this class would require multiple temp
        // buffers.
        var table = Galois.MULTIPLICATION_TABLE;
        for (iOutput in 0...checkCount)
            {
                var outputShard = toCheck[iOutput];
                var matrixRow = matrixRows[iOutput];
                {
                    var iInput =  0;
                    var inputShard = inputs[iInput];
                    var multTableRow = table[matrixRow.get(iInput)];
                    for (iByte in offset...(offset+byteCount)) {
                        tempBuffer.set(iByte, multTableRow[inputShard.get(iByte)]);
                    }
                }
                for (iInput in 1...inputCount) {
                    var inputShard = inputs[iInput];
                    var multTableRow = table[matrixRow.get(iInput)];
                    for (iByte in offset...(offset+byteCount)) {
                        tempBuffer.set(iByte,
                            tempBuffer.get(iByte) ^
                            multTableRow[inputShard.get(iByte)]
                            );
                    }
                }
                for (iByte in offset...(offset+byteCount)) {
                    if (tempBuffer.get(iByte) != outputShard.get(iByte)) {
                        return false;
                    }
                }
            }
        return true;
     }
}