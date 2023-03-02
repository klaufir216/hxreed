package hxreed;


import haxe.io.Bytes;

class Bytes2D
{
    private var internalBytes:Bytes;
    public var rows:Int;
    public var columns:Int;
    public function new(rows:Int, columns:Int)
    {
        this.rows = rows;
        this.columns = columns;
        internalBytes = Bytes.alloc(rows*columns);
    }

    public inline function get(row: Int, col: Int): Int {
        return internalBytes.get(col*rows+row);
        //return Bytes.fastGet(internalBytes.getData(), col*rows+row);
    }
    
    public inline function set(row:Int, col:Int, value:Int): Void {
        internalBytes.set(col*rows+row, value);
    }
}
