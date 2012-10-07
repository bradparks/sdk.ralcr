﻿import flash.display.BitmapData;
import flash.utils.ByteArray;
import flash.Vector;


class JPGEncoder10 {
	// Static table initialization
	inline static var ZigZag :Vector<Int> = flash.Lib.vectorOfArray([
		 0, 1, 5, 6,14,15,27,28,
		 2, 4, 7,13,16,26,29,42,
		 3, 8,12,17,25,30,41,43,
		 9,11,18,24,31,40,44,53,
		10,19,23,32,39,45,52,54,
		20,22,33,38,46,51,55,60,
		21,34,37,47,50,56,59,61,
		35,36,48,49,57,58,62,63
	]);
	
	var YTable :Vector<Int>;
	var UVTable :Vector<Int>;
	var outputfDCTQuant :Vector<Int>;
	var fdtbl_Y :Vector<Float>;
	var fdtbl_UV :Vector<Float>;
	var sf :Int;
	
	static var aasf :Vector<Float> = flash.Lib.vectorOfArray([
			1.0, 1.387039845, 1.306562965, 1.175875602,
			1.0, 0.785694958, 0.541196100, 0.275899379
		]);
	
	static var YQT :Vector<Int> = flash.Lib.vectorOfArray([
			16, 11, 10, 16, 24, 40, 51, 61,
			12, 12, 14, 19, 26, 58, 60, 55,
			14, 13, 16, 24, 40, 57, 69, 56,
			14, 17, 22, 29, 51, 87, 80, 62,
			18, 22, 37, 56, 68,109,103, 77,
			24, 35, 55, 64, 81,104,113, 92,
			49, 64, 78, 87,103,121,120,101,
			72, 92, 95, 98,112,100,103, 99
		]);
	
	static var UVQT :Vector<Int> = flash.Lib.vectorOfArray([
			17, 18, 24, 47, 99, 99, 99, 99,
			18, 21, 26, 66, 99, 99, 99, 99,
			24, 26, 56, 99, 99, 99, 99, 99,
			47, 66, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99
		]);
	
	
	public function new (quality:Int=80) {
		
		YTable = new Vector<Int>(64, true);
		UVTable = new Vector<Int>(64, true);
		outputfDCTQuant = new Vector<Int>(64, true);
		fdtbl_Y = new Vector<Float>(64, true);
		fdtbl_UV = new Vector<Float>(64, true);
		
		if (quality <= 0)
			quality = 1;
	
		if (quality > 100)
			quality = 100;
			
		sf = quality < 50 ? cast(5000 / quality, Int) : cast(200 - (quality<<1), Int);
		init();
	}
	
	function init () :Void {
		ZigZag.fixed = true;
		aasf.fixed = true;
		YQT.fixed = true;
		UVQT.fixed = true;
		std_ac_chrominance_nrcodes.fixed = true;
		std_ac_chrominance_values.fixed = true;
		std_ac_luminance_nrcodes.fixed = true;
		std_ac_luminance_values.fixed = true;
		std_dc_chrominance_nrcodes.fixed = true;
		std_dc_chrominance_values.fixed = true;
		std_dc_luminance_nrcodes.fixed = true;
		std_dc_luminance_values.fixed = true;
		// Create tables
		initHuffmanTbl();
		initCategoryFloat();
		initQuantTables(sf);
	}

