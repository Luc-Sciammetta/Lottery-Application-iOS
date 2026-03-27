import Foundation
import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage? //bind to the parent view's state
    @Environment(\.presentationMode) var presentationMode //dismiss the view when done
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let cameraPicker = UIImagePickerController() //creates the camera picker
        cameraPicker.delegate = context.coordinator //set the coordinator as the delegate
        cameraPicker.sourceType = .camera //set the source to the camera
        return cameraPicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        //no updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init (_ parent: CameraView){
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image //pass the selected image to the parent
            }
            
            parent.presentationMode.wrappedValue.dismiss() //dismiss the camera picker
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss() //dismiss on cancel the camera
        }
    }
    
    
}
