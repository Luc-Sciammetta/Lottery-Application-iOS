import SwiftUI
import SwiftData
import PhotosUI

struct ConfirmView: View {
    @State var ticket: ParsedTicket
    @State private var wins: [WinDict] = []
    @State private var navigateToResults = false
    @Environment(\.modelContext) private var context
    
    @Binding var navPath: NavigationPath
    
    @State private var selectedGame: String //holds the selected lottery game
    
    //for editing dates
    @State private var selectedDateIndex: Int? = nil
    @State private var showingDatePicker: Bool = false
    @State private var newSelectedDate: Date = Date()
    
    //for editing ball numbers
    @State private var editingSpecial: Bool = false
    @State private var selectedDrawIndex: Int? = nil
    @State private var selectedNumberIndex: Int? = nil
    @State private var showingNumberPicker: Bool = false
    @State private var newSelectedNumber: Int = 0
    
    //alerts
    @State private var showingTooManyDatesAlert: Bool = false
    @State private var numbersInAnInvalidRangeAlert: Bool = false
    @State private var tooManyDrawsAlert: Bool = false
    @State private var unfilledNumbersAlert: Bool = false
    @State private var noTicketAlert: Bool = false
    
    @State private var isTicket: Bool = true //whether the image is detected to be a ticket or not
    
    
    let gameNames: [String: String] = [
        "powerball": "Powerball",
        "megamillions": "Mega Millions",
        "lottoamerica": "Lotto America",
        "euromillions": "EuroMillions",
    ]
    
    let playLetters: [Int: String] = [1: "A", 2: "B", 3: "C", 4: "D", 5: "E", 6: "F", 7: "G", 8: "H", 9: "I", 10: "J", 11: "K", 12: "L", 13: "M", 14: "N", 15: "O", 16: "P", 17: "Q", 18: "R", 19: "S", 20: "T", 21: "U", 22: "V", 23: "W", 24: "X", 25: "Y", 26: "Z"]
    
    let gameSpecialNames: [String: String] = [
        "Powerball": "Powerball",
        "Mega Millions": "Megaball",
        "Lotto America": "Star Ball",
        "Euromillions": "Lucky Stars",
        "powerball": "Powerball",
        "megamillions": "Megaball",
        "lottoamerica": "Star Ball",
        "euromillions": "Lucky Stars",
    ]
    
    let LOTTERY_NUMBER_RANGES: [String: (mainRange: ClosedRange<Int>, specialRange: ClosedRange<Int>)] = [
        "powerball":    (1...69, 1...26),
        "megamillions": (1...70, 1...24),
        "lottoamerica": (1...52, 1...10),
        "euromillions": (1...50, 1...12)
    ]
    
    //init function
    init(ticket: ParsedTicket, navPath: Binding<NavigationPath>) {
        self.ticket = ticket
        self._navPath = navPath
        self._selectedGame = State(initialValue: ticket.game)
        
        //detects if we have a ticket or not
        let isEmpty = ticket.drawDates.isEmpty &&
                ticket.drawNumbers.count == 1 &&
                ticket.drawNumbers[0].isEmpty &&
                ticket.drawSpecials.count == 1 &&
                ticket.drawSpecials[0].isEmpty
        self._isTicket = State(initialValue: !isEmpty)
    }
    
    func checkTicketForValidNumberRange() -> Bool{
        ///Checks to see if the ticket ball numbers are all in the valid range of the lottery game
        let numberRange = LOTTERY_NUMBER_RANGES[ticket.game]
        //check the drawNumbers
        for draw in ticket.drawNumbers{
            for number in draw {
                if !numberRange!.mainRange.contains(number) {
                    return false
                }
            }
        }
        
        //check the drawSpecials
        for draw in ticket.drawSpecials{
            for number in draw {
                if !numberRange!.specialRange.contains(number) {
                    return false
                }
            }
        }
        
        return true
    }
    
