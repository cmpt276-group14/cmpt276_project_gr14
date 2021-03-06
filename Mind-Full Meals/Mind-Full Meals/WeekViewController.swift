//
//  WeekViewController.swift
//  Mind-Full Meals
//
//  Created by Jason Kimoto on 7/17/18.
//  Copyright © 2018 CMPT 267. All rights reserved.
//
/*
 TO DO:
 DONE:determine start and end of the week in seconds since 1970
 
 get all meals planned for the week from the database
 
 determine how many inputs there are for this week(set number of rows)
 
 go through each row of database results to input on calendar
 */

import UIKit

class WeekViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource
{
    
    var mealsInDateRangeQueue: [(String, Int32, String)] = []
    @IBAction func leftButton(_ sender: Any) {
        CurrentDay -= 7
        print("CURR DAY:", CurrentDay)
        if CurrentDay < 0
        {
            CurrentMonth -= 1 // go back 1 month
            if CurrentMonth < 0{ // go back to December of last year
                CurrentYear -= 1
                CurrentMonth = 11
            }
            CurrentDay = numOfDays[CurrentMonth]+CurrentDay // CurrentDay is negative
        }
       
        //i hate leap years
        if CurrentMonth == 1 && CurrentYear % 4 == 0
        {
           numOfDays[1] = 29
        }
        else
        {
           numOfDays[1] = 28
        }
       
        //CurrentDay = numOfDays[CurrentMonth]
        //print("CURR DAY:", CurrentDay)
        //print("DAY: ", CurrentDay, "N=", n, "MONTH:", CurrentMonth, "YEAR:", CurrentYear, "WEEK:", dayOfWeek)

        n = 0
        print("New week Loaded", CurrentMonth, CurrentDay)
        MyCollectionView.reloadData()
    }
    @IBAction func rightButton(_ sender: Any) {
        CurrentDay += 7
        print("CURR DAY:", CurrentDay)

        if CurrentDay > numOfDays[CurrentMonth]
        {
            CurrentMonth += 1 // Eg December 35 -> Jan 4?
            if CurrentMonth > 11{ // CurrentMonth = 12
                CurrentYear += 1 // Go 1 year forward
                CurrentMonth = 0 // January
                CurrentDay = CurrentDay%(numOfDays[11]) // Avoid index out of range for CurrentMonth = 0  or 12
                // CurrentDay = numOfDays[CurrentMonth] + CurrentDay%(numOfDays[11])
            }
            else { // Eg November 37 -> Dec 7
                //CurrentDay = numOfDays[CurrentMonth]+CurrentDay%(numOfDays[CurrentMonth-1]) // Dec has 31 days + 37%(num of days in nov) = 31 + 37%30=31+7=38
                CurrentDay = CurrentDay%(numOfDays[CurrentMonth-1])
            }
        }
        
        //i hate leap years
        if CurrentMonth == 1 && CurrentYear % 4 == 0
        {
           numOfDays[1] = 29
        }
        else
        {
           numOfDays[1] = 28
        }
        
        dayOfWeek = ((dayOfWeek - (CurrentDay % 7))+14)%7
        //CurrentDay = numOfDays[CurrentMonth]
        //print("CURR DAY:", CurrentDay)
        //print("DAY: ", CurrentDay, "N=", n, "MONTH:", CurrentMonth, "YEAR:", CurrentYear, "WEEK:", dayOfWeek)

        n = 0
        print("New week Loaded", CurrentMonth, CurrentDay)
        MyCollectionView.reloadData()
    }
    
    @IBOutlet weak var MyCollectionView: UICollectionView!
    var db: SQLiteDatabase?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        n = 0
        // Do any additional setup after loading the view, typically from a nib.
        //connecting to database
        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("Meal Database")
        do {
            db = try SQLiteDatabase.open(path: fileURL.path)
            print("Connected to database")
        }
        catch SQLiteError.OpenDatabase(let message) {
            print("Unable to open database: \(message)")
            return
        }
        catch {
            print("Another type of error happened: \(error)")
            return
        }
        
