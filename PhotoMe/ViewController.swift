//
//  ViewController.swift
//  PhotoMe
//
//  Created by N on 2016-10-27.
//  Copyright © 2016 Agaba Nkuuhe. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

	@IBOutlet weak var cameraPreviewView: CameraPreviewView!
	
	fileprivate let session = AVCaptureSession()
	fileprivate let sessionQueue = DispatchQueue(label: "com.agabankuuhe.PhotoMe")
	
	var videoDeviceInput: AVCaptureDeviceInput!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Pass through the capture session to the view so it can display the output.
		cameraPreviewView.session = session
		
		// Suspend the session queue, so nothing can happen with the session.
		sessionQueue.suspend()
		
		//Ask for permission to access the camera and microphone. Both of these are required for live photos, which you’ll add later.
		AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) {
			success in
			if !success {
				print("Come on yo, it's just a camera app, let me see you!")
				return
			}
			
			//Once permission is granted, resume the queue.
			self.sessionQueue.resume()
		}
		sessionQueue.async {
			[unowned self] in
			self.prepareCaptureSession()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		sessionQueue.async {
			self.session.startRunning()
		}
	}
	
	private func prepareCaptureSession(){
		//1
		session.beginConfiguration()
		session.sessionPreset = AVCaptureSessionPresetPhoto
		
		do {
			//2
			let videoDevice = AVCaptureDevice.defaultDevice(
				withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera,
				mediaType: AVMediaTypeVideo,
				position: .front)
			
			//3
			let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
			
			//4
			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput
				
				//5
				DispatchQueue.main.async {
					self.cameraPreviewView.cameraPreviewLayer.connection.videoOrientation = .portrait
				}
			} else {
				print("Couldn't add device to the session")
				return
			}
		} catch {
			print("Couldn't create video device input: \(error)")
			return
		}
		// 6
		session.commitConfiguration()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

