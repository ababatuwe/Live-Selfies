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
	
	func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		
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
	
	func capture(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
		photoCaptureBegins?()
	}
	
	func capture(_ captureOutput: AVCapturePhotoOutput, didCapturePhotoForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
		photoCaptured?()
	}
}
