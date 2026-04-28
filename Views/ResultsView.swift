import SwiftUI
import SwiftData
import PhotosUI

struct ResultsView: View {
    var wins: [WinDict]
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var navPath: NavigationPath
    
    var body: some View {
        VStack {
            Button("Go Home") {
                navPath.removeLast(navPath.count) // clears entire stack → back to ContentView
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
