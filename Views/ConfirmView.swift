import SwiftUI
import SwiftData
import PhotosUI

struct ConfirmView: View {
    @State var ticket: ParsedTicket
    @State private var wins: [WinDict] = []
    @State private var navigateToResults = false
    @Environment(\.modelContext) private var context
    
    @Binding var navPath: NavigationPath
    
    @State private var selectedGame: String
    
    @State private var selectedDateIndex: Int? = nil
    @State private var showingDatePicker: Bool = false
    @State private var newSelectedDate: Date = Date()
    
    @State private var editingSpecial: Bool = false
    @State private var selectedDrawIndex: Int? = nil
    @State private var selectedNumberIndex: Int? = nil
    @State private var showingNumberPicker: Bool = false
    @State private var newSelectedNumber: Int = 0
    
    @State private var showingTooManyDatesAlert: Bool = false
    
    
    let gameNames: [String: String] = [
        "powerball": "Powerball",
        "megamillions": "Mega Millions",
        "lottoamerica": "Lotto America",
        "euromillions": "EuroMillions",
    ]
    
    let playLetters: [Int: String] = [1: "A", 2: "B", 3: "C", 4: "D", 5: "E", 6: "F", 7: "G", 8: "H", 9: "I", 10: "J", 11: "K", 12: "L"]
    
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
    
    init(ticket: ParsedTicket, navPath: Binding<NavigationPath>) {
        self.ticket = ticket
        self._navPath = navPath
        self._selectedGame = State(initialValue: ticket.game)
    }
    
    var currentPickerRange: [Int] {
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
        HStack{
            Text("Lottery Draws")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button{
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
    private func drawCard(index: Int, numbers: [Int]) -> some View {
        VStack{
            Text("Play " + (playLetters[index + 1] ?? "Unknown"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
             
            Divider()
             
            Text("Main Numbers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack (spacing: 8){
                ForEach(Array(numbers.enumerated()), id: \.offset) { idx, ball in
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
            
            Text(gameSpecialNames[selectedGame] ?? "Special")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            let specials = index < ticket.drawSpecials.count ? ticket.drawSpecials[index] : []
            HStack (spacing: 8){
                ForEach(Array(specials.enumerated()), id: \.offset) { idx, ball in
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
        Button("Check Ticket"){
            Task {
                wins = checkForWin(game: selectedGame, drawNumbers: ticket.drawNumbers, drawSpecials: ticket.drawSpecials, drawDates: ticket.drawDates, context: context)
                print("wins: ", wins)
                navPath.append(wins)
            }
        }
        .foregroundStyle(Color(.white))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.black))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(BlackButtonStyle())
    }

    // MARK: - Sheets

    private var datePickerSheet: some View {
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

    // MARK: - Body

    var body: some View {
        ScrollView{
            VStack (alignment: .center, spacing: 12) {
                dateSection
                
                Spacer()
                
                drawNumbersSection
                
                checkTicketButton
            }
            .navigationTitle("Confirm Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: [WinDict].self) { wins in
                ResultsView(wins: wins, ticket: ticket, navPath: $navPath)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing){
                    Menu {
                        ForEach(["powerball", "megamillions", "euromillions", "lottoamerica"], id: \.self) { game in
                            Button {
                                selectedGame = game
                            } label: {
                                Text(gameNames[game] ?? game)
                                    .padding(.horizontal, 10)
                                    .foregroundStyle(Color(.black))
                            }
                        }
                    } label: {
                        HStack (spacing: 4) {
                            Text(gameNames[selectedGame] ?? selectedGame)
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabel))
                            Image(systemName: "chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(Color(.secondaryLabel))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal)
            .sheet(isPresented: $showingDatePicker){
                datePickerSheet
            }
            .sheet(isPresented: $showingNumberPicker){
                numberPickerSheet
            }
            .alert("Unable to add date", isPresented: $showingTooManyDatesAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You are about to add too many dates to your lottery draw. Please remove a date before adding another.")
            }
        }
    }
}
