//
//  ViewController.swift
//  PhotoMe
//
//  Created by N on 2016-10-27.
//  Copyright © 2016 Agaba Nkuuhe. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {

	@IBOutlet weak var cameraPreviewView: CameraPreviewView!
	@IBOutlet weak var shutterButton: UIButton!
	@IBOutlet weak var previewImageView: UIImageView!
	@IBOutlet weak var thumbnailSwitch: UISwitch!
	@IBOutlet weak var livePhotoSwitch: UISwitch!
	@IBOutlet weak var capturingLabel: UILabel!
	
	
	fileprivate let session = AVCaptureSession()
	fileprivate let sessionQueue = DispatchQueue(label: "com.agabankuuhe.PhotoMe")
	fileprivate let photoOutput = AVCapturePhotoOutput()
	fileprivate var currentLivePhotoCaptures: Int = 0
	fileprivate var lastAsset: PHAsset?
	
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
			
			do {
				let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
				let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
				
				if session.canAddInput(audioDeviceInput) {
					session.addInput(audioDeviceInput)
				} else {
					print("Couldn't add audio device to the session")
					return
				}
			} catch {
				print("Unable to create audio device input: \(error)")
				return
			}
			
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
			
			photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
			
			DispatchQueue.main.async {
				self.livePhotoSwitch.isEnabled = self.photoOutput.isLivePhotoCaptureSupported
			}
		} else {
			print("Unable to add photo output")
			return
		}
		// 6
		session.commitConfiguration()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let editor = segue.destination as? PhotoEditingViewController {
			editor.asset = lastAsset
		}
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
			
			
			if self.thumbnailSwitch.isOn && photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
				photoSettings.previewPhotoFormat = [
					kCVPixelBufferPixelFormatTypeKey as String: photoSettings.availablePreviewPhotoPixelFormatTypes.first!,
					kCVPixelBufferWidthKey as String : 160,
					kCVPixelBufferHeightKey as String : 160
				]
			}
			
			// additional configuration needed to support live photo capture
			// During capture the video file will be recorded into this unique name in the temporary directory.
			if self.livePhotoSwitch.isOn {
				let movieFileName = UUID().uuidString
				let moviePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(movieFileName).mov")
				photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: moviePath)
				
			}
			// Create the delegate and, in a cruel twist of fate, tell it to remove itself from memory when it’s finished.
			let uniqueID = photoSettings.uniqueID
			let photoCaptureDelegate = PhotoCaptureDelegate(){
				[unowned self]
				(photoCaptureDelegate, asset) in
				
				self.sessionQueue.async {
					[unowned self] in
					self.photoCaptureDelegates[uniqueID] = .none
					self.lastAsset = asset
				}
			}
			
			photoCaptureDelegate.thumbnailCaptured = {[unowned self] image in
				DispatchQueue.main.async {
					self.previewImageView.image = image
				}
			}
			
			// When the capture begins, you blank out and fade back in to give a shutter effect and disable the shutter button.
			photoCaptureDelegate.photoCaptureBegins = { [unowned self] in
				DispatchQueue.main.async {
					self.shutterButton.isEnabled = false
					self.cameraPreviewView.cameraPreviewLayer.opacity = 0
					UIView.animate(withDuration: 0.2) {
						self.cameraPreviewView.cameraPreviewLayer.opacity = 1
					}
				}
			}
			
			// When the capture is complete, the shutter button is enabled again.
			
			photoCaptureDelegate.photoCaptured = { [unowned self] in
				DispatchQueue.main.async {
					self.shutterButton.isEnabled = true
				}
			}
			
			// Live photo UI updates
			photoCaptureDelegate.capturingLivePhoto = { currentlyCapturing in
				DispatchQueue.main.async {
					[unowned self] in
					self.currentLivePhotoCaptures += currentlyCapturing ? 1 : -1
					UIView.animate(withDuration: 0.2) {
						self.capturingLabel.isHidden = (self.currentLivePhotoCaptures == 0)
					}
				}
			}
			
			// Store the delegate in the dictionary
			self.photoCaptureDelegates[uniqueID] = photoCaptureDelegate
			
			// Start the capture process, passing in the delegate and the settings object.
			self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
		}
	}
}