	public function encode (image:BitmapData) :ByteArray {
		// Initialize bit writer
		byteout = new ByteArray();
		YDU = new Vector<Float>(64, true);
		UDU = new Vector<Float>(64, true);
		VDU = new Vector<Float>(64, true);
		DU = new Vector<Int>(64, true);
		
		// Add JPEG headers
		byteout.writeShort(0xFFD8); // SOI
		writeAPP0();
		writeDQT();
		writeSOF0 (image.width, image.height);
		writeDHT();
		writeSOS();
		
		// Encode 8x8 macroblocks
		var DCY:Float=0;
		var DCU:Float=0;
		var DCV:Float=0;
		bytenew=0;
		bytepos=7;
		
		var width:Int = cast ( image.width, Int );
		var height:Int = cast ( image.height, Int );
		
		var ypos :Int = 0;
		while (ypos < height) {
			var xpos :Int = 0;
			while (xpos < width) {
				RGB2YUV (image, xpos, ypos);
				DCY = processDU (YDU, fdtbl_Y,  DCY, YDC_HT,  YAC_HT);
				DCU = processDU (UDU, fdtbl_UV, DCU, UVDC_HT, UVAC_HT);
				DCV = processDU (VDU, fdtbl_UV, DCV, UVDC_HT, UVAC_HT);
				xpos += 8;
			}
			ypos += 8;
		}
		
		
		// Do the bit alignment of the EOI marker
		if (bytepos >= 0) {
			var fillbits = new BitString();
				fillbits.len = bytepos+1;
				fillbits.val = (1 << (bytepos+1)) - 1;
			writeBits ( fillbits );
		}
		byteout.writeShort ( 0xFFD9 ); //EOI
		return byteout;
	}
	
	
	function initQuantTables (sf:Int) :Void {
		var i:Int;
		
		for (i in 0...64) {
			var t:Int = int((YQT[i]*sf+50)*0.01);
			if (t < 1) {
				t = 1;
			} else if (t > 255) {
				t = 255;
			}
			YTable[ZigZag[i]] = t;
		}

		for (i in 0...64) {
			var u:Int = int((UVQT[i]*sf+50)*0.01);
			if (u < 1) {
				u = 1;
			} else if (u > 255) {
				u = 255;
			}
			UVTable[ZigZag[i]] = u;
		}
		
		var i :Int = 0;
		for (row in 0...8) {
			for (col in 0...8) {
				fdtbl_Y[i]  = (1 / (YTable [ZigZag[i]] * aasf[row] * aasf[col] * 8));
				fdtbl_UV[i] = (1 / (UVTable[ZigZag[i]] * aasf[row] * aasf[col] * 8));
				i++;
			}
		}
	}

	var YDC_HT :Vector<BitString>;
	var UVDC_HT :Vector<BitString>;
	var YAC_HT :Vector<BitString>;
	var UVAC_HT :Vector<BitString>;

	function computeHuffmanTbl (nrcodes:Vector<Int>, std_table:Vector<Int>) :Vector<BitString> {
		var codevalue:Int = 0;
		var pos_in_table:Int = 0;
		var HT = new Vector<BitString>(251, true);
		var bitString :BitString;
		for (k in 1...17) {
			for (j in 1...nrcodes[k]+1) {
				HT[std_table[pos_in_table]] = bitString = new BitString();
				bitString.val = codevalue;
				bitString.len = k;
				pos_in_table++;
				codevalue++;
			}
			codevalue<<=1;
		}
		return HT;
	}

	inline static var std_dc_luminance_nrcodes = Vector<Int>([0,0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0]);
	inline static var std_dc_luminance_values = Vector<Int>([0,1,2,3,4,5,6,7,8,9,10,11]);
	inline static var std_ac_luminance_nrcodes = Vector<Int>([0,0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,0x7d]);
	inline static var std_ac_luminance_values = Vector<Int>([0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,
																			0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,
																			0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,
																			0x23,0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,
																			0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,
																			0x17,0x18,0x19,0x1a,0x25,0x26,0x27,0x28,
																			0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,
																			0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
																			0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,
																			0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
																			0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,
																			0x7a,0x83,0x84,0x85,0x86,0x87,0x88,0x89,
																			0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,
																			0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,
																			0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,
																			0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,
																			0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,
																			0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,
																			0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,
																			0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
																			0xf9,0xfa]);

