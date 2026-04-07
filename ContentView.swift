import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? //holds the selected photo from the image library
    @State private var selectedImage: UIImage? //holds the loaded image from the image library
    @State private var showingCamera = false
    
    @Environment(\.modelContext) private var context //context for saving the lottery data
    
    var body: some View {
        VStack {
            //display the selected image/placeholder
            
            if let selectedImage = selectedImage{ //if this ever gets changed to have an image, it will display it
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            }else{
                Text("No Image Selected")
                    .foregroundStyle(Color.gray) //changes the color of the text
                    .padding()
            }
            
            Button(action: {
                showingCamera = true //show the camera view
            }){
                Text("Take Photo")
                    .padding()
                    .frame(maxWidth: 150)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .sheet(isPresented: $showingCamera){
                CameraView(image: $selectedImage)
            }
            
            //photo picker button
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()){ //binds the user's chosen phot with the selectedItem variable so it updates when a photo is picked. Makes sures it only shows photos and to use the shared photo library.
                Text("Upload Image") //information on how the button looks
                    .padding()
                    .frame(maxWidth: 150)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .onChange(of: selectedItem) { _, newItem in //watches the selected item until it changes to a value. newItem contains the image
                if let newItem = newItem { //gets the image from the line above if its not equal to nil
                    Task { //creates an asynchromous task. This is required
                        
                        //loads the raw image into the selected photo picker item, and then converts the data into a UIImage.
                        if let imageData = try? await newItem.loadTransferable(type: Data.self),
                            let image = UIImage(data: imageData) {
                            selectedImage = image //assigns the selectedImage to the uploaded image to display to the UI
                        }
                    }
                }
            }
        }
        .padding()
        //call the recognize text function to read the text off of the image
        .onChange(of: selectedImage) {
            if let selectedImage = selectedImage {
                processImage(from: selectedImage)
            }
        }
    }
    
    func processImage(from image: UIImage){
        /// Processes the uploaded/captured image
        recognizeText(from: image) { lines in
            let result = getInfoFromText(from: lines, game: "euromillions")
            let drawDates = result.drawDates
            let drawNumbers = result.drawNumbers
            let drawSpecial = result.drawSpecial
            
            print("drawDates: ", drawDates)
            print("drawNumbers: ", drawNumbers)
            print("drawSpecial: ", drawSpecial)
        }
        
        //try? clearDatabase(context: context)
        
        let response: [LotteryDraw] = (try? getAllDraws(context: context)) ?? [] //the ?? [] unwraps the response of [LotteryDraw]?
        print("size: ", response.count)
    }
    
    func getDataFromAPI(game: String, context: ModelContext){
        /// Updates/gets the data from the API and adds it into the phone's database
        Task {
            do {
                try await fetchFromAPIandStore(game: game, context: context)
            } catch {
                print("Error fetching from API: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
