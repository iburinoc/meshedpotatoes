//
//  ViewController.swift
//  Mesh Potatoes
//
//  Created by Sean Purcell on 2015-10-04.
//  Copyright (c) 2015 Sean Purcell. All rights reserved.
//

import UIKit
import AVFoundation
import CoreFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
	
	internal struct PixelData {
		var a:UInt8 = 255
		var r:UInt8
		var g:UInt8
		var b:UInt8
	}
	
	let captureSession = AVCaptureSession()
	
	var captureDevice : AVCaptureDevice?
	
	var previewLayer: AVCaptureVideoPreviewLayer?
	var videoOutput: AVCaptureVideoDataOutput?
	
	var startTime = CFAbsoluteTimeGetCurrent()
	
	let drawLayer = CALayer()
	
	let d = Drawer()
	
	let bitlen = 0.2
	
	// 0: waiting to receive starting indicator
	// 1: getting width and height
	// 2: getting info
	var mode = 0

	var submode = 0

	var prev = false
	var onStart: Double = 0
	var offStart: Double = 0
	
	var prestartSum: Int64 = 0
	var prestartCount: Int64 = 0
	
	var width: Int = 0
	var height: Int = 0
	
	var curFrame = 0
	var frameSum = 0
	var frameNum = 0
	
	var curCol: Int = 0
	
	var imgView: UIImageView?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		captureSession.sessionPreset = AVCaptureSessionPresetLow
		
		let devices = AVCaptureDevice.devices()
		print(devices)
		
		for device in devices {
			if (device.hasMediaType(AVMediaTypeVideo)) {
				if(device.position == AVCaptureDevicePosition.Back) {
					captureDevice = device as? AVCaptureDevice
				}
			}
		}
		
		if captureDevice != nil {
			beginSession()
		}
	}
	
	func beginSession() {
		do {
			try captureDevice?.lockForConfiguration()
			let activeFormat = captureDevice?.activeFormat
			//print("\(CMTimeGetSeconds(activeFormat!.minExposureDuration)) \(CMTimeGetSeconds(activeFormat!.maxExposureDuration))")
			print("\(CMTimeGetSeconds(CMTimeMake(1, 100)))")
			let iso:Float = (activeFormat!.minISO + activeFormat!.maxISO) / 2
			captureDevice?.setExposureModeCustomWithDuration(CMTimeMake(1, 100), ISO: iso) { (time:CMTime) -> Void in
			}
			captureDevice?.unlockForConfiguration()
		} catch {
			print("Couldn't set config")
		}
		do {
			try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
		} catch {
			print("failed to add input to capture session")
		}
		
		previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		self.view.layer.addSublayer(previewLayer!)
		previewLayer?.frame = self.view.layer.frame
		
		imgView = UIImageView()
		self.view.addSubview(d)
		imgView!.frame = self.view.frame
		d.frame = self.view.frame
		
		videoOutput = AVCaptureVideoDataOutput()
		videoOutput!.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
		videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
		if captureSession.canAddOutput(self.videoOutput) {
			captureSession.addOutput(self.videoOutput)
		} else {
			print("error: couldn't add output")
		}
		
		captureSession.startRunning()
//		mode = 1
		/*bitset(bitlen * 3, v: 0)
		bitset(bitlen * 1, v: 1)
		bitset(bitlen * 15, v: 0)
		bitset(bitlen * 1, v: 1)
		bitset(bitlen * 12, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*24, v: 0)
		bitset(bitlen*24, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*24, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*18, v: 1)
		bitset(bitlen*36, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*25, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*25, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*25, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*1, v: 0)
		bitset(bitlen*1, v: 1)
		bitset(bitlen*6, v: 0)
		bitset(bitlen*12, v: 1)
		bitset(bitlen*36, v: 0)
		bitset(bitlen*6, v: 1)*/
	}

	func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
		let pixelBuffer : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
		let width = CVPixelBufferGetWidth(pixelBuffer)
		let height = CVPixelBufferGetHeight(pixelBuffer)
		
		CVPixelBufferLockBaseAddress(pixelBuffer, 0)
		let ptr = UnsafePointer<UInt8>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0))
		let rowWidth = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
		
		var sum = 0
		