	inline static var std_dc_chrominance_nrcodes = Vector<Int>([0,0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0]);
	inline static var std_dc_chrominance_values = Vector<Int>([0,1,2,3,4,5,6,7,8,9,10,11]);
	inline static var std_ac_chrominance_nrcodes = Vector<Int>([0,0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,0x77]);
	inline static var std_ac_chrominance_values = Vector<Int>([0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,
																			0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,
																			0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,
																			0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,
																			0x15,0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,
																			0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,
																			0x27,0x28,0x29,0x2a,0x35,0x36,0x37,0x38,
																			0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,
																			0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,
																			0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,
																			0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,
																			0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,
																			0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,
																			0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,
																			0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,
																			0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,
																			0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,
																			0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,
																			0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,
																			0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
																			0xf9,0xfa
																		]);

	function initHuffmanTbl() :Void {
		YDC_HT = computeHuffmanTbl (std_dc_luminance_nrcodes, std_dc_luminance_values);
		UVDC_HT = computeHuffmanTbl (std_dc_chrominance_nrcodes, std_dc_chrominance_values);
		YAC_HT = computeHuffmanTbl (std_ac_luminance_nrcodes, std_ac_luminance_values);
		UVAC_HT = computeHuffmanTbl (std_ac_chrominance_nrcodes, std_ac_chrominance_values);
	}

	var bitcode :Vector<BitString>;
	var category :Vector<Int>;
	
	function initCategoryFloat() :Void {
		var nrlower:Int = 1;
		var nrupper:Int = 2;
		bitcode = new Vector<BitString>(65535, true);
		category = new Vector<Int>(65535, true);
		var bitString :BitString;
		
		var pos:Int;
		for (cat in 1...16) {
			//Positive numbers
			for (nr in nrlower...nrupper) {
				pos = cast (32767 + nr, Int);
				category[pos] = cat;
				bitcode[pos] = bitString = new BitString();
				bitString.len = cat;
				bitString.val = nr;
			}
			//Negative numbers
			var nrneg :Int = -(nrupper-1);
			while (nrneg <= -nrlower) {
				pos = int(32767+nrneg);
				category[pos] = cat;
				bitcode[pos] = bitString = new BitString();
				bitString.len = cat;
				bitString.val = nrupper - 1 + nrneg;
				nrneg++;
			}
			nrlower <<= 1;
			nrupper <<= 1;
		}
	}

	// IO functions

	var byteout:ByteArray;
	var bytenew:Int;
	var bytepos:Int;

	function writeBits(bs:BitString) :Void {
		var value:Int = bs.val;
		var posval:Int = bs.len-1;
		while ( posval >= 0 ) {
			if (value & uint(1 << posval) )
				bytenew |= uint(1 << bytepos);
			posval--;
			bytepos--;
			if (bytepos < 0)
			{
				if (bytenew == 0xFF)
				{
					byteout.writeByte(0xFF);
					byteout.writeByte(0);
				}
				else byteout.writeByte(bytenew);
				bytepos=7;
				bytenew=0;
			}
		}
	}

	// DCT & quantization core

