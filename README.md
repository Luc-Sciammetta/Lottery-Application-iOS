# Lottery-Application-iOS

This repository contains a Swift iOS application that interacts with lottery APIs to fetch and analyze lottery data. It (will) includes functionalities to retrieve datasets for different lottery games, process the data, and check for winning numbers.

The goal of this project is to allow users to take a photo of their lottery ticket numbers and the program will check if they have won any prizes based on the latest lottery draws.

This will be done using image recognition techniques to determine lottery ticket type, and extract the numbers from the photo and then comparing them against the fetched lottery data.

This is based off of the previous code written in Python in the Lottery-Application GitHub repository.

## Features
- Fetch lottery data from public APIs.
- Process and store lottery datasets in the iPhone's database format.
- This has support for the following lottery games:
  - Powerball
  - Mega Millions
  - Lotto America
  - EuroMillions
- Can get the date and numbers of the lottery draw from VNRecognizeText results
- Can check the found numbers from the ticket against the database, determining if the ticket is a winner or not
- Classify the lottery game to determine what game the ticket is for

## Known Issues
- The OCR for extracting numbers is not reliable, so not all lottery numbers/dates will be extracted from the text.

## Things to do:
- Have OCR Read text if there are letters in the way idk.
- Have Night Mode work well
