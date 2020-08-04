//
//  Date+Extensions.swift
//  StreamChatCore
//
//  Created by Alexey Bukhtin on 04/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation

extension Date {
    
    /// Checks if the date if today.
    public var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Checks if the date if yesterday.
    public var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
}

extension Date {
    /// A yesterday title for a status separartor.
    public static var yesterday = "Yesterday"
    
    public static let XUnitsAgo = NSLocalizedString("%d%@ ago", comment: "States how long ago event happen")
    public static let YearUnit = NSLocalizedString("y", comment: "One character abbreviation of year")
    public static let DayUnit = NSLocalizedString("d", comment: "One character abbreviation of day")
    public static let HourUnit = NSLocalizedString("h", comment: "One character abbreviation of hour")
    public static let MinuteUnit = NSLocalizedString("m", comment: "One character abbreviation of minute")
    public static let Now = NSLocalizedString("Now", comment: "Indicates that it happened in the last moments")
    
    /// A words separator for day and time.
    public static var wordsSeparator = ", "
    
    /// A relative date from the current time in string.
    public var relative: String {
        let timeString = DateFormatter.time.string(from: self)
        
        if isToday {
            return timeString
        }
        
        if isYesterday {
            return Date.yesterday.appending(Date.wordsSeparator).appending(timeString)
        }
        
        if timeIntervalSinceNow > -518_400 {
            return DateFormatter.weekDay.string(from: self).appending(Date.wordsSeparator).appending(timeString)
        }
        
        return DateFormatter.shortDate.string(from: self).appending(Date.wordsSeparator).appending(timeString)
    }
    
    /// Generates a filename from the date.
    public var fileName: String {
        return DateFormatter.fileName.string(from: self)
    }
    
    /// Check if a time interval between dates is less then a given time interval.
    ///
    /// - Parameters:
    ///   - timeInterval: a required time interval.
    ///   - date: a date for comparing.
    /// - Returns: a logical comparison result.
    public func isLessThan(timeInterval: TimeInterval, with date: Date) -> Bool {
        return abs(timeIntervalSinceNow - date.timeIntervalSinceNow) < timeInterval
    }
    
    public var numberOfUnitsFromToday: String {
        let timeInterval = abs(self.timeIntervalSinceNow)
        let timeElapsed: Int
        let unitString: String
        
        switch timeInterval {
        case .year...:
            timeElapsed = Int(timeInterval / .year)
            unitString = Date.YearUnit
            
        // "days will begin at the 49th hour and continue until a year is hit
        case (49 * .hour )...:
            timeElapsed = Int(timeInterval / .day)
            unitString = Date.DayUnit
            
        case .hour...:
            timeElapsed = Int(timeInterval / .hour)
            unitString = Date.HourUnit
            
        case .minute...:
            timeElapsed = Int(timeInterval / .minute)
            unitString = Date.MinuteUnit
            
        default:
            return Date.Now.lowercased()
        }
        
        return String(format: Date.XUnitsAgo, arguments: [timeElapsed, unitString])
    }
    
}

extension DateFormatter {
    
    /// A short time formatter from the date.
    public static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    /// A short date and time formatter from the date.
    public static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
    
    /// A short date and time formatter from the date.
    public static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return formatter
    }()

    /// A week formatter from the date.
    public static let weekDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    static let fileName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HHmmss"
        return formatter
    }()
}

extension TimeInterval {
    static let year: TimeInterval = 365 * .day
    static let month: TimeInterval = 30 * .day
    static let day: TimeInterval = 24 * .hour
    static let hour: TimeInterval = 60 * .minute
    static let minute: TimeInterval = 60
    
    func hasPassed(since: TimeInterval) -> Bool {
        return Date().timeIntervalSinceReferenceDate - self > since
    }
}
