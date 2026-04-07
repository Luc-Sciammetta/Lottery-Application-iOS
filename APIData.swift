import SwiftData
import Foundation

@Model
class LotteryDraw { //class structure to hold the specific lottery drawing
    var game: String
    var drawingDate: Date
    var ball1: Int
    var ball2: Int
    var ball3: Int
    var ball4: Int
    var ball5: Int
    var special1: Int
    var special2: Int?
    var jackpot: String?
    
    init(game: String, drawingDate: Date, ball1: Int, ball2: Int, ball3: Int, ball4: Int, ball5: Int, special1: Int, special2: Int?) {
        self.game = game
        self.drawingDate = drawingDate
        self.ball1 = ball1
        self.ball2 = ball2
        self.ball3 = ball3
        self.ball4 = ball4
        self.ball5 = ball5
        self.special1 = special1
        self.special2 = special2
    }
}

func fetchFromAPIandStore(game: String, firstDate: String = "2025-01-01", secondDate: String = "2030-01-01", context: ModelContext) async throws {
    /// Gets data from the API and stores the data into the phone's database.

    let apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
    var request = URLRequest(url: URL(string: "https://api.lotterydata.io/\(game)/v1/betweendates/\(firstDate)/\(secondDate)")!)
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    let (data, _) = try await URLSession.shared.data(for: request) //gets the data from the URL
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("Error getting data, invalid JSON response.")
        return
    }
    
    //convert the json data into an array
    guard let drawingsData = json["data"] as? [[String: Any]] else {
        print("Error: 'data' field is missing or not an array.")
        return
    }
    //print(drawingsData)
    
    //list of ways to rename the lottery games's special balls
    let specialRenames: [String: [String: String]] = [
        "powerball":    ["special": "powerball"],
        "megamillions": ["special": "megaball"],
        "euromillions": ["special": "star1", "special2": "star2"],
        "eurojackpot":  ["special": "euro1", "special2": "euro2"],
        "lottoamerica": ["special": "starball"]
    ]
    let renames = specialRenames[game] ?? [:] //gets the proper renames for the game
    
    let dateFormatter = DateFormatter() //to format the date into a proper date
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    var draws: [LotteryDraw] = []
    for draw in drawingsData {
        //create the LotteryDraw object with the data from the API
        guard let ball1 = draw["ball1"] as? Int,
              let ball2 = draw["ball2"] as? Int,
              let ball3 = draw["ball3"] as? Int,
              let ball4 = draw["ball4"] as? Int,
              let ball5 = draw["ball5"] as? Int,
              let drawDateStr = draw["drawing_date"] as? String,
              let drawDate = dateFormatter.date(from: drawDateStr),
              let special1 = draw[renames["special"] ?? "special"] as? Int else {
            continue
        }
        let special2 = renames["special2"].flatMap { draw[$0] as? Int }
        
        let lotteryDraw = LotteryDraw(game: game, drawingDate: drawDate, ball1: ball1, ball2: ball2, ball3: ball3, ball4: ball4, ball5: ball5, special1: special1, special2: special2)
        draws.append(lotteryDraw)
    }
    
    //print(draws)
    
    //save the data in the phone's database
    for draw in draws {
        //check if this draw already exists in the database
        let date = draw.drawingDate
        let descriptor = FetchDescriptor<LotteryDraw>(
            predicate: #Predicate { $0.game == game && $0.drawingDate == date }
        )
        let existing = try context.fetch(descriptor)
                
        if existing.isEmpty {
            //only insert if it doesn't already exist
            context.insert(draw)
        }
    }
    try context.save() //save it
}

func clearDatabase(context: ModelContext) throws {
    /// Clears the phone's database of lottery draws
    try context.delete(model: LotteryDraw.self)
    try context.save()
}

func getDraw(game: String, drawingDate: Date, context: ModelContext) throws -> LotteryDraw? {
    /// Gets a specific lottery draw if given a game and a drawing date
    let descriptor = FetchDescriptor<LotteryDraw>(
        predicate: #Predicate { $0.game == game && $0.drawingDate == drawingDate }
    )
    return try context.fetch(descriptor).first!
}

func getDraws(game: String, context: ModelContext) throws -> [LotteryDraw] {
    /// Gets all lottery draws based on a given game
    let descriptor = FetchDescriptor<LotteryDraw>(
        predicate: #Predicate { $0.game == game }
    )
    return try context.fetch(descriptor)
}

func getAllDraws(context: ModelContext) throws -> [LotteryDraw] {
    /// Gets all lottery draws from the database
    let descriptor = FetchDescriptor<LotteryDraw>()
    return try context.fetch(descriptor)
}