        // Creating the meal table
        do {
            try db?.createTable(table: Meal.self)
        }
        catch {
            print(db?.getError() ?? "db is nil")
        }
        
        n = 0 // Resets n before loading the calendar
        //print("view is loading")
        self.MyCollectionView.delegate = self
        self.MyCollectionView.dataSource = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Close the database when switching views
        db?.closeDatabase()
        n = 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return 25
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WeekCell", for: indexPath) as! WeekCollectionViewCell
        //it has been more than a week
        if n > 6{
            cell.layer.borderWidth = 0
            cell.Date.text = " "
            cell.MealName.text = " "
            cell.MealType.text = " "
            return cell
        }
        //set up to get the date
        let numYear = CurrentYear - 1970
        var leapYearsDays = Int(round(Double(numYear/4)))
        for index in 0...CurrentMonth{
            leapYearsDays += numOfDays[index]
        }
        let numDays = numYear * 365 + leapYearsDays + CurrentDay + n - 32
        let numHours = numDays * 24
        let numSeconds = numHours * 3600
        let numEndSeconds = numSeconds + 86399
        var tempMonth = CurrentMonth
        var tempDay = CurrentDay + n
        if tempDay > numOfDays[tempMonth]{
            tempDay = tempDay % numOfDays[tempMonth]
            tempMonth += 1
            if tempMonth > 11{
                tempMonth = 0
            }
        }
        //get the meals for the day
        if mealsInDateRangeQueue.isEmpty{
            var mealsInDateRange: [(String, Int32, String)] = []
            do {
                mealsInDateRange = (try db?.selectDateRange(numSeconds: numSeconds, numEndSeconds: numEndSeconds))!
            }
            catch {
                print(db?.getError() ?? "db is nil")
            }
            mealsInDateRangeQueue.append(contentsOf: mealsInDateRange)
        }
        
        cell.Date.text = month[tempMonth] + " " + String(tempDay)
        cell.layer.borderWidth = 0.5
        
        //there are no meals for the day return an empty cell
        if mealsInDateRangeQueue.isEmpty{
            print("there are no meals for ", month[tempMonth] + " " + String(tempDay))
            cell.MealName.text = " "
            cell.MealType.text = " "
            //go to next day
            n += 1
            return cell
        }
        
        //there are meals for the day fill the cell
        else{
            //save data from array
            let mealName = mealsInDateRangeQueue[0].0
            let mealDate = mealsInDateRangeQueue[0].1
            let mealType = mealsInDateRangeQueue[0].2
            
            //remove the item from the array
            mealsInDateRangeQueue.removeFirst(1)
            
            //fill the cell
            let tempDate = convertToDate(arg1: Int(mealDate))
            cell.Date.text = month[Calendar.current.component(.month, from: tempDate)-1] + " " + String(Calendar.current.component(.day, from: tempDate))
            cell.MealName.text = mealName
            cell.MealType.text = mealType
            print("DATE:", cell.Date.text ?? "", " NAME:", cell.MealName.text ?? "", " TYPE:", cell.MealType.text ?? "")
            if mealsInDateRangeQueue.isEmpty{
                //go to next day
                print("there are  more meals for ", month[tempMonth] + " " + String(tempDay))
                n += 1
            }
            else{
                print("there are no more meals for ", month[tempMonth] + " " + String(tempDay))
            }
            return cell
        //print("N = ",n)
        }
    }
    
    // Converts from Date format to Seconds since 1970-01-01 00:00:00
    private func convertFromDate(arg1:Date) -> Int {
        let date = arg1
        let seconds = date.timeIntervalSince1970
        return Int(seconds)
        
    }
    
    // Converts from seconds since 1970-01-01 00:00:00 to Date format
    private func convertToDate(arg1:Int) -> Date {
        let seconds = Double(arg1)
        let date = Date(timeIntervalSince1970: seconds)
        return date
    }
}
