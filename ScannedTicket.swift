import SwiftData
import Foundation

@Model
class ScannedTicket{
    var game: String
    var scanDate: Date
    var drawDates: [Date]
    var drawNumbers: [[Int]]
    var drawSpecials: [[Int]]
    var ticketImageData: Data?

    //win details
    var isWinner: Bool? //nil for not checked
    
    init(game: String, scanDate: Date, drawDates: [Date], drawNumbers: [[Int]], drawSpecials: [[Int]], ticketImageData: Data? = nil, isWinner: Bool? = nil) {
        self.game = game
        self.scanDate = scanDate
        self.drawDates = drawDates
        self.drawNumbers = drawNumbers
        self.drawSpecials = drawSpecials
        self.ticketImageData = ticketImageData
        self.isWinner = isWinner
    }
}


