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

let playLetters: [Int: String] = [1: "A", 2: "B", 3: "C", 4: "D", 5: "E", 6: "F", 7: "G", 8: "H", 9: "I", 10: "J", 11: "K", 12: "L"]

struct ResultsView: View {
    var wins: [WinDict]
    @State var ticket: ParsedTicket
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var navPath: NavigationPath
    
    @State private var selectedImage: UIImage?
    @State private var parsedTicket: ParsedTicket? = nil
    @State private var showCamera = false
    
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
    
    @ViewBuilder
    private var checkAnotherButton : some View{
        Button("Check another ticket") {
            showCamera = true
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
        .foregroundStyle(Color(.white))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.black))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .bold()
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .buttonStyle(BlackButtonStyle())
        .onChange(of: selectedImage) {
            if let selectedImage = selectedImage {
                Task {
                    let ticket = await processImage(from: selectedImage)
                    parsedTicket = ticket
                    navPath.append(ticket)
                }
            }
        }
        //navigates to the Confirm View when the ticket has been parsed
        .navigationDestination(for: ParsedTicket.self) { ticket in
            ConfirmView(ticket: ticket, navPath: $navPath)
        }
        
    }
    
    @ViewBuilder
    private var goHome : some View{
        Button("Go Home") {
            navPath.removeLast(navPath.count) // clears entire stack → back to ContentView
        }
        .foregroundStyle(Color(.black))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .bold()
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
                Text("Play " + (playLetters[index + 1] ?? "Unknown"))
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
                            .overlay(Circle().stroke(Color.mint, lineWidth: 2))
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
            
            let specials = index < ticket.drawSpecials.count ? ticket.drawSpecials[index] : []
            HStack (spacing: 8){
                ForEach(Array(specials.enumerated()), id: \.offset) { idx, ball in
                    if win.matchedSpecials.contains(ball){
                        Text("\(ball)")
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.green, lineWidth: 2))
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
    
    var body: some View {
        VStack (alignment: .center, spacing: 12){
            ScrollView{
                VStack (alignment: .center, spacing: 12) {
                    if wins.isEmpty{
                        Spacer()
                        
                        Text("This ticket is not a winner")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }else{
                        winsCards
                    }
                }
                .navigationTitle("Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing){
                        Text(gameNames[ticket.game] ?? ticket.game)
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            
            checkAnotherButton
            goHome
        }
        .navigationBarBackButtonHidden(false)
    }
}
