/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Actionscript 3 barcode decoding library.
 *
 * The Initial Developer of the Original Code is
 * webqem pty ltd. http://www.webqem.com/.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Mike Shaw <mikes@webqem.com>
 * ***** END LICENSE BLOCK ***** */

package com.webqem.barcode.readers {

	import com.webqem.barcode.core.AbstractDecoder;
	import com.webqem.barcode.core.IBarcodeReader;
	import com.webqem.barcode.core.IEncodedBarcodeData;
	import com.webqem.barcode.core.InputIsNullError;

	import flash.display.BitmapData;
	import flash.filters.ColorMatrixFilter;
	import flash.filters.ConvolutionFilter;
	import flash.geom.Point;
	import flash.utils.Dictionary;
	import flash.utils.getTimer;

	public class BitmapReader implements IBarcodeReader {

		private static const VERTICAL_INTERVAL:uint = 20;
		private static const HORIZONTAL_INTERVAL:uint = 20;

		private var _input:BitmapData;
		private var _encodedBarcodeData:OneDimEncodedData;

		private var barcodeDecoder:AbstractDecoder;

		private var pixelRowsIdx:Dictionary = new Dictionary();
		private var	pixelRows:Array = new Array();
		private var	indexes:Array = new Array();

		// greyscale matrix
		private var greyscaleArr:Array = [0.3, 0.59, 0.11, 0, 0,
										  0.3, 0.59, 0.11, 0, 0,
										  0.3, 0.59, 0.11, 0, 0,
										  0, 0, 0, 1, 0];
		private var greyscaleFilter:ColorMatrixFilter = new ColorMatrixFilter(greyscaleArr);

		// sharpen matrix
		private var sharpenFilter:ConvolutionFilter = new ConvolutionFilter(3, 3, [0, -1, 0, -1, 15, -1, 0, -1, 0], 9);

		public function BitmapReader(barcodeDecoder:AbstractDecoder = null) {
			this.barcodeDecoder = barcodeDecoder;
		}

		public function set input(value:Object):void {
			_input = value as BitmapData;
			readInput();
		}

		[Bindable]
		public function get encodedBarcodeData():IEncodedBarcodeData {
			return _encodedBarcodeData;
		}

		private function set encodedBarcodeData(value:IEncodedBarcodeData):void {
			_encodedBarcodeData = value as OneDimEncodedData;
		}

		public function readInput(input:Object = null):IEncodedBarcodeData {
			if (input) {
				_input = input as BitmapData;
			}

			if (! _input) {
				throw new InputIsNullError();
			}

			scanPixels();

			return encodedBarcodeData;
		}

		private function scanPixels():void {
			var startTime:int = getTimer();

			var scanFrame:BitmapData = _input.clone();

			scanFrame.applyFilter(scanFrame, scanFrame.rect, new Point(0, 0), sharpenFilter);
			scanFrame.applyFilter(scanFrame, scanFrame.rect, new Point(0, 0), greyscaleFilter);

			pixelRowsIdx = new Dictionary();
			pixelRows = new Array();
			indexes = new Array();

			for (var c:Number = 0xf; c <= 0xff; c += 0xf) {
				var threshold:Number = new Number(c << 16 | c << 8 | c);
				var x:uint = 0;
				var y:uint = 0;

				// Scan Horizontally
				for (y = 0; y <= scanFrame.height; y += Math.round(scanFrame.height / VERTICAL_INTERVAL)) {

					var row:Array = new Array(scanFrame.width);
					var startX:uint = scanFrame.width;
					var endX:uint = 0;

					for (x = 0; x < scanFrame.width; x++) {
						if (scanFrame.getPixel(x,y) <= threshold) {
							if (x < startX) {
								startX = x;
							}
							if (x > endX) {
								endX = x;
							}
							row[x] = 1;
						}
						else {
							row[x] = 0;
						}
					}
					addDataToResult(row, startX, endX);
					// check if upside down.
					row = row.slice();
					row.reverse();
					addDataToResult(row, row.length - endX, row.length - startX);
				}

				// Scan Vertically
				for (x = 0; x <= scanFrame.width; x += Math.round(scanFrame.width / HORIZONTAL_INTERVAL)) {

					var col:Array = new Array(scanFrame.height);
					var startY:Number = scanFrame.height;
					var endY:Number = 0;

					for (y = 0; y < scanFrame.height; y++) {
						if (scanFrame.getPixel(x,y) <= threshold) {
							if (y < startY) {
								startY = y;
							}
							if (y > endY) {
								endY = y;
							}
							col[y] = 1;
						}
						else {
							col[y] = 0;
						}
					}
					addDataToResult(col, startY, endY);
					// check if upside down.
					col = col.slice();
					col.reverse();
					addDataToResult(col, col.length - endY, col.length - startY);
				}
			}
			pixelRowsIdx = null;

			encodedBarcodeData = new OneDimEncodedData(pixelRows, indexes);
			trace("scanPixels", getTimer() - startTime);
		}

		private function addDataToResult(bits:Array, start:uint, end:uint):void {
			if (!pixelRowsIdx[bits.toString()]) {
				if (barcodeDecoder) {
					if (barcodeDecoder.isValidEncoding(new OneDimEncodedData(bits, [start, end]))) {
						pixelRowsIdx[bits.toString()] = bits;
						pixelRows.push(bits);
						indexes.push({start: start, end: end});
					}
				}
				else {
					pixelRowsIdx[bits.toString()] = bits;
					pixelRows.push(bits);
					indexes.push({start: start, end: end});
				}
			}
		}


	}
}