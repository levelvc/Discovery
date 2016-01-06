//
//  DateUtils.swift
//  ConnectedColors
//
//  Created by ALBERT AZOUT on 12/29/15.
//  Copyright © 2015 Ralf Ebert. All rights reserved.
//

import Foundation

public extension NSDate {
    
    class func dateFromISOString(string: String) -> NSDate {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"        
        return dateFormatter.dateFromString(string)!
    }

    var formattedISO8601: String {
        let formatter = NSDateFormatter()
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'hh:mm:SSxxxxx"   //+00:00
        return formatter.stringFromDate(self)
    }
    
}