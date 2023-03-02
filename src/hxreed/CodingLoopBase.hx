package hxreed;



using haxe.io.Bytes;

abstract class CodingLoopBase implements CodingLoop {
    public function checkSomeShards(
            matrixRows: Array<Bytes>,
            inputs: Array<Bytes>, inputCount: Int,
            toCheck: Array<Bytes>, checkCount: Int,
            offset: Int, byteCount: Int,
            tempBuffer: Bytes): Bool {
        
        var table = Galois.MULTIPLICATION_TABLE;
        for(iByte in offset...(offset+byteCount)) {
            for(iOutput in 0...checkCount) {
                var matrixRow: Bytes = matrixRows[iOutput];
                var value: Int = 0;
                for(iInput in 0...inputCount) {
                    value ^= table[matrixRow.get(iInput) & 0xFF][inputs[iInput].get(iByte) & 0xFF];
                }
                if (toCheck[iOutput].get(iByte) != value)
                    return false;
            }
        }

        return true;
     }
}