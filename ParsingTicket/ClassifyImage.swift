import UIKit
import Vision
import CoreML

func classifyImage(image: UIImage) -> String {
    //makes an instance of the model
    //wraps the model in a VNCoreMLModel, which is the format Vision needs to run classication requests
    guard let mlModel = try? LotteryTicketModel(configuration: MLModelConfiguration()),
          let model = try? VNCoreMLModel(for: mlModel.model) else {
        return "Model not available" //if we get nil
    }
    
    var result = "Unknown"
    
    //create the classification request and what to do when the request is run
    let request = VNCoreMLRequest(model: model) { request, error in
        //casts the raw results into a nice 'class + confidence' array
        guard let results = request.results as? [VNClassificationObservation],
              let top = results.first else { return }
        
        //gets the top result
        result = top.identifier
        for value in results{
            print("\(value.identifier): \(value.confidence)")
        }
    }
    
    request.imageCropAndScaleOption = .scaleFill
    
    let renderer = UIGraphicsImageRenderer(size: image.size)
    let rgbImage = renderer.image { _ in
        image.draw(at: .zero)
    }
    
    //run the request on the image
    //this runs synchronusly, so this does nto run in the background
    guard let cgImage = rgbImage.cgImage else { return "Image not available" }
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try? handler.perform([request])
    
    return result
}
