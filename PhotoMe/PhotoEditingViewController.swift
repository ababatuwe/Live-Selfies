//
//  PhotoEditingViewController.swift
//  PhotoMe
//
//  Created by N on 2016-10-31.
//  Copyright © 2016 Agaba Nkuuhe. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

class PhotoEditingViewController: UIViewController {
	
	@IBOutlet weak var livePhotoView: PHLivePhotoView!
	
	@IBAction func handleComicifyTapped(_ sender: UIButton){
		comicifyImage()
	}
	
	@IBAction func handleDoneTapped(_ sender: UIButton){
		
	}
	
	var asset: PHAsset? // Holds the asset being edited

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		if let asset = asset {
			PHImageManager.default().requestLivePhoto(for: asset,
												   targetSize: livePhotoView.bounds.size,
												   contentMode: .aspectFill,
												   options: .none, resultHandler: { (livePhoto, info) in
														DispatchQueue.main.async {
															self.livePhotoView.livePhoto = livePhoto
														}
													})
		}
	}
    override func viewDidLoad() {
        super.viewDidLoad()
    }
	
	fileprivate func comicifyImage(){
		guard let asset = asset else { return }
		
		// load the asset data from the library and prepare for editing
		asset.requestContentEditingInput(with: .none) {
			[unowned self] (input, info) in
			guard let input = input else {
				print("error: \(info)")
				return
			}
			
			// Check that the photo is actually a live photo
			guard input.mediaType == .image, input.mediaSubtypes.contains(.photoLive) else {
				print("This isn't a live photo")
				return
			}
			
			// Create a live photo editing context & assign it a frame processor.
			let editingContext = PHLivePhotoEditingContext(livePhotoEditingInput: input)
			
			//Closure that is applied to each PHLivePhotoFrame in the live photo, including the full resolition image.
			// You can identify how far through the video you are, or if you're editing the full image, by inspecting the frame object.
			// The closure must return a CIImage - returning nil at any point aborts the edit
			editingContext?.frameProcessor = {
				(frame, error) in
				
				// Apply the same CIFilter to each frame, which is the Comic Effect filter.
				// You could put any combination of core image filters in here, or perform any other manipulations you can think of.
				var image = frame.image
				image = image.applyingFilter("CIComicEffect", withInputParameters: .none)
				return image
			}
			
			// This call creates preview-level renderings of the live photo. When it's done, it will update the live photo view.
			editingContext?.prepareLivePhotoForPlayback(withTargetSize: self.livePhotoView.bounds.size, options: .none) {
				(livePhoto, error) in
				guard let livePhoto = livePhoto else {
					print("Preparation error: \(error)")
					return
				}
				self.livePhotoView.livePhoto = livePhoto
				
				// output acts as a destination for the editing operation. For live photos, it's configured using the content editing input object requested earlier
				let output = PHContentEditingOutput(contentEditingInput: input)
				
				// adjustmentData? must be set otherwise the photo cannot be saved. This info allows the edits to be reverted
				output.adjustmentData = PHAdjustmentData(formatIdentifier: "PhotoMe", formatVersion: "1.0", data: "Comicify".data(using: .utf8)!)
				
				
				// saveLivePhoto reruns the editing context's frame processor, but for the full-size video and still.
				editingContext?.saveLivePhoto(to: output, options: nil){
					success, error in
					if !success {
						print("Rendering error \(error)")
						return
					}
					
					// Once rendering is complete Save the changes to the photo library in the standard manner by creating requests inside a photo Library's changes block.
					PHPhotoLibrary.shared().performChanges({ 
						let request = PHAssetChangeRequest(for: asset)
						request.contentEditingOutput = output
						}, completionHandler: { (success, error) in
							print("Saved \(success), error \(error)")
					})
				}
			}
		}
	}
	

}
