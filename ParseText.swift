import UIKit
import SwiftUI

struct LotteryConfig {
    let main : Int
    let special : Int
    let special_labels : [String]
}

let LOTTERY_CONFIGS: [String: LotteryConfig] = [
    "euromillions": LotteryConfig(main: 5, special: 2, special_labels: ["Lucky", "--", "-", "++", "LD"]),
    "powerball":    LotteryConfig(main: 5, special: 1, special_labels: ["PB", "EP", "QP", "OP", "-", "PWR"]),
    "megamillions": LotteryConfig(main: 5, special: 1, special_labels: ["MB", "EP", "QP", "OP", "AP"]),
    "lottoamerica": LotteryConfig(main: 5, special: 1, special_labels: ["Star", "EP", "QP", "OP", "SB"]),
]

let MONTHS = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]


func getInfoFromText(from lines: [String], game: String) -> (drawDates: [String], drawNumbers: [[String]], drawSpecial: [[String]]) {
    var possibleDrawDates: [String] = []
    var possibleDrawNumbers: [[String]] = []
    var possibleDrawSpecial: [[String]] = []
    
    let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                  "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
                  "JANUARY", "FEBRUARY", "MARCH", "APRIL", "JUNE",
                  "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    //"JAN 15" or "JANURARY 15"
    let perfectPatternDayAfter = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|JANUARY|FEBRUARY|MARCH|APRIL|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+(\d{1,2})\b/
        .ignoresCase()
    //"15 JAN"
    let perfectPatternDayBefore = /\b(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|JANUARY|FEBRUARY|MARCH|APRIL|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\b/
        .ignoresCase()
    //"JAN15"
    let fusedPattern = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{1,2})(\s|$)\b/
        .ignoresCase()
    let misreadPattern = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[IOQT\]](\d)/
        .ignoresCase()
    
    //get the drawDates
    for line in lines {
        print(line)
        var foundPerfectMatch = false //so that we dont get both perfect matches (i.e. "FRI 15 JAN 20", we want "15 JAN" not "JAN 20")
        if let match = try? perfectPatternDayBefore.firstMatch(in: line) {
            let month = String(String(match.output.2).prefix(3)).uppercased() //gets the first group (the month), trims it to the first 3 characters, in uppercase
            let day = String(match.output.1)
            possibleDrawDates.append(month + " " + day)
            foundPerfectMatch = true
        }
        if !foundPerfectMatch, let match = try? perfectPatternDayAfter.firstMatch(in: line) {
            let month = String(String(match.output.1).prefix(3)).uppercased() //gets the first group (the month), trims it to the first 3 characters, in uppercase
            let day = String(match.output.2)
            possibleDrawDates.append(month + " " + day)
        }
        
        if let match = try? misreadPattern.firstMatch(in: line){
            let month = String(match.output.1).uppercased()
            var day = String(match.output.2)
            
            let letter = line[match.range] //gets the full matched substring
                .dropFirst(3) //drops the first 3 characters
                .prefix(1) //gets the first character
                .uppercased()
            
            switch letter{
                case "I", "T":
                    day = "1" + day
                case "Q", "O":
                    day = "0" + day
                default:
                    break
            }
            
            possibleDrawDates.append(month + " " + day)
        }
        
        if let match = try? fusedPattern.firstMatch(in: line){
            let month = String(match.output.1).uppercased()
            let day = String(match.output.2)
            possibleDrawDates.append(month + " " + day)
        }
    }
    
    
    //get the drawNumbers and drawSpecial
    let drawNumberPattern = /\b\d{2}\b/
    let parenNumberPattern = /^\(\d+\)$/
    for line in lines {
        var foundNumbers: [String] = []
        var foundSpecials: [String] = []
        
        let tokens = line.split(separator: " ")
        
         var specialSwitch = false
        
        for token in tokens {
            //TODO: If we see a string in the middle of out numbers, chances are those numbers arent actually drawNumbers
//            print("token: ", token)
            
            if LOTTERY_CONFIGS[game]?.special_labels.contains(String(token).uppercased()) == true {
                print("Hey")
                //now any numbers we see in the line are special numbers
                specialSwitch = true
                continue
            }
            
            if let match = try? parenNumberPattern.firstMatch(in: String(token)){
//                print("Hi")
                foundSpecials.append(String(match.output.dropFirst().dropLast())) //drop the () from the match to get just the number
                specialSwitch = true //we found a special number, so we can assume the rest in the row are special numbers
                continue //so that we dont get to the drawNumberPattern match if-statement
            }
            
            if let match = try? drawNumberPattern.firstMatch(in: String(token)){
                if specialSwitch{ //special number
                    print("helloo")
                    foundSpecials.append(String(match.output))
                }else{ //regular draw number
                    foundNumbers.append(String(match.output))
                }
            }
        }
        
        print("found numbers", foundNumbers)
        print("found specials", foundSpecials)
        
        if foundNumbers.count == LOTTERY_CONFIGS[game]?.main { //then we have probably found a group of numbers
            possibleDrawNumbers.append(foundNumbers)
            foundNumbers = []
        }
        
        if foundSpecials.count == LOTTERY_CONFIGS[game]?.special { //then we have probably found a group of special numbers
            print("why")
            possibleDrawSpecial.append(foundSpecials)
            foundSpecials = []
        }
    }
    
    return (possibleDrawDates, possibleDrawNumbers, possibleDrawSpecial)
}
