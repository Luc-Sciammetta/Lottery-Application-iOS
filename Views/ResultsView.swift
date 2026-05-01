import SwiftUI
import SwiftData
import PhotosUI

let gameNames: [String: String] = [
    "powerball": "Powerball",
    "megamillions": "Mega Millions",
    "lottoamerica": "Lotto America",
    "euromillions": "EuroMillions",
]

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

let playLetters: [Int: String] = [0: "A", 1: "B", 2: "C", 3: "D", 4: "E", 5: "F", 6: "G", 7: "H", 8: "I", 9: "J", 10: "K", 11: "L", 12: "M", 13: "N", 14: "O", 15: "P", 16: "Q", 17: "R", 18: "S", 19: "T", 20: "U", 21: "V", 22: "W", 23: "X", 24: "Y", 25: "Z"]

struct ResultsView: View {
    var wins: [WinDict]
    @State var ticket: ParsedTicket
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var navPath: NavigationPath
    
    @State private var selectedImage: UIImage?
    @State private var parsedTicket: ParsedTicket? = nil
    @State private var showCamera: Bool = false
    
    @State private var showHelpSheet: Bool = false
    
    @ViewBuilder
    private var checkAnotherButton : some View{
        Button {
            showCamera = true
        } label: {
            Text("Check another ticket")
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
        .onChange(of: selectedImage) {
            if let selectedImage = selectedImage {
                Task {
                    let ticket = await processImage(from: selectedImage)
                    parsedTicket = ticket
                    print("TICKEEEET:", ticket)
                    navPath.removeLast(navPath.count)
                    navPath.append(ticket)
                    
                }
            }
        }
    }
    
    @ViewBuilder
    private var goHome : some View{
        Button {
            navPath.removeLast(navPath.count) // clears entire stack → back to ContentView
        } label: {
            Text("Go Home")
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
    }
    
    @ViewBuilder
    private var winsCards : some View {
        ForEach(Array(wins.enumerated()), id: \.offset) { index, win in
            winCard(index, win)
        }
    }
    
    @ViewBuilder
    private func winCard(_ index: Int, _ win: WinDict) -> some View {
        VStack{
            HStack {
                Text("Play " + (playLetters[win.playNumber] ?? "Unknown"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                let formattedDate = win.drawDate.formatted(date: .long, time: .omitted)
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
             
            Text("Main Numbers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack (spacing: 8){
                ForEach(Array(win.drawNumbers.enumerated()), id: \.offset) { idx, ball in
                    if win.matchedNumbers.contains(ball){
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .background(Color(.green))
                            .clipShape(Circle())
                    }else{
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            
            Text(gameSpecialNames[ticket.game] ?? "Special")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack (spacing: 8){
                ForEach(Array(win.drawSpecials.enumerated()), id: \.offset) { idx, ball in
                    if win.matchedSpecials.contains(ball){
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .background(Color(.green))
                            .clipShape(Circle())
                    }else{
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var helpSheet : some View {
        VStack (spacing: 20){
            Text("Not sure about your results? Cross-check your ticket on the official lottery websites below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                        
            VStack(spacing: 16) {
                Link("Powerball", destination: URL(string: "https://www.powerball.com")!)
                Link("Mega Millions", destination: URL(string: "https://www.megamillions.com")!)
                Link("Lotto America", destination: URL(string: "https://www.powerball.com/lotto-america")!)
                Link("Euro Millions", destination: URL(string: "https://www.euro-millions.com")!)
            }
            .font(.body)
            .foregroundStyle(.blue)
        }
        .padding(.top, 32)
        .padding(.horizontal)
        .presentationDetents([.height(300)])
    }
    
    var body: some View {
        VStack (alignment: .center, spacing: 12){
            ZStack (alignment: .bottomTrailing){
                GeometryReader { geometry in
                    ScrollView{
                        VStack (alignment: .center, spacing: 12) {
                            if ticket.drawDates.count == 0 && !ticket.drawNumbers.isEmpty && !ticket.drawSpecials.isEmpty && ticket.drawNumbers[0] != [] && ticket.drawSpecials[0] != []{ //then wins will contain all potential wins
                                Text("No draw dates were entered, so all possible wins are shown. Check your ticket for the exact draw date(s).")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                
                                Spacer()
                                Divider()
                            }
                            
                            if wins.isEmpty{
                                Spacer()
                                
                                Text("This ticket is not a winner")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }else{
                                Text("⭐️ Congratulations! This ticket is a winner! ⭐️")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                
                                winsCards
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                        .padding(.horizontal)
                    }
                }
                
                Button {
                    showHelpSheet = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 32))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .buttonStyle(.plain)
            }
            .frame(maxHeight: .infinity)
            
            checkAnotherButton
            goHome
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
        .sheet(isPresented: $showHelpSheet){
            helpSheet
        }
    }
}
