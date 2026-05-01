import SwiftUI
import SwiftData
import PhotosUI

struct ParsedTicket: Hashable{
    var game: String
    var drawDates: [Date]
    var drawNumbers: [[Int]]
    var drawSpecials: [[Int]]
}

struct BlackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0) // darkens when pressed
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct WinResult: Hashable {
    var wins: [WinDict]
    var ticket: ParsedTicket
}

struct ContentView: View {
    @Binding var navigationPath: NavigationPath
    
    @State private var selectedItem: PhotosPickerItem? //holds the selected photo from the image library
    @State private var selectedImage: UIImage? //holds the loaded image from the image library
    @State private var showingCamera = false
        
    @State private var parsedTicket: ParsedTicket? = nil
    @State private var navigateToConfirmView = false
    
    @State private var isProcessing = false
    
    @State private var hasRefreshedData: Bool = false
    
    @Environment(\.modelContext) private var context //context for saving the lottery data
    
    private let allGames = ["powerball", "megamillions", "lottoamerica", "euromillions"]
    
    let gameDraws: [String: [Int]] = [
        "powerball": [2, 4, 7],
        "megamillions": [3, 6],
        "lottoamerica": [2, 4, 7],
        "euromillions": [3, 6]
    ]
    
    var body: some View {
        VStack{
            ScrollView {
                VStack {
                    Text("Scan a ticket to check for wins")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    Text("")
                    
                    Divider()
                    
                    //display the selected image/placeholder
                    if let selectedImage = selectedImage{ //if this ever gets changed to have an image, it will display it
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                    }else{
                        Text("No Image Selected")
                            .foregroundStyle(Color.secondary) //changes the color of the text
                            .padding()
                    }
                }
                .padding()
                .overlay {
                    if isProcessing {
                        VStack {
                            ProgressView()
                            Text("Extracting ticket information")
                                .foregroundStyle(.primary)
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                //call the recognize text function to read the text off of the image
                .onChange(of: selectedImage) {
                    if let selectedImage = selectedImage {
                        isProcessing = true
                        Task {
                            let ticket = await processImage(from: selectedImage)
                            parsedTicket = ticket
                            isProcessing = false
                            navigationPath.append(ticket)
                        }
                    }
                }
            }
            
            VStack (alignment: .center, spacing: 12){
                Button(action: {
                    showingCamera = true //show the camera view
                }){
                    Text("Take Photo")
                        .foregroundStyle(Color(.white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.black))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .bold()
                }
                .sheet(isPresented: $showingCamera){
                    CameraView(image: $selectedImage)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .buttonStyle(BlackButtonStyle())
                
                //photo picker button
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()){ //binds the user's chosen phot with the selectedItem variable so it updates when a photo is picked. Makes sures it only shows photos and to use the shared photo library.
                    Text("Choose from library") //information on how the button looks
                        .foregroundStyle(Color(.black))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .bold()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .buttonStyle(GrayButtonStyle())
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
        }
        .navigationTitle("Lottery Checker")
        .navigationBarTitleDisplayMode(.large)
        //navigates to the Confirm View when the ticket has been parsed
        .navigationDestination(for: ParsedTicket.self) { ticket in
            ConfirmView(ticket: ticket, navPath: $navigationPath, selectedImage: $selectedImage)
        }
        .navigationDestination(for: WinResult.self) { result in
            ResultsView(wins: result.wins, ticket: result.ticket, navPath: $navigationPath, selectedImage: $selectedImage)
        }
        .onAppear {
            if navigationPath.count == 0 {
                selectedImage = nil
                selectedItem = nil
            }
            if !hasRefreshedData {
                hasRefreshedData = true
                Task {
                    await refreshDataIfNeeded()
                }
            }
        }
    }
    
    
    @MainActor
    func refreshDataIfNeeded() async {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)! //we look at yesterday since in most cases, lottery draws are at night, and so if we check on the day of the draw, it hasn't happened yet, but we think it has.

        for game in allGames {
            //find the most recent draw date for this game
            guard let drawDays = gameDraws[game] else { continue }
            
            //work backwards from today to find the last draw day
            var mostRecentDraw: Date? = nil
            for daysBack in 0...6 {
                let candidate = calendar.date(byAdding: .day, value: -daysBack, to: yesterday)!
                let candidateWeekday = calendar.component(.weekday, from: candidate)
                if drawDays.contains(candidateWeekday) {
                    mostRecentDraw = calendar.startOfDay(for: candidate)
                    break
                }
            }
            
            guard let expectedDate = mostRecentDraw else { continue }
            
            //check if we already have that draw in the database
            let lastEntry = try? getLastEntry(game: game, context: context)
            let lastDrawDay = lastEntry.map { calendar.startOfDay(for: $0.drawingDate) }
            
            print("last draw day: ", lastDrawDay as Any)
            print("expected date: ", expectedDate)
            
            if lastDrawDay != expectedDate {
                print("Missing draw for \(game) on \(expectedDate), fetching...")
                await getDataFromAPI(game: game, context: context)
            } else {
                print("Data for \(game) is up to date")
            }
        }
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

@MainActor
func processImage(from image: UIImage) async -> ParsedTicket {
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
    
    return ParsedTicket(game: game, drawDates: formattedDates, drawNumbers: formattedNumbers, drawSpecials: formattedSpecials)
}

func convertStringsToDate(drawDates: [String]) -> [Date] {
    var convertedDates: [Date] = []
    
    let months: [String: String] = [
        "JAN": "01", "FEB": "02", "MAR": "03", "APR": "04", "MAY": "05", "JUN": "06", "JUL": "07", "AUG": "08", "SEP": "09", "OCT": "10", "NOV": "11", "DEC": "12"
    ]
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    
    let currentYear = Calendar.current.component(.year, from: Date())
    
    for date in drawDates{
        let parts = date.split(separator: " ")
        let stringDay = parts[1]
        let stringMonth = parts[0]
        
        let month = months[stringMonth.uppercased()]!
        
        var stringYear: String
        if parts.count == 3{
            stringYear = String(parts[2])
        }else{
            if Int(month)! > Calendar.current.component(.month, from: Date()) {
                stringYear = "\(currentYear-1)"
            }else{
                stringYear = "\(currentYear)"
            }
        }
        
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

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        ContentView(navigationPath: $path)
    }
}
