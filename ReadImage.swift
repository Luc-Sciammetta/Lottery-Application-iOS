import Vision
import UIKit
import SwiftUI

func recognizeText(from image: UIImage, completion: @escaping ([String]) -> Void){
    guard let cgImage = image.cgImage else {
        completion([])
        return
    }
    
    let request = VNRecognizeTextRequest { request, error in
        guard error == nil,
              let observations = request.results as? [VNRecognizedTextObservation] else {
            completion([])
            return
        }
        
        let lines = observations
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .compactMap { $0.topCandidates(1).first?.string }
        
        completion(lines)
    }
    
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        try? handler.perform([request])
    }
}