	function fDCTQuant(data:Vector<Float>, fdtbl:Vector<Float>) :Vector<Int> {
		/* Pass 1: process rows. */
		var dataOff:Int=0;
		var d0:Float, d1:Float, d2:Float, d3:Float, d4:Float, d5:Float, d6:Float, d7:Float;
		
		for (i in 0...8) {
            d0 = data[dataOff];
			d1 = data[dataOff+1];
			d2 = data[dataOff+2];
			d3 = data[dataOff+3];
			d4 = data[dataOff+4];
			d5 = data[dataOff+5];
			d6 = data[dataOff+6];
			d7 = data[dataOff+7];
			
			var tmp0:Float = d0 + d7;
			var tmp7:Float = d0 - d7;
			var tmp1:Float = d1 + d6;
			var tmp6:Float = d1 - d6;
			var tmp2:Float = d2 + d5;
			var tmp5:Float = d2 - d5;
			var tmp3:Float = d3 + d4;
			var tmp4:Float = d3 - d4;

			/* Even part */
			var tmp10:Float = tmp0 + tmp3;	/* phase 2 */
			var tmp13:Float = tmp0 - tmp3;
			var tmp11:Float = tmp1 + tmp2;
			var tmp12:Float = tmp1 - tmp2;

			data[int(dataOff)] = tmp10 + tmp11; /* phase 3 */
			data[int(dataOff+4)] = tmp10 - tmp11;

			var z1:Float = (tmp12 + tmp13) * 0.707106781; /* c4 */
			data[int(dataOff+2)] = tmp13 + z1; /* phase 5 */
			data[int(dataOff+6)] = tmp13 - z1;

			/* Odd part */
			tmp10 = tmp4 + tmp5; /* phase 2 */
			tmp11 = tmp5 + tmp6;
			tmp12 = tmp6 + tmp7;

			/* The rotator is modified from fig 4-8 to avoid extra negations. */
			var z5:Float = (tmp10 - tmp12) * 0.382683433; /* c6 */
			var z2:Float = 0.541196100 * tmp10 + z5; /* c2-c6 */
			var z4:Float = 1.306562965 * tmp12 + z5; /* c2+c6 */
			var z3:Float = tmp11 * 0.707106781; /* c4 */

			var z11:Float = tmp7 + z3;	/* phase 5 */
			var z13:Float = tmp7 - z3;

			data[int(dataOff+5)] = z13 + z2;	/* phase 6 */
			data[int(dataOff+3)] = z13 - z2;
			data[int(dataOff+1)] = z11 + z4;
			data[int(dataOff+7)] = z11 - z4;

			dataOff += 8; /* advance pointer to next row */
		}

		/* Pass 2: process columns. */
		dataOff = 0;
		for (i in 0...8) {
			d0 = data[int(dataOff)];
			d1 = data[int(dataOff + 8)];
			d2 = data[int(dataOff + 16)];
			d3 = data[int(dataOff + 24)];
	        d4 = data[int(dataOff + 32)];
			d5 = data[int(dataOff + 40)];
			d6 = data[int(dataOff + 48)];
			d7 = data[int(dataOff + 56)];
			
			var tmp0p2:Float = d0 + d7;
			var tmp7p2:Float = d0 - d7;
			var tmp1p2:Float = d1 + d6;
			var tmp6p2:Float = d1 - d6;
			var tmp2p2:Float = d2 + d5;
			var tmp5p2:Float = d2 - d5;
			var tmp3p2:Float = d3 + d4;
			var tmp4p2:Float = d3 - d4;

			/* Even part */
			var tmp10p2:Float = tmp0p2 + tmp3p2;	/* phase 2 */
			var tmp13p2:Float = tmp0p2 - tmp3p2;
			var tmp11p2:Float = tmp1p2 + tmp2p2;
			var tmp12p2:Float = tmp1p2 - tmp2p2;

			data[int(dataOff)] = tmp10p2 + tmp11p2; /* phase 3 */
			data[int(dataOff+32)] = tmp10p2 - tmp11p2;

			var z1p2:Float = (tmp12p2 + tmp13p2) * 0.707106781; /* c4 */
			data[int(dataOff+16)] = tmp13p2 + z1p2; /* phase 5 */
			data[int(dataOff+48)] = tmp13p2 - z1p2;
			
			/* Odd part */
			tmp10p2 = tmp4p2 + tmp5p2; /* phase 2 */
			tmp11p2 = tmp5p2 + tmp6p2;
			tmp12p2 = tmp6p2 + tmp7p2;

			/* The rotator is modified from fig 4-8 to avoid extra negations. */
			var z5p2:Float = (tmp10p2 - tmp12p2) * 0.382683433; /* c6 */
			var z2p2:Float = 0.541196100 * tmp10p2 + z5p2; /* c2-c6 */
			var z4p2:Float = 1.306562965 * tmp12p2 + z5p2; /* c2+c6 */
			var z3p2:Float= tmp11p2 * 0.707106781; /* c4 */

			var z11p2:Float = tmp7p2 + z3p2;	/* phase 5 */
			var z13p2:Float = tmp7p2 - z3p2;

			data[int(dataOff+40)] = z13p2 + z2p2; /* phase 6 */
			data[int(dataOff+24)] = z13p2 - z2p2;
			data[int(dataOff+ 8)] = z11p2 + z4p2;
			data[int(dataOff+56)] = z11p2 - z4p2;

			dataOff++; /* advance pointer to next column */
		}

		// Quantize/descale the coefficients
		var fDCTQuant:Float;
		for (i in 0...64) {
			// Apply the quantization and scaling factor & Round to nearest integer
			fDCTQuant = data[i] * fdtbl[i];
			outputfDCTQuant[i] = (fDCTQuant > 0.0) ? cast(fDCTQuant + 0.5, Int) : cast(fDCTQuant - 0.5, Int);
		}
		return outputfDCTQuant;
	}

