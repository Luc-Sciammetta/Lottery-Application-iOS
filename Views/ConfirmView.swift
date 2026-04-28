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
        if editingSpecial {
            if let range = LOTTERY_NUMBER_RANGES[selectedGame]?.specialRange {
                return Array(range)
            }
            return Array(1...99)
        } else {
            if let range = LOTTERY_NUMBER_RANGES[selectedGame]?.mainRange {
                return Array(range)
            }
            return Array(1...99)
        }
    }
    
    var body: some View {
        ScrollView{
            VStack (alignment: .center, spacing: 12) {
                if ticket.drawDates.count == 0 {
                    //TODO
                }else{
                    if ticket.drawDates.count == 1 {
                        Text("Date of Draw")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }else{
                        Text("Dates of Draw - Range")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(Array(ticket.drawDates.enumerated()), id: \.offset) { index, date in
                        Text(date.formatted(date: .long, time: .omitted))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture { //tap gesture for changing the date
                                selectedDateIndex = index
                                showingDatePicker = true
                                newSelectedDate = date //prefil the new date with the old one
                            }
                    }
                }
                
                Spacer()
                
                Text("Lottery Draws")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                ForEach(Array(ticket.drawNumbers.enumerated()), id: \.offset) { index, numbers in
                    VStack{
                        Text("Play " + (playLetters[index + 1] ?? "Unknown"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                         
                        Divider() //diving line between the Play text and the main numbers text
                         
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
                    
                }
                
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
                
            }
            .navigationTitle("Confirm Numbers")
            .navigationBarTitleDisplayMode(.inline)
            
            .navigationDestination(for: [WinDict].self) { wins in
                ResultsView(wins: wins, navPath: $navPath)
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
                                .font(.caption)
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
            
            //the popup for choosing a new date
            .sheet(isPresented: $showingDatePicker){
                VStack (spacing: 20){
                    Text("Select a Date")
                        .font(.headline)
                        .padding()
                    
                    DatePicker(
                        "",
                        selection: $newSelectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical) //shows the calendar grid style
                    .padding(.horizontal)
                }
                .presentationDetents([.medium]) //shows for only 1/2 of the screen
                .onChange(of: newSelectedDate){
                    if let index = selectedDateIndex{
                        ticket.drawDates[index] = newSelectedDate
                        
                        if ticket.drawDates.count == 2 {
                            //check the order of the dates so they are in chronological order
                            if ticket.drawDates[0] > ticket.drawDates[1] {
                                ticket.drawDates.swapAt(0, 1)
                            }
                        }
                    }
                    showingDatePicker = false
                }
            }
            
            //the popup for choosing a new draw number
            .sheet(isPresented: $showingNumberPicker){
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
                    .frame(width: 200, height: 300)
                    
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
                .presentationDetents([.medium]) //shows for only 1/2 of the screen
            }
            
        }
    }
}
