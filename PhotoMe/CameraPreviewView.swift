//
//  CameraPreviewView.swift
//  PhotoMe
//
//  Created by N on 2016-10-27.
//  Copyright © 2016 Agaba Nkuuhe. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraPreviewView: UIView {
	
	// Views have a layerClass class property which can specify a specific CALayer subclass to use for the main layer. Here, you specify AVCaptureVideoPreviewLayer.
	override static var layerClass: AnyClass {
		return AVCaptureVideoPreviewLayer.self
	}
	
	// convenience method to give you a typed property for the view’s layer.
	var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
		return layer as! AVCaptureVideoPreviewLayer
	}
	
	// The capture preview layer needs have an AVCaptureSession to show input from the camera, so this property passes through a session to the underlying layer
	var session: AVCaptureSession {
		get {
			return cameraPreviewLayer.session
		}
		set {
			cameraPreviewLayer.session = newValue
		}
	}

}
