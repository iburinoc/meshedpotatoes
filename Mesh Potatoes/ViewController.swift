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
	
	let captureSession = AVCaptureSession()
	
	var captureDevice : AVCaptureDevice?
	
	var previewLayer: AVCaptureVideoPreviewLayer?
	var videoOutput: AVCaptureVideoDataOutput?
	
	var startTime = CFAbsoluteTimeGetCurrent()
	
	let drawLayer = CALayer()
	var raster : CGImageRef?
	
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
	
	var curFrame = -1
	var frameSum = 0
	var frameNum = 0
	
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
		
		videoOutput = AVCaptureVideoDataOutput()
		videoOutput!.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
		videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)]
		if captureSession.canAddOutput(self.videoOutput) {
			captureSession.addOutput(self.videoOutput)
		} else {
			print("error: couldn't add output")
		}
		
		captureSession.startRunning()
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
			print(":(")
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
				newBit(v)
				return
			}
			if curFrame > 16 {
				height += (v << (curFrame - 16))
			} else {
				width += (v << curFrame)
			}
		case 2:
			return
		default:
			return
		}
		curFrame++
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	internal struct PixelData {
		var a:UInt8 = 255
		var r:UInt8
		var g:UInt8
		var b:UInt8
	}
	
	private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
	private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.rawValue)
	
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
			width * UInt(sizeof(PixelData)),
			rgbColorSpace,
			bitmapInfo,
			providerRef,
			nil,
			true,
			CGColorRenderingIntent.RenderingIntentDefault
		)
		return UIImage(CGImage: cgim)
	}

}

