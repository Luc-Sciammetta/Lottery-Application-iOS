import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? //holds the selected photo from the image library
    @State private var selectedImage: UIImage? //holds the loaded image from the image library
    @State private var showingCamera = false
    @State private var wins: [WinDict] = []
    
    @Environment(\.modelContext) private var context //context for saving the lottery data
    
    private let allGames = ["powerball", "megamillions", "lottoamerica", "euromillions"]
    
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
            
            if !wins.isEmpty {
                ForEach(wins.indices, id: \.self) { index in
                    let win = wins[index]
                    Text("Matched \(win.numberOfMatchedNumbers) numbers, \(win.numberOfMatchedSpecials) special")
                }
            }else{
                Text("Sorry, didn't win anything :(")
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
        .task {
//            try? clearDatabase(context: context)
            await refreshDataIfNeeded()
        }
        //call the recognize text function to read the text off of the image
        .onChange(of: selectedImage) {
            if let selectedImage = selectedImage {
                Task {
                    wins = await processImage(from: selectedImage)
                }
            }
        }
    }
    
    
    @MainActor
    func refreshDataIfNeeded() async { //refreshes app database in the background when the app loads
        print("DATASET SIZE BEFORE: ", (try? getAllDraws(context: context).count) ?? -1)
        
        let currentDate = Date()
        for game in allGames {
            let lastEntry = try? getLastEntry(game: game, context: context)
            
            if let drawingDate = lastEntry?.drawingDate, currentDate.timeIntervalSince(drawingDate) > 3 * 24 * 60 * 60 { //TODO: find whether the value should be 2 or 3 days
                print("updating data from api for \(game)")
                await getDataFromAPI(game: game, context: context)
            } else if lastEntry == nil { //we have nothing in the database for that game
                print("getting data to populate database for \(game)")
                await getDataFromAPI(game: game, context: context)
            }
        }
        
        print("DATASET SIZE AFTER: ", (try? getAllDraws(context: context).count) ?? -1)
    }
    
    @MainActor
    func processImage(from image: UIImage) async -> [WinDict] {
        /// Processes the uploaded/captured image

        let game = classifyImage(image: image);

        let lines = await recognizeText(from: image)
        
        let result = getInfoFromText(from: lines, game: game, mainTolerance: 2, specialTolerance: 0)
        let drawDates = result.drawDates
        let drawNumbers = result.drawNumbers
        let drawSpecial = result.drawSpecial
        
        print(drawDates)
        
        //convert [[String]] numbers to [[Int]] by flattening and parsing
        let formattedNumbers: [[Int]] = drawNumbers.map { $0.compactMap { Int($0) } }
        let formattedSpecials: [[Int]] = drawSpecial.map { $0.compactMap { Int($0) } }
        
        let formattedDates: [Date] = convertStringsToDate(drawDates: drawDates)
        
        print("formatted dates: ", formattedDates)
        print("formatted numbers: ", formattedNumbers)
        print("formatted special: ", formattedSpecials)
        
        let wins = checkForWin(game: game, drawNumbers: formattedNumbers, drawSpecials: formattedSpecials, drawDates: formattedDates, context: context)
        print("wins: ", wins)
        
        return wins
    }
    
    
    func convertStringsToDate(drawDates: [String]) -> [Date] {
        var convertedDates: [Date] = []
        
        let months: [String: String] = [
            "JAN": "01", "FEB": "02", "MAR": "03", "APR": "04", "MAY": "05", "JUN": "06", "JUL": "07", "AUG": "08", "SEP": "09", "OCT": "10", "NOV": "11", "DEC": "12"
        ]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for date in drawDates{
            let parts = date.split(separator: " ")
            let stringDay = parts[1]
            let stringMonth = parts[0]
            let stringYear = parts[2]
            
            let month = months[stringMonth.uppercased()]!
            
//            let currentYear = Calendar.current.component(.year, from: Date())
//            
//            if Int(month)! >= Calendar.current.component(.month, from: Date()) {
//                let stringDate = "\(currentYear-1)-\(month)-\(stringDay)" //puts components into yyyy-MM-dd format
//                guard let convertedDate = formatter.date(from: stringDate) else {
//                    print("Could not parse date: \(stringDate) correctly")
//                    return []
//                }
//                convertedDates.append(convertedDate)
//            }else{
//                let stringDate = "\(currentYear)-\(month)-\(stringDay)" //puts components into yyyy-MM-dd format
//                guard let convertedDate = formatter.date(from: stringDate) else {
//                    print("Could not parse date: \(stringDate) correctly")
//                    return []
//                }
//                convertedDates.append(convertedDate)
//            }
            
            let stringDate = "\(stringYear)-\(month)-\(stringDay)" //puts components into yyyy-MM-dd format
            guard let convertedDate = formatter.date(from: stringDate) else {
                print("Could not parse date: \(stringDate) correctly")
                return []
            }
            convertedDates.append(convertedDate)
        }
        
        let uniqueDates = Array(Set(convertedDates))  //remove duplicate dates
        
        return uniqueDates.sorted()
    }
    
    func getDataFromAPI(game: String, context: ModelContext) async{
        /// Updates/gets the data from the API and adds it into the phone's database
        do {
            try await fetchFromAPIandStore(game: game, context: context)
        } catch {
            print("Error fetching from API: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
