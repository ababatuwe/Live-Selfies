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
	@IBOutlet weak var shutterButton: UIButton!
	
	fileprivate let session = AVCaptureSession()
	fileprivate let sessionQueue = DispatchQueue(label: "com.agabankuuhe.PhotoMe")
	fileprivate let photoOutput = AVCapturePhotoOutput()
	
	fileprivate var photoCaptureDelegates = [Int64: PhotoCaptureDelegate]()
	
	@IBAction func handleShutterButtonTap(_ sender: UIButton){
		capturePhoto()
	}
	
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
		
		if session.canAddOutput(photoOutput){
			session.addOutput(photoOutput)
			photoOutput.isHighResolutionCaptureEnabled = true
		} else {
			print("Unable to add photo output")
			return
		}
		// 6
		session.commitConfiguration()
	}

}

extension ViewController {
	fileprivate func capturePhoto() {
		// Output connection needs to know what orientation the camera is in.
		let cameraPreviewLayerOrientation = cameraPreviewView.cameraPreviewLayer.connection.videoOrientation
		
		// connection 'is a' AVCaptureConection:
		// An AVCaptureConnection represents a stream of media coming from one of the inputs, through the session, to the output. Pass the orientation to the connection.
		sessionQueue.async {
			if let connection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo) {
				connection.videoOrientation = cameraPreviewLayerOrientation
			}
			// Configure photo settings for JPEG capture.
			let photoSettings = AVCapturePhotoSettings()
			photoSettings.flashMode = .off
			photoSettings.isHighResolutionPhotoEnabled = true
			
			//Create the delegate and, in a cruel twist of fate, tell it to remove itself from memory when it’s finished.
			let uniqueID = photoSettings.uniqueID
			let photoCaptureDelegate = PhotoCaptureDelegate(){
				[unowned self]
				(photoCaptureDelegate, asset) in
				
				self.sessionQueue.async {
					[unowned self] in
					self.photoCaptureDelegates[uniqueID] = .none
				}
			}
			
			// Store the delegate in the dictionary
			self.photoCaptureDelegates[uniqueID] = photoCaptureDelegate
			
			// Start the capture process, passing in the delegate and the settings object.
			self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
		}
	}
}

