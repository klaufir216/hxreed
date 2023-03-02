package test;

class Main {
	static function main() {
		//utest.UTest.run([new GaloisTest(), new MatrixTest()]);
		//ReedSolomonTest
		utest.UTest.run([new ReedSolomonTest()]);
		

		
	}
}