    func checkForNotFilledNumbers() -> Bool {
        ///Checks to see if we have numbers in the ticket draw that are not filled in
        for draw in ticket.drawNumbers + ticket.drawSpecials {
            if draw.contains(-1) { return false }
        }
        return true
    }
    
    func addSpecialBallsToDraws() {
        ///adds a ball to all specials
        for index in 0..<ticket.drawSpecials.count {
            ticket.drawSpecials[index].append(-1) //-1 is the value for an unfilled number
        }
    }
    
    func removeSpecialBallsFromDraws() {
        ///removes the last ball from all specials
        for index in 0..<ticket.drawSpecials.count {
            ticket.drawSpecials[index].removeLast() //remove the last special ball in the group
        }
    }
    
    var currentPickerRange: [Int] {
        ///Gets the range that main and special numbers can be in for the selected lottery game
        ///Also removes any numbers that have already been used in that draw
        let range: [Int]
        
        if editingSpecial {
            range = Array(LOTTERY_NUMBER_RANGES[selectedGame]?.specialRange ?? 1...99)
        } else {
            range = Array(LOTTERY_NUMBER_RANGES[selectedGame]?.mainRange ?? 1...99)
        }
        
        //filter out numbers already in the current draw
        guard let sdi = selectedDrawIndex else { return range }
        
        return range.filter { number in
            if editingSpecial {
                return !ticket.drawSpecials[sdi].contains(number)
            } else {
                return !ticket.drawNumbers[sdi].contains(number)
            }
        }
    }
    
    struct BlackButtonStyle: ButtonStyle {
        ///Black button animation
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .brightness(configuration.isPressed ? -0.1 : 0) // darkens when pressed
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    // MARK: - Date Section

