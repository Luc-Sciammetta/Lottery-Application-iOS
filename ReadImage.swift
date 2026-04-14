import Vision
import UIKit
import SwiftUI

func recognizeText(from image: UIImage, completion: @escaping ([String]) -> Void){
    guard let cgImage = image.cgImage else { //converts the image into a cgImage (needed for Vision framework). If there is no image, returns
        completion([])
        return
    }
    
    let request = VNRecognizeTextRequest { request, error in //creates a request to recognize the text
        //code inside the {} is what happens AFTER the vision finishes
        guard error == nil, //if we have an error
              let observations = request.results as? [VNRecognizedTextObservation] else {
            completion([])
            return
        }

        //we found text!
        let lines = observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y } //sort the lines from top to bottom
            .compactMap { $0.topCandidates(1).first?.string } //takes out the text from the observations
        
        completion(lines) //hands the list back to whoever asked
    }
    
    //settings for the vision request
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false //no auto correction on spelling errors
    
    //gives the image to the Vision, and executes the request
    //this runs in the background (asynchrounously) so the app doesn't freeze while thinking
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        try? handler.perform([request])
    }
}

/// Async version of recognizeText that can be awaited
func recognizeText(from image: UIImage) async -> [String] {
    await withCheckedContinuation { continuation in
        recognizeText(from: image) { lines in
            continuation.resume(returning: lines)
        }
    }
}