	// Chunk writing
	function writeAPP0() :Void {
		byteout.writeShort(0xFFE0); // marker
		byteout.writeShort(16); // length
		byteout.writeByte(0x4A); // J
		byteout.writeByte(0x46); // F
		byteout.writeByte(0x49); // I
		byteout.writeByte(0x46); // F
		byteout.writeByte(0); // = "JFIF",'\0'
		byteout.writeByte(1); // versionhi
		byteout.writeByte(1); // versionlo
		byteout.writeByte(0); // xyunits
		byteout.writeShort(1); // xdensity
		byteout.writeShort(1); // ydensity
		byteout.writeByte(0); // thumbnwidth
		byteout.writeByte(0); // thumbnheight
	}

	function writeSOF0(width:Int, height:Int) :Void {
		byteout.writeShort(0xFFC0); // marker
		byteout.writeShort(17);   // length, truecolor YUV JPG
		byteout.writeByte(8);    // precision
		byteout.writeShort(height);
		byteout.writeShort(width);
		byteout.writeByte(3);    // nrofcomponents
		byteout.writeByte(1);    // IdY
		byteout.writeByte(0x11); // HVY
		byteout.writeByte(0);    // QTY
		byteout.writeByte(2);    // IdU
		byteout.writeByte(0x11); // HVU
		byteout.writeByte(1);    // QTU
		byteout.writeByte(3);    // IdV
		byteout.writeByte(0x11); // HVV
		byteout.writeByte(1);    // QTV
	}

	function writeDQT() :Void {
		byteout.writeShort(0xFFDB); // marker
		byteout.writeShort(132);	   // length
		byteout.writeByte(0);
		
		for (i in 0...64)
			byteout.writeByte(YTable[i]);
			
		byteout.writeByte(1);
		
		for (i in 0...64)
			byteout.writeByte(UVTable[i]);
	}

	function writeDHT() :Void {
		byteout.writeShort(0xFFC4); // marker
		byteout.writeShort(0x01A2); // length

		byteout.writeByte(0); // HTYDCinfo
		for (i in 0...16) byteout.writeByte(std_dc_luminance_nrcodes[i+1]);
		for (i in 0...12) byteout.writeByte(std_dc_luminance_values[i]);

		byteout.writeByte(0x10); // HTYACinfo
		for (i in 0...16) byteout.writeByte(std_ac_luminance_nrcodes[i+1]);
		for (i in 0...162) byteout.writeByte(std_ac_luminance_values[i]);

		byteout.writeByte(1); // HTUDCinfo
		for (i in 0...16) byteout.writeByte(std_dc_chrominance_nrcodes[i+1]);
		for (i in 0...12) byteout.writeByte(std_dc_chrominance_values[i]);

		byteout.writeByte(0x11); // HTUACinfo
		for (i in 0...16) byteout.writeByte(std_ac_chrominance_nrcodes[i+1]);
		for (i in 0...162) byteout.writeByte(std_ac_chrominance_values[i]);
	}

