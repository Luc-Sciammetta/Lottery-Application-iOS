import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications

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

struct WinResult: Hashable, Identifiable {
    let id = UUID()
    var wins: [WinDict]
    var ticket: ParsedTicket
    
    //for the sheet that displays the results
    func hash(into hasher: inout Hasher) {
        hasher.combine(wins)
        hasher.combine(ticket)
    }
    
    static func == (lhs: WinResult, rhs: WinResult) -> Bool {
        lhs.wins == rhs.wins && lhs.ticket == rhs.ticket
    }
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
    
    @State private var pastResultSheetData: WinResult?
    @State private var isTicketFinished: Bool = false
    
    @Environment(\.modelContext) private var context //context for saving the lottery data
    @Environment(\.colorScheme) var colorScheme //for dark mode/light mode
    
    @Query(sort: \ScannedTicket.scanDate, order: .reverse) var pastTickets: [ScannedTicket] //to get all past scanned tickets
    
    private let allGames = ["powerball", "megamillions", "lottoamerica", "euromillions"]
    
    let gameDraws: [String: [Int]] = [
        "powerball": [2, 4, 7],
        "megamillions": [3, 6],
        "lottoamerica": [2, 4, 7],
        "euromillions": [3, 6]
    ]
    
    private func winBadge(_ isWinner: Bool?, lastDrawDate: Date?) -> some View {
        let label: String
        let foreground: Color
        let background: Color
        
        if isWinner == true {
            label = "Winner"
            foreground = Color(red: 0.23, green: 0.53, blue: 0.07)
            background = Color(red: 0.92, green: 0.95, blue: 0.87)
        }else if isWinner == false{
            label = "No Win"
            foreground = .secondary
            background = Color(.systemGray5)
        }else{ //isWinner == nil
            let today = Calendar.current.startOfDay(for: Date())
            let lastDraw = Calendar.current.startOfDay(for: lastDrawDate!)
            if today <= lastDraw {
                label = "Live"
                foreground = Color(red: 0.52, green: 0.31, blue: 0.04)
                background = Color(red: 0.98, green: 0.93, blue: 0.85)
            }else{
                label = "Not Checked"
                foreground = Color(red: 0.10, green: 0.30, blue: 0.60)
                background = Color(red: 0.88, green: 0.93, blue: 0.98)
            }
        }
        
        return Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(background)
            .clipShape(Capsule())
    }
    
    @ViewBuilder
    private func ballView(_ number: Int, matched: Bool, isSpecial: Bool) -> some View {
        if matched {
            if isSpecial{
                Text("\(number)")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 26, height: 26)
                    .background(Color(.green))
                    .overlay(Circle().stroke(Color.orange, lineWidth: 4))
                    .clipShape(Circle())
            }else{
                Text("\(number)")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 26, height: 26)
                    .background(Color(.green))
                    .clipShape(Circle())
            }
            
        }else if isSpecial{
            Text("\(number)")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                .clipShape(Circle())
        }else{
            Text("\(number)")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 26, height: 26)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    private var scannedTicketsView : some View{
        VStack{
            Text("Previously Scanned")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
            
            if pastTickets.count == 0{
                Text("No scanned tickets")
                    .foregroundStyle(Color.secondary) //changes the color of the text
                    .padding()
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, -6)
            }
            
            VStack (spacing: 8){
                ForEach(Array(pastTickets.enumerated()), id: \.offset) { idx, ticket in
                    Button {
                        //click on it to see a sheet of the draws
                        let wins = checkForWin(game: ticket.game, drawNumbers: ticket.drawNumbers, drawSpecials: ticket.drawSpecials, drawDates: ticket.drawDates, context: context)
                        pastResultSheetData = WinResult(wins: wins, ticket: ParsedTicket(game: ticket.game, drawDates: ticket.drawDates, drawNumbers: ticket.drawNumbers, drawSpecials: ticket.drawSpecials))
                        
                        if ticket.drawDates.count > 0{
                            let today = Calendar.current.startOfDay(for: Date())
                            let lastDrawDate = Calendar.current.startOfDay(for: ticket.drawDates.last!)
                            if today > lastDrawDate{
                                //so we are now checking it so we can update this tickets isWinner parameter
                                ticket.isWinner = !wins.isEmpty
                                try? context.save()
                                
                                //delete any notifications associated with this ticket
                                if let lastDate = ticket.drawDates.last {
                                    UNUserNotificationCenter.current().removePendingNotificationRequests(
                                        withIdentifiers: ["ticket-\(ticket.game)-\(lastDate.timeIntervalSince1970)"]
                                    )
                                }
                            }
                        }
                        
                        if ticket.isWinner == nil{ //indicates that we have never checked the results of this ticket before
                            isTicketFinished = false //indicates that the ticket is currently live
                        }else{
                            isTicketFinished = true
                        }
                        
                    } label: {
                        HStack{
                            //thumbnail
                            Group {
                                if let data = ticket.ticketImageData,
                                    let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color(.systemGray5)
                                }
                            }
                            .frame(width: 44, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack (alignment: .leading, spacing: 3){
                                //game name + win badge
                                HStack{
                                    Text(gameNames[ticket.game] ?? ticket.game)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    winBadge(ticket.isWinner, lastDrawDate: ticket.drawDates.last)
                                }
                                
                                //dates
                                Text("Scanned \(ticket.scanDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                switch ticket.drawDates.count {
                                case 0:
                                    Text("No Draw Date")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                case 1:
                                    Text("Draw \(ticket.drawDates[0], format: .dateTime.month().day().year())")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                case 2:
                                    Text("Draw \(ticket.drawDates[0], format: .dateTime.month().day().year()) - \(ticket.drawDates[1], format: .dateTime.month().day().year())")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                default:
                                    Text("Somehow you broke the app...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            //delete any notifications associated with this ticket
                            if let lastDate = ticket.drawDates.last {
                                UNUserNotificationCenter.current().removePendingNotificationRequests(
                                    withIdentifiers: ["ticket-\(ticket.game)-\(lastDate.timeIntervalSince1970)"]
                                )
                            }
                            //delete the ticket
                            context.delete(ticket)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    private func pastResultSheet(data: WinResult) -> some View {
        Group {
            if !data.wins.isEmpty {
                ScrollView{
                    Spacer()
                    Text("Results")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    winsCards(wins: data.wins, game: data.ticket.game)
                }
            }else{
                VStack{
                    if isTicketFinished == false {
                        Text("This draw hasn't occurred yet")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text("Check back after \(data.ticket.drawDates.last!, format: .dateTime.month().day().year())")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }else{
                        Text("This ticket is not a winner")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .presentationDetents([.large])
    }
    
    var body: some View {
        VStack{
            HStack (spacing: 16){
                Text("ScanMyTicket")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Image("Logo trans1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
            }
            .padding()
            
            Text("Scan a lottery ticket to check for wins")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .padding(.top, -40)
            
            Spacer()
            
            ScrollView {
                VStack {
                    Divider()
                    
                    //display the selected image/placeholder
                    if let selectedImage = selectedImage{ //if this ever gets changed to have an image, it will display it
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .padding()
                    }else{
                        Text("No Ticket Selected")
                            .foregroundStyle(Color.secondary) //changes the color of the text
                            .padding()
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    Divider()
                    
                    scannedTicketsView
                }
                .padding()
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
            .padding(.top, -10)
            
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
        .sheet(item: $pastResultSheetData){ data in
            pastResultSheet(data: data)
        }
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