    @ViewBuilder
    private var dateSection: some View {
        ///Creates the date section of the view
        if ticket.drawDates.count == 0 {
            HStack{
                Text("No Dates Found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button{
                    ticket.drawDates.append(Date())
                } label: {
                    Image(systemName: "plus.app")
                }
                .foregroundStyle(.secondary)
            }
        } else {
            dateHeader
            
            ForEach(Array(ticket.drawDates.enumerated()), id: \.offset) { index, date in
                Text(date.formatted(date: .long, time: .omitted))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        selectedDateIndex = index
                        showingDatePicker = true
                        newSelectedDate = date
                    }
                    .contextMenu {
                        Button(role: .destructive){
                            ticket.drawDates.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var dateHeader: some View {
        ///Creates the header for the dates when there were dates in the ticket
        HStack{
            Text(ticket.drawDates.count == 1 ? "Date of Draw" : "Dates of Draw - Range")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button{
                if ticket.drawDates.count < 2 {
                    ticket.drawDates.append(Date())
                } else {
                    showingTooManyDatesAlert = true
                }
            } label: {
                Image(systemName: "plus.app")
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Draw Numbers Section

    @ViewBuilder
    private var drawNumbersSection: some View {
        ///Creates the draw numbers section
        if ticket.drawNumbers.first?.isEmpty ?? true {
            emptyDrawHeader
        } else {
            populatedDrawHeader
            
            ForEach(Array(ticket.drawNumbers.enumerated()), id: \.offset) { index, numbers in
                drawCard(index: index, numbers: numbers)
            }
        }
    }

    @ViewBuilder
    private var emptyDrawHeader: some View {
        ///Creates the draw header when there are no ball information
        HStack{
            Text("No Draw Information Found")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button{
                ticket.drawNumbers = ticket.drawNumbers.filter { !$0.isEmpty }
                ticket.drawSpecials = ticket.drawSpecials.filter { !$0.isEmpty }
                
                ticket.drawNumbers.append([1, 2, 3, 4, 5])
                if selectedGame == "euromillions"{
                    ticket.drawSpecials.append([1, 2])
                }else{
                    ticket.drawSpecials.append([1])
                }
            } label: {
                Image(systemName: "plus.app")
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var populatedDrawHeader: some View {
        ///Creates the draw number section when there are numbers
        HStack{
            Text("Lottery Draws")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button{
                if ticket.drawNumbers.count == 26 {
                    //cannot add any more (no more letters in the alphabet)
                    tooManyDrawsAlert = true
                }else{
                    ticket.drawNumbers.append([1, 2, 3, 4, 5])
                    if selectedGame == "euromillions"{
                        ticket.drawSpecials.append([1, 2])
                    }else{
                        ticket.drawSpecials.append([1])
                    }
                }
            } label: {
                Image(systemName: "plus.app")
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func drawCard(index: Int, numbers: [Int]) -> some View {
        ///Creates a card of a lottery play/draw
        VStack{
            Text("Play " + (playLetters[index + 1] ?? "Unknown"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
             
            Divider()
             
            Text("Main Numbers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            //Main numbers
            HStack (spacing: 8){
                ForEach(Array(numbers.enumerated()), id: \.offset) { idx, ball in
                    if ball == -1{ //for balls that were not found in the text parsing
                        Text("-")
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .onTapGesture {
                                editingSpecial = false
                                selectedDrawIndex = index
                                selectedNumberIndex = idx
                                showingNumberPicker = true
                            }
                    }else{
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .onTapGesture {
                                editingSpecial = false
                                selectedDrawIndex = index
                                selectedNumberIndex = idx
                                showingNumberPicker = true
                                newSelectedNumber = ball
                            }
                    }
                    
                }
            }
            
            //Special Numbers
            Text(gameSpecialNames[selectedGame] ?? "Special")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            let specials = index < ticket.drawSpecials.count ? ticket.drawSpecials[index] : []
            HStack (spacing: 8){
                ForEach(Array(specials.enumerated()), id: \.offset) { idx, ball in
                    if ball == -1{
                        Text("-")
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                            .clipShape(Circle())
                            .onTapGesture {
                                editingSpecial = true
                                selectedDrawIndex = index
                                selectedNumberIndex = idx
                                showingNumberPicker = true
                            }
                    }else{
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                            .clipShape(Circle())
                            .onTapGesture {
                                editingSpecial = true
                                selectedDrawIndex = index
                                selectedNumberIndex = idx
                                showingNumberPicker = true
                                newSelectedNumber = ball
                            }
                    }
                    
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive){
                ticket.drawNumbers.remove(at: index)
                ticket.drawSpecials.remove(at: index)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Check Ticket Button

    private var checkTicketButton: some View {
        ///Check the ticket button
        Button{
            Task {
                if !checkForNotFilledNumbers(){
                    unfilledNumbersAlert = true
                }else if !checkTicketForValidNumberRange() {
                    numbersInAnInvalidRangeAlert = true
                }else if !isTicket{
                    noTicketAlert = true
                }else{
                    wins = checkForWin(game: selectedGame, drawNumbers: ticket.drawNumbers, drawSpecials: ticket.drawSpecials, drawDates: ticket.drawDates, context: context)
                    print("wins: ", wins)
                    navPath.append(wins)
                }
            }
        } label: {
            Text("Check Ticket")
                .foregroundStyle(Color(.white))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.black))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .bold()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .buttonStyle(BlackButtonStyle())
    }

    // MARK: - Sheets

    private var datePickerSheet: some View {
        ///Sheet for picking the date
        VStack (spacing: 20){
            Text("Select a Date")
                .font(.headline)
                .padding()
            
            DatePicker(
                "",
                selection: $newSelectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
        }
        .presentationDetents([.medium])
        .onChange(of: newSelectedDate){
            if let index = selectedDateIndex{
                ticket.drawDates[index] = newSelectedDate
                
                if ticket.drawDates.count == 2 {
                    if ticket.drawDates[0] > ticket.drawDates[1] {
                        ticket.drawDates.swapAt(0, 1)
                    }
                }
            }
            showingDatePicker = false
        }
    }

    private var numberPickerSheet: some View {
        ///Sheet for picking the numbers
        VStack (spacing: 20){
            Text("Select a New Number")
                .font(.headline)
                .padding()
            
            Picker("", selection: $newSelectedNumber) {
                ForEach(currentPickerRange, id: \.self) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 200, height: 200)
            
            Spacer()
            
            Button{
                if let sdi = selectedDrawIndex, let sni = selectedNumberIndex{
                    if editingSpecial{
                        ticket.drawSpecials[sdi][sni] = newSelectedNumber
                    }else{
                        ticket.drawNumbers[sdi][sni] = newSelectedNumber
                    }
                }
                showingNumberPicker = false
            } label: {
                Text("Confirm")
                    .foregroundStyle(Color(.white))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.black))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .presentationDetents([.medium])
    }
    
    private var gameHeader : some View {
        ///Header for choosing the lottery game
        HStack {
            Text("Lottery Game")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if !isTicket {
                Button{
                    isTicket = true
                } label: {
                    Image(systemName: "plus.app")
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var gameSection : some View {
        ///Section for choosing the game
        gameHeader
        
        if isTicket {
            VStack {
                ForEach(["powerball", "megamillions", "euromillions", "lottoamerica"], id: \.self) { game in
                    Button {
                        selectedGame = game
                    } label: {
                        if selectedGame == game {
                            Text(gameNames[game] ?? game)
                                .foregroundStyle(Color(.white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.black))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .bold()
                        }else{
                            Text(gameNames[game] ?? game)
                                .foregroundStyle(Color(.black))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .bold()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Body

    var body: some View {
        VStack{
            ScrollView{
                VStack (alignment: .center, spacing: 12) {
                    Spacer()
                    
                    gameSection
                    
                    if isTicket {
                        Spacer()
                        
                        dateSection
                        
                        Spacer()
                        
                        drawNumbersSection
                    }else{
                        Spacer()
                        Divider()
                        Spacer()
                        Text("Are you sure this is a ticket?")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .bold()
                    }
                }
                .padding(.horizontal)
                .sheet(isPresented: $showingDatePicker){
                    datePickerSheet
                }
                .sheet(isPresented: $showingNumberPicker){
                    numberPickerSheet
                }
            }
            
            checkTicketButton
        }
        .navigationTitle("Confirm Numbers")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: [WinDict].self) { wins in
            ResultsView(wins: wins, ticket: ticket, navPath: $navPath)
        }
        .onChange(of: selectedGame) {
            let old = ticket.game
            ticket.game = selectedGame
            if LOTTERY_CONFIGS[old]!.special == 2{ //then we need to remove a special ball from each draw
                removeSpecialBallsFromDraws()
            }else if LOTTERY_CONFIGS[selectedGame]!.special == 2{ //then we need to add a special ball to each draw
                addSpecialBallsToDraws()
            }
        }
        .alert("Unable to add date", isPresented: $showingTooManyDatesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You are about to add too many dates to your lottery draw. Please remove a date before adding another.")
        }
        .alert("Numbers in an invalid range", isPresented: $numbersInAnInvalidRangeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Some of your numbers are outside the valid range for this game. Please update your numbers or select a different game.")
        }
        .alert("Unable to add draw", isPresented: $tooManyDrawsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have too many draws. Please delete a draw before creating a new one.")
        }
        .alert("Unfilled numbers", isPresented: $unfilledNumbersAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Some draws have unfilled numbers. Please fill them in before checking your ticket.")
        }
        .alert("No ticket to check", isPresented: $noTicketAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No lottery ticket was detected in the provided image. Please enter your ticket details manually by selecting the + beside \"Lottery Game,\" or retake the photo and try again.")
        }
    }
}
