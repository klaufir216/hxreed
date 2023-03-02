package hxreed;

import haxe.io.Bytes;
import haxe.exceptions.ArgumentException;

class Matrix {
    var rows: Int;
    var columns: Int;

    public var data: Array<Bytes>;
    public function new(initRows: Int, initColumns: Int) {
        rows = initRows;
        columns = initColumns;
        data = new Array();
        data.resize(rows);
        for(r in 0...rows) {
            data[r] = Bytes.alloc(columns);
        }
    }

    public static function fromByteArray(initData: Array<Bytes>): Matrix {
        var rows = initData.length;
        var columns = initData[0].length;
        var result: Matrix = new Matrix(rows, columns);
        for (r in 0...rows)
            for (c in 0...columns)
                result.data[r].set(c, initData[r].get(c));
        return result;
    }

    public static function fromArray(initData: Array<Array<Int>>): Matrix {
        var rows = initData.length;
        var columns = initData[0].length;
        var result = new Matrix(rows, columns);
        for (r in 0...rows)
            for (c in 0...columns)
                result.data[r].set(c, initData[r][c]);
        return result;
    }

    public static function identity(size: Int): Matrix {
        var result = new Matrix(size, size);
        for (i in 0...size)
            result.set(i, i, 1);
        return result;
    }

    public function toString(): String {
        var result = new StringBuf();
        result.add('[');
        for (r in 0...rows) {
            if (r != 0)
                result.add(", ");
            result.add('[');
            for (c in 0...columns) {
                if (c != 0)
                    result.add(", ");
                result.add(data[r].get(c) & 0xFF);
            }
            result.add("]");
        }
        result.add(']');
        return result.toString();
    }

    public function toBigString(): String {
        var result = new StringBuf();
        for (r in 0...rows) {
            for (c in 0...columns) {
                var value: Int = get(r, c);
                result.add(StringTools.hex(value, 2) + " ");
            }
            result.add("\n");
        }
                
        return result.toString();
    }

    public function getColumns(): Int {
        return columns;
    }

    public function getRows(): Int {
        return rows;
    }

    public function get(r: Int, c: Int) {
        if (r < 0 || rows <= r)
            throw new ArgumentException("r", "Row index out of range: " + r);
        if (c < 0 || columns <= c)
            throw new ArgumentException("c", "Column index out of range: " + c);

        return data[r].get(c);
    }

    public function set(r: Int, c: Int, value: Int) {
        if (r < 0 || rows <= r)
            throw new ArgumentException("r", "Row index out of range: " + r);
        if (c < 0 || columns <= c)
            throw new ArgumentException("c", "Column index out of range: " + c);
        data[r].set(c, value);
    }

    public function equals(other: Matrix):Bool {
        if (other.getColumns() != columns
            || other.getRows() != rows)
            return false;

        for (r in 0...rows)
            for (c in 0...columns)
                if (this.get(r,c) != other.get(r,c))
                    return false;

        return true;
    }

    public function times(right: Matrix): Matrix {
        if (getColumns() != right.getRows())
            throw new ArgumentException("right",
                "Columns on left (" + getColumns() +") " +
                "is different than rows on right (" + right.getRows() + ")");
        var result: Matrix = new Matrix(getRows(), right.getColumns());
        for (r in 0...getRows())
            for (c in 0...right.getColumns()) {
                var value: Int = 0;
                for (i in 0...getColumns())
                    value ^= Galois.multiply(get(r,i), right.get(i, c));
                result.set(r, c, value & 0xFF);
            }

        return result;
    }

    public function augment(right: Matrix): Matrix {
        if (rows != right.rows)
            throw new ArgumentException("right", 
                "Matrices don't have the same number of rows");
        var result: Matrix = new Matrix(rows, columns + right.columns);
        for (r in 0...rows) {
            for (c in 0...columns)
                result.data[r].set(c, data[r].get(c));
            for (c in 0...right.columns)
                result.data[r].set(columns + c, right.data[r].get(c));
        }

        return result;
    }

    public function submatrix(rmin: Int, cmin: Int, rmax: Int, cmax: Int): Matrix {
        var result = new Matrix(rmax - rmin, cmax - cmin);
        for (r in rmin...rmax)
            for (c in cmin...cmax)
                result.data[r - rmin].set(c - cmin, data[r].get(c));
        return result;
    }

    public function getRow(row: Int): Bytes {
        var result = Bytes.alloc(columns);
        for (c in 0...columns)
            result.set(c, this.get(row, c));
        return result;
    }

    public function swapRows(r1: Int, r2: Int) {
        if (r1 < 0 || rows <= r1)
            throw new ArgumentException("r1", "Row index out of range");

        if (r2 < 0 || rows <= r2)
            throw new ArgumentException("r2", "Row index out of range");

        var tmp: Bytes = data[r1];
        data[r1] = data[r2];
        data[r2] = tmp;
    }

    /**
     * Returns the inverse of this matrix.
     *
     * @throws IllegalArgumentException when the matrix is singular and
     * doesn't have an inverse.
     */
    public function invert(): Matrix {
        if (rows != columns) {
            throw new ArgumentException("this", "Only square matrices can be inverted");
        }

        var work = augment(identity(rows));
        work.gaussianElimination();
        return work.submatrix(0, rows, columns, columns*2);
    }

    private function gaussianElimination(): Void {
        // Clear out the part below the main diagonal and scale the main
        // diagonal to be 1.
        for (r in 0...rows) {
            // If the element on the diagonal is 0, find a row below
            // that has a non-zero and swap them.
            if (data[r].get(r) == 0) {
                for (rowBelow in (r+1)...rows) {
                    if (data[rowBelow].get(r) != 0) {
                        swapRows(r, rowBelow);
                        break;
                    }
                }
            }

            // If we couldn't find one, the matrix is singular.
            if (data[r].get(r) == 0)
                throw new haxe.exceptions.ArgumentException("this", "Matrix is singular");

            if (data[r].get(r) != 1) {
                var scale: Int = Galois.divide(1, data[r].get(r));
                for (c in 0...columns) {
                    data[r].set(c, Galois.multiply(data[r].get(c), scale));
                }
            }

            // Make everything below the 1 be a 0 by subtracting
            // a multiple of it.  (Subtraction and addition are
            // both exclusive or in the Galois field.)
            for (rowBelow in (r+1)...rows) {
                if (data[rowBelow].get(r) != 0) {
                    var scale: Int = data[rowBelow].get(r);
                    for (c in 0...columns) {
                        var v = data[rowBelow].get(c);
                        data[rowBelow].set(c, 
                            v ^ Galois.multiply(scale, data[r].get(c)));
                    }
                }
            }
        }

        // Now clear the part above the main diagonal.
        for (d in 0...rows) {
            for (rowAbove in 0...d) {
                if (data[rowAbove].get(d) != 0) {
                    var scale = data[rowAbove].get(d);
                    for (c in 0...columns) {
                        var v = data[rowAbove].get(c);
                        data[rowAbove].set(c, 
                            v ^ Galois.multiply(scale, data[d].get(c)));
                    }
                }
            }
        }
    }
}