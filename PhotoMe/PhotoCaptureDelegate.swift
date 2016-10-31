//
//  PhotoCaptureDelegate.swift
//  PhotoMe
//
//  Created by N on 2016-10-27.
//  Copyright © 2016 Agaba Nkuuhe. All rights reserved.
//

import AVFoundation
import Photos

class PhotoCaptureDelegate: NSObject {
	
	var photoCaptureBegins: (() ->())? = .none
	var photoCaptured: (()->())? = .none
	var thumbnailCaptured: ((UIImage?)->())? = .none
	var capturingLivePhoto: ((Bool)->())? = .none // closure which the view controller will use to update the UI to indicate if live photo capture is happening
	
	fileprivate var livePhotoMovieURL: URL? = .none // store the URL of the movie file that accompanies the live photo.
	fileprivate let completionHandler: (PhotoCaptureDelegate, PHAsset)-> ()
	
	fileprivate var photoData: Data? = .none
	
	init(completionHandler: @escaping (PhotoCaptureDelegate, PHAsset)-> ()) {
		self.completionHandler = completionHandler
	}
	
	fileprivate func cleanup(asset: PHAsset? = .none){
		completionHandler(self, asset!)
	}
}

extension PhotoCaptureDelegate: AVCapturePhotoCaptureDelegate {
	//Process data completed
	
	func capture(_ captureOutput: AVCapturePhotoOutput,
	             didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
	             previewPhotoSampleBuffer: CMSampleBuffer?,
	             resolvedSettings: AVCaptureResolvedPhotoSettings,
	             bracketSettings: AVCaptureBracketedStillImageSettings?,
	             error: Error?) {
		
		guard let photoSampleBuffer = photoSampleBuffer else {
			print("Error capturing photo \(error)")
			return
		}
		
		photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
		
		if let thumbnailCaptured = thumbnailCaptured, let previewPhotoSampleBuffer = previewPhotoSampleBuffer, let cvImageBuffer = CMSampleBufferGetImageBuffer(previewPhotoSampleBuffer) {
			
			let ciThumbnail = CIImage(cvImageBuffer: cvImageBuffer)
			let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
			let thumbnail = UIImage(cgImage: context.createCGImage(ciThumbnail, from: ciThumbnail.extent)!, scale: 2.0,	orientation: .right)
			
			thumbnailCaptured(thumbnail)
		}
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput,
	             didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings,
	             error: Error?) {
		
		guard error == nil, let photoData = photoData else {
			print("Error \(error) or no data")
			return
		}
		
		PHPhotoLibrary.requestAuthorization {
			[unowned self]
			(status) in
			
			guard status == .authorized else {
				print("Need authorization to write to the photo library")
				self.cleanup()
				return
			}
			
			var assetIdentifier: String?
			
			PHPhotoLibrary.shared().performChanges({ 
				let creationRequest = PHAssetCreationRequest.forAsset()
				let placeholder = creationRequest.placeholderForCreatedAsset
				
				creationRequest.addResource(with: .photo, data: photoData, options: .none)
				
				// bundles in the video data with the photo data you’re already sending, making your photo live. Setting the shouldMoveFile option means that the video file will be removed from the temporary directory for you
				if let livePhotoMovieURL = self.livePhotoMovieURL {
					let movieResourceOptions = PHAssetResourceCreationOptions()
					movieResourceOptions.shouldMoveFile = true
					creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoMovieURL, options: movieResourceOptions)
				}
				
				assetIdentifier = placeholder?.localIdentifier
				
				}, completionHandler: {
					success, error in
					
					if let error = error {
						print("Error saving photo to user library: \(error)")
					}
					var asset: PHAsset? = .none
					
					if let assetIdentifier = assetIdentifier {
						asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: .none).firstObject
					}
					self.cleanup(asset: asset)
			})
		}
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput,
	             willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
		photoCaptureBegins?()
		if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
			capturingLivePhoto?(true)
		}
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
		photoCaptured?()
	}
	
	// called when the video capture is complete
	func capture(_ captureOutput: AVCapturePhotoOutput,
	             didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
	             resolvedSettings: AVCaptureResolvedPhotoSettings) {
		capturingLivePhoto?(false)
	}
	
	// called when the processing of the video capture is complete
	func capture(_ captureOutput: AVCapturePhotoOutput,
	             didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
	             duration: CMTime,
	             photoDisplay photoDisplayTime: CMTime,
	             resolvedSettings: AVCaptureResolvedPhotoSettings,
	             error: Error?) {
		if let error = error {
			print("Error creating live photo video: \(error)")
		}
		livePhotoMovieURL = outputFileURL
	}
}