//		for i in (width/2 - 10)...(width/2 + 10) {
//			for j in (height/2 - 10)...(height/2 + 10) {
		for i in 0...width {
			for j in 0...height {
				sum += Int(ptr[i * 4 + 0 + j * rowWidth])
				sum += Int(ptr[i * 4 + 1 + j * rowWidth])
				sum += Int(ptr[i * 4 + 2 + j * rowWidth])
			}
		}

		CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
		
		receivedData(sum)
	}
	
	func receivedData(sum : Int) {
		let time = CFAbsoluteTimeGetCurrent() - startTime
		//print("\(time) \(sum)")
		switch mode {
		case 0:
			if (Double(Int64(sum) * prestartCount) > 2 * Double(prestartSum) && time > 5) {
				print("ON \(time)")
				if submode == 0 {
					if !prev {
						onStart = time
					} else {
						print("\(onStart - time)")
						if time - onStart > bitlen * 7 {
							submode = 1
						}
					}
				}
				prev = true
			} else {
				print("OFF \(time)")
				if submode == 0 {
					prestartSum += sum
					prestartCount++
				}
				if submode == 1 {
					if prev {
						offStart = time
					} else {
						if time - offStart > bitlen * 7 {
							mode = 1
							startTime = startTime + time
							offStart = bitlen
							onStart = bitlen
							curFrame = 0
						}
					}
				}
				prev = false
			}
		case 1, 2:
			var bit: Int
			if (Double(Int64(sum) * prestartCount) > 2 * Double(prestartSum)) {
				bit = 1
				if !prev {
										print("\(time) \(offStart)")
					bitset((time - offStart), v: 0)
					onStart = time
				}
				prev = true
			} else {
				bit = 0
				if prev {
					print("\(time) \(onStart)")
					bitset((time - onStart), v: 1)
					offStart = time
				}
				prev = false
			}
		default:
			mode = 3
		}
	}
	
	func bitset(a: Double, v: Int) {
		let len = Int(round(a / bitlen))
		print("\(len) bits of \(v)")
		for _ in 1...len {
			newBit(v)
		}
	}
	
	func newBit(v: Int) {
		switch(mode) {
		case 1:
			if(curFrame >= 32) {
				mode = 2
				print("\(width) \(height)")
				d.width = width
				d.height = height
				let blank = PixelData(a: 0, r: 0, g: 0, b: 0)
				d.raster = [PixelData](count: Int(width * height), repeatedValue: blank)
				newBit(v)
				return
			}
			if curFrame > 16 {
				height += (v << (curFrame - 16))
			} else {
				width += (v << curFrame)
			}
		case 2:
			curCol += (v << (5 - ((curFrame - 32) % 6)))
			if((curFrame - 32) % 6 == 5) {
				print("data: \(curCol)")
				let pix = PixelData(a: 255, r: (UInt8(Int(0xc0) & (curCol << 2))), g: (UInt8(Int(0xc0) & (curCol << 4))), b: (UInt8(Int(0xff) & (curCol << 6))))
				print("\(pix.r) \(pix.g) \(pix.b)")
				let idx = (curFrame - 32) / 6
				d.raster[idx] = pix
				
//				imgView!.image = imageFromARGB32Bitmap(d.raster, width: UInt(width), height: UInt(height))
//				imgView!.setNeedsDisplay()
				d.setNeedsDisplay()
				
				curCol = 0
			}
		default:
			return
		}
		curFrame++
		if curFrame == width * height * 6 + 32 {
			mode = 3
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
	private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
	
	func imageFromARGB32Bitmap(pixels:[PixelData], width:UInt, height:UInt)->UIImage {
		let bitsPerComponent:UInt = 8
		let bitsPerPixel:UInt = 32
		
		assert(pixels.count == Int(width * height))
		
		var data = pixels // Copy to mutable []
		let providerRef = CGDataProviderCreateWithCFData(
			NSData(bytes: &data, length: data.count * sizeof(PixelData))
		)
		
		let cgim = CGImageCreate(
			Int(width),
			Int(height),
			Int(bitsPerComponent),
			Int(bitsPerPixel),
			Int(width) * Int(sizeof(PixelData)),
			rgbColorSpace,
			bitmapInfo,
			providerRef,
			nil,
			true,
			CGColorRenderingIntent.RenderingIntentDefault
		)
		return UIImage(CGImage: cgim!)
	}
	
	internal class Drawer : UIView {
		var raster: [PixelData] = [PixelData](count: 0, repeatedValue: PixelData(a: 0, r: 0, g: 0, b: 0))
		var width: Int = 0
		var height: Int = 0
		override func drawRect(rect: CGRect) {
			if width == 0 {
				return
			}
			let context = UIGraphicsGetCurrentContext()
			let colorSpace = CGColorSpaceCreateDeviceRGB()
			CGContextSetFillColorSpace(context, colorSpace)
			CGContextSetFillColorWithColor(context, col(PixelData(a: 255, r: 255, g: 0, b: 0)))
			//CGContextFillRect(context, self.bounds)
			var ratio = min(Int(self.bounds.width) / width, Int(self.bounds.height) / height)
			for i in 0...(height - 1) {
				for j in 0...(width - 1) {
					CGContextSetFillColorWithColor(context, col(raster[i * width + j]))
					CGContextFillRect(context, CGRectMake(CGFloat(j * ratio), CGFloat(i * ratio), CGFloat(ratio), CGFloat(ratio)))
				}
			}
		}
		
		func col(a: PixelData) -> CGColor {
			return UIColor(red: CGFloat(Double(a.r) / Double(256)), green: CGFloat(Double(a.g) / Double(256)), blue: CGFloat(Double(a.b) / Double(256)), alpha: CGFloat(Double(a.a) / Double(256))).CGColor
		}
	}

}