	function writeSOS() :Void {
		byteout.writeShort(0xFFDA); // marker
		byteout.writeShort(12); // length
		byteout.writeByte(3); // nrofcomponents
		byteout.writeByte(1); // IdY
		byteout.writeByte(0); // HTY
		byteout.writeByte(2); // IdU
		byteout.writeByte(0x11); // HTU
		byteout.writeByte(3); // IdV
		byteout.writeByte(0x11); // HTV
		byteout.writeByte(0); // Ss
		byteout.writeByte(0x3f); // Se
		byteout.writeByte(0); // Bf
	}

	// Core processing
	var DU :Vector<Int>;

	function processDU(CDU:Vector<Float>, fdtbl:Vector<Float>, DC:Float, HTDC:Vector<BitString>, HTAC:Vector<BitString>):Float {
		var EOB :BitString = HTAC[0x00];
		var M16zeroes :BitString = HTAC[0xF0];
		var pos:Int;
		
		var DU_DCT:Vector<Int> = fDCTQuant(CDU, fdtbl);
		//ZigZag reorder
		for (i in 0...64) DU[ZigZag[j]]=DU_DCT[j];
		
		var Diff:Int = DU[0] - DC;
		DC = DU[0];
		//Encode DC
		if (Diff == 0) {
			writeBits(HTDC[0]); // Diff might be 0
		}
		else {
			pos = cast (32767 + Diff, Int);
			writeBits(HTDC[category[pos]]);
			writeBits(bitcode[pos]);
		}
		//Encode ACs
		var end0pos:Int = 63;
		while (end0pos>0 && DU[end0pos]==0) end0pos--;
		//for (; (end0pos>0)&&(DU[end0pos]==0); end0pos--) {};
		//end0pos = first element in reverse order !=0
		if (end0pos == 0) {
			writeBits ( EOB );
			return DC;
		}
		var i:Int = 1;
		var lng:Int;
		while ( i <= end0pos ) {
			var startpos:Int = i;
			while (DU[i]==0 && i<=end0pos) i++;
			//for (; (DU[i]==0) && (i<=end0pos); ++i) {}
			var nrzeroes:Int = i - startpos;
			if (nrzeroes >= 16) {
				lng = nrzeroes>>4;
				//for (var nrmarker:Int=1; nrmarker <= lng; ++nrmarker)
				for (nrmarker in 0...lng)
					writeBits ( M16zeroes );
				nrzeroes = cast(nrzeroes&0xF, Int);
			}
			pos = 32767 + DU[i];
			writeBits ( HTAC[int((nrzeroes<<4) + category[pos])] );
			writeBits ( bitcode[pos] );
			i++;
		}
		if (end0pos != 63) writeBits(EOB);
		
		return DC;
	}
	
	var YDU :Vector<Float>;
	var UDU :Vector<Float>;
	var VDU :Vector<Float>;
	
	function RGB2YUV (img:BitmapData, xpos:Int, ypos:Int) :Void {
		var pos:Int=0;
		for (y in 0...8) {
			for (x in 0...8) {
				var P:UInt = img.getPixel32 (xpos+x, ypos+y);
				var R:Int = (P>>16)&0xFF;
				var G:Int = (P>> 8)&0xFF;
				var B:Int = (P    )&0xFF;
                YDU[int(pos)] = ((( 0.29900)*R + ( 0.58700)*G + ( 0.11400)*B)) - 0x80;
				UDU[int(pos)] = (((-0.16874)*R + (-0.33126)*G + ( 0.50000)*B));
				VDU[int(pos)] = ((( 0.50000)*R + (-0.41869)*G + (-0.08131)*B));
				++pos;
			}
		}
	}
}