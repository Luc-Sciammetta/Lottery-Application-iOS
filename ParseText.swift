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

let LOTTERY_NUMBER_RANGES: [String: (mainRange: ClosedRange<Int>, specialRange: ClosedRange<Int>)] = [
    "powerball":    (1...69, 1...26),
    "megamillions": (1...70, 1...24),
    "lottoamerica": (1...52, 1...10),
    "euromillions": (1...50, 1...12)
]
let MONTHS = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]


func zip3<A: Sequence, B: Sequence, C: Sequence>(_ a: A, _ b: B, _ c: C) -> [(A.Element, B.Element, C.Element)] {
    Array(zip(a, zip(b, c)).map { ($0.0, $0.1.0, $0.1.1) })
}

func getInfoFromText(from lines: [String], game: String, mainTolerance: Int, specialTolerance: Int) -> (drawDates: [String], drawNumbers: [[String]], drawSpecial: [[String]]) {
    //mainTolerance: the amount of allowed missing numbers from the foundNumbers to be considered a "draw"
    //specialTolerance: the amount of allowed missing numbers from the specialNumbers to be considered part of a "special"
    
    var possibleDrawDates: [String] = []
    var possibleDrawNumbers: [[String]] = []
    var possibleDrawSpecial: [[String]] = []

    //"JAN 15 25" or "JAN 15 2025" or "JAN15 25" etc.
    let perfectPatternDayAfter = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s*(\d{1,2})\s+(\d{2,4})\b/
        .ignoresCase()
    //"15 JAN 25" or "15 JAN 2025"
    let perfectPatternDayBefore = /\b(\d{1,2})\s*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s+(\d{2,4})\b/
        .ignoresCase()
    //"JAN1725" or "DEC172025" (fully fused)
    let fusedPattern = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{1,2})(\d{2}|\d{4})\b/
        .ignoresCase()
    //Misread: letter replacing a digit in day/year e.g. "JANI725"
    let misreadPattern = /\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[IOQT\]](\d)/
        .ignoresCase()

    //Helper: normalise a 2- or 4-digit year string → "2025" style
    func normaliseYear(_ raw: String) -> String {
        if raw.count == 4 { return raw }
        let suffix = Int(raw) ?? 0
        return suffix < 50 ? "20\(String(format: "%02d", suffix))" : "19\(String(format: "%02d", suffix))"
    }

    for line in lines {
        print(line)
        var foundPerfectMatch = false

        //"17 DEC 25" / "17DEC25" / "17 DEC 2025" / "17DEC2025"
        if let match = try? perfectPatternDayBefore.firstMatch(in: line) {
            let day   = String(match.output.1)
            let month = String(String(match.output.2).prefix(3)).uppercased()
            let year  = normaliseYear(String(match.output.3))
            possibleDrawDates.append(month + " " + day + " " + year)
            foundPerfectMatch = true
        }

        //"DEC 17 25" / "DEC17 25" / "DEC 17 2025" / "DEC17 2025"
        if !foundPerfectMatch, let match = try? perfectPatternDayAfter.firstMatch(in: line) {
            let month = String(String(match.output.1).prefix(3)).uppercased()
            let day   = String(match.output.2)
            let year  = normaliseYear(String(match.output.3))
            possibleDrawDates.append(month + " " + day + " " + year)
            foundPerfectMatch = true
        }

        //"DEC1725" / "DEC172025"
        if !foundPerfectMatch, let match = try? fusedPattern.firstMatch(in: line) {
            let month = String(match.output.1).uppercased()
            let day   = String(match.output.2)
            let year  = normaliseYear(String(match.output.3))
            possibleDrawDates.append(month + " " + day + " " + year)
        }

        //Misread pass — runs independently of the above
        if let match = try? misreadPattern.firstMatch(in: line) {
            let month = String(match.output.1).uppercased()
            var day   = String(match.output.2)

            let matchedSubstring = line[match.range]
            let letter = matchedSubstring
                .dropFirst(3)
                .prefix(1)
                .uppercased()

            switch letter {
            case "I", "T": day = "1" + day
            case "Q", "O": day = "0" + day
            default: break
            }

            //Try to grab a year that follows the misread day
            let afterMisread = String(line[match.range.upperBound...])
            let yearCapture  = /^\s*(\d{2,4})\b/.ignoresCase()
            var year = ""
            if let yMatch = try? yearCapture.firstMatch(in: afterMisread) {
                year = " " + normaliseYear(String(yMatch.output.1))
            }

            possibleDrawDates.append(month + " " + day + " " + year)
        }
    }
    
    var twoDigitsUnused: [Int] = []
    
    //get the drawNumbers and drawSpecial
    let drawNumberPattern = /\b\d{2}\b/
    let parenNumberPattern = /^\(\d+\)$/
    for line in lines {
        //skip lines that contain a date — numbers on these lines are NOT draw values
        let isDateLine = (try? perfectPatternDayBefore.firstMatch(in: line)) != nil || (try? perfectPatternDayAfter.firstMatch(in: line)) != nil || (try? fusedPattern.firstMatch(in: line)) != nil || (try? misreadPattern.firstMatch(in: line)) != nil
            
        if isDateLine {
            print("skipping date line: \(line)")
            continue
        }
        
        
        var foundNumbers: [String] = []
        var foundSpecials: [String] = []
        
        let tokens = line.split(separator: " ")
        
        var specialSwitch = false
        
        for token in tokens {
            print("token: ", token)
            if LOTTERY_CONFIGS[game]?.special_labels.contains(String(token).uppercased()) == true {
                print("meh")
                //now any numbers we see in the line are special numbers
                specialSwitch = true
                continue
            }
            
            if let match = try? parenNumberPattern.firstMatch(in: String(token)){
                print("()((())")
                foundSpecials.append(String(match.output.dropFirst().dropLast())) //drop the () from the match to get just the number
                specialSwitch = true //we found a special number, so we can assume the rest in the row are special numbers
                continue //so that we dont get to the drawNumberPattern match if-statement
            }
            
            if let match = try? drawNumberPattern.firstMatch(in: String(token)){
                if !specialSwitch && foundNumbers.count < LOTTERY_CONFIGS[game]!.main { //have the foundNumbers.count so that we dont add greater than the amount of allowed numbers in a draw
                    //we want to add to foundNumbers
                    print("Hello: ", token)
                    foundNumbers.append(String(match.output))
                }else{
                    //probs found a special
                    print("hhehehehe: ", token)
                    foundSpecials.append(String(match.output))
                }
                continue
            }
            
        }

        if foundNumbers.count >= LOTTERY_CONFIGS[game]!.main - mainTolerance { //we found mainNumbers
            print("MAIN")
            possibleDrawNumbers.append(foundNumbers)
            foundNumbers = []
            
            //always pair with a special entry, even if empty
            if foundSpecials.count >= LOTTERY_CONFIGS[game]!.special - specialTolerance { //we found specialNumbers
                print("SPECIAL")
                possibleDrawSpecial.append(foundSpecials)
                foundSpecials = []
            } else {
                for num in foundSpecials {
                    twoDigitsUnused.append(Int(num)!)
                }
                possibleDrawSpecial.append([]) // placeholder so draw indices stay in sync
                foundSpecials = []
            }
        } else {
            for num in foundNumbers {
                twoDigitsUnused.append(Int(num)!)
            }
            foundNumbers = []
            
            //only append specials if we didn't already handle them above
            if foundSpecials.count >= LOTTERY_CONFIGS[game]!.special - specialTolerance {
                print("SPECIAL")
                possibleDrawSpecial.append(foundSpecials)
                foundSpecials = []
                
                possibleDrawNumbers.append([])  // placeholder so draw indices stay in sync
            } else {
                for num in foundSpecials {
                    twoDigitsUnused.append(Int(num)!)
                }
                foundSpecials = []
            }
        }
        
        print("found numbers", foundNumbers)
        print("found specials", foundSpecials)
    }
    
    if possibleDrawNumbers.count == 0 && possibleDrawSpecial.count == 0 { //worst case we didnt find a single thing
        //we add empty lists to both, so we can see if we can fill any slots with unused numbers
        //we can assume that there is one lottery draw on a lottery ticket (a zero-draw ticket would be wierd)
        print("COULD NOT FIND ANYTHING, SO ATTEMPTING TO FILL EVERYTHING")
        possibleDrawNumbers.append([])
        possibleDrawSpecial.append([])
    }
    
    
    //code to assume the placement of unused digits
    print("UNUSED: ", twoDigitsUnused)
    
    var possibleIndicies: [Int] = [] //the index of the entry in either drawNumbers/drawSpecial
    var possibleLists: [Int] = [] //1: draw numbers, 2: draw special
    var missingCounts: [Int] = [] //the number of missing items
    
    for (index, draw) in possibleDrawNumbers.enumerated() {
        let missing = (LOTTERY_CONFIGS[game]!.main) - draw.count
        if missing > 0 {
            for _ in 0..<missing {
                possibleIndicies.append(index)
                possibleLists.append(1)
            }
            missingCounts.append(missing)
        }
    }
    for (index, draw) in possibleDrawSpecial.enumerated() {
        let missing = (LOTTERY_CONFIGS[game]!.special) - draw.count
        if missing > 0 {
            for _ in 0..<missing {
                possibleIndicies.append(index)
                possibleLists.append(2)
            }
            missingCounts.append(missing)
        }
    }
    
    //remove any duplicates in possibleIndicies and possibleLists (combined duplicates)
    var seen = Set<String>()
    var zipped: [(Int, Int)] = []
    for pair in zip(possibleIndicies, possibleLists) {
        let key = "\(pair.0),\(pair.1)"
        if seen.insert(key).inserted {
            zipped.append(pair)
        }
    }
    possibleIndicies = zipped.map { $0.0 }
    possibleLists = zipped.map { $0.1 }
    
    print("POSSIBLE INDICIES: ", possibleIndicies)
    print("POSSIBLE LISTS: ", possibleLists)
    print("MISSING COUNTS: ", missingCounts)
    
    let gameMainRange = LOTTERY_NUMBER_RANGES[game]?.mainRange
    let gameSpecialRange = LOTTERY_NUMBER_RANGES[game]?.specialRange
    
    var index = 0
    var candidatesAdded: [Int] = [] //holds the candidates that we have added to drawNumbers/Special every pass we go through twoDigitsUnused
    while missingCounts.count != 0 && twoDigitsUnused != []{
        let candidate = twoDigitsUnused[index]
        var removed = false //whether we have removed an item from the twoDigitusUnused (meaning we found a spot for it)
        
        //see if the candidate fits the main/special values
        let fitsMain = gameMainRange!.contains(candidate)
        let fitsSpecial = gameSpecialRange!.contains(candidate)
        print("Candidate: ", candidate)
        print("FM: ", fitsMain)
        print("FS: ", fitsSpecial)
        
        if fitsMain && fitsSpecial {
            print("fits both")
            //we can only determine where it goes if there is only one open spot in both drawNumbers and drawSpecials (we know this is index 0)
            if possibleLists.count == 1 { //meaning there is only one missing item
                print("only one missing item")
                //it goes there
                if possibleLists[0] == 1 { //goes in drawNumbers
                    if !possibleDrawNumbers[possibleIndicies[0]].contains(String(format: "%02d", candidate)) { //to make sure we aren't adding a value we already have
                        print("goes in drawnumbers")
                        possibleDrawNumbers[possibleIndicies[0]].append(String(candidate))
                        twoDigitsUnused.remove(at: index)
                        candidatesAdded.append(candidate)
                        removed = true
                    }
                }else{ //goes in specialNumbers
                    if !possibleDrawSpecial[possibleIndicies[0]].contains(String(format: "%02d", candidate)) { //to make sure we aren't adding a value we already have
                        print("goes in drawspecial")
                        possibleDrawSpecial[possibleIndicies[0]].append(String(candidate))
                        twoDigitsUnused.remove(at: index)
                        candidatesAdded.append(candidate)
                        removed = true
                    }
                }
                
                missingCounts[0] -= 1 //decrement the number of missing places by 1 (since we just filled one)
                if missingCounts[0] == 0 { //then we are done
                    print("Missing counts is 0 when there is only one missing location, so breaking out of the loop")
                    break
                }
            }else{
                print("can't determine where value goes")
                //we cannot determine where the number goes, so we ignore it.
            }
        }
        
        if fitsMain && !fitsSpecial {
            print("fits one")
            //we have to loop through to see if we have any open spots in the drawNumbers.
            //if we see multiple open spots in the drawNumbers, we can't determine which location it goes in, so we ignore it.
            let count = possibleLists.filter { $0 == 1 }.count //the number of sets of drawNumbers that have missing values
            print("COUNT: ", count)
            
            
            if count == 1 { //meaning we have only one open spot in drawNumbers
                for (i, (idx, lst, _)) in zip3(possibleIndicies, possibleLists, missingCounts).enumerated(){
                    if lst == 1{ //we have found that open spot in drawNumbers
                        if !possibleDrawNumbers[idx].contains(String(format: "%02d", candidate)) { //to make sure we aren't adding a value we already have
                            print("found misisng drawnumbers loc")
                            possibleDrawNumbers[idx].append(String(candidate))
                            twoDigitsUnused.remove(at: index)
                            candidatesAdded.append(candidate)
                            removed = true
                            missingCounts[i] -= 1 //decrease the number of missing values in that group of drawNumbers by 1
                            if missingCounts[i] == 0{
                                print("missing ctns = 0")
                                possibleLists.remove(at: i)
                                possibleIndicies.remove(at: i)
                                missingCounts.remove(at: i)
                            }
                        }
                    }
                }
            }else{
                print("Cant determine where number goes")
                //we can't determine where it can go.
            }
        }
        
        if !fitsMain && fitsSpecial {
            print("UH OH spagehtti-oh")
            //impossible rn so no implementation
        }
        
        if !removed {
            index += 1
        }
        if twoDigitsUnused.isEmpty { break }
        if index >= twoDigitsUnused.count {
            index = 0
            if candidatesAdded == [] { //then we have gone through the whole list of twoDigitsUnused w/out adding anything, so we cannot add anymore (since we are stuck)
                break
            }else{
                candidatesAdded = [] //reset it to be empty so that we can do the loop again.
            }
        }
    }
    
    
    return (possibleDrawDates, possibleDrawNumbers, possibleDrawSpecial)
}
