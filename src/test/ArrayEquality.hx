package test;

class ArrayEquality {
    static public function equals<T>(a: Array<T>, b: Array<T>): Bool {
        if (a.length != b.length)
            return false;
        for(i in 0...a.length) {
            if (a[i] != b[i])
                return false;
        }
        return true;
    }
}