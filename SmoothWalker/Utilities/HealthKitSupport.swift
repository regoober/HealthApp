/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A collection of utility functions used for general HealthKit purposes.
*/

import Foundation
import HealthKit

// MARK: Sample Type Identifier Support

/// Return an HKSampleType based on the input identifier that corresponds to an HKQuantityTypeIdentifier, HKCategoryTypeIdentifier
/// or other valid HealthKit identifier. Returns nil otherwise.
func getSampleType(for identifier: String) -> HKSampleType? {
    if let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier)) {
        return quantityType
    }
    
    if let categoryType = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier)) {
        return categoryType
    }
    
    return nil
}

// MARK: - Unit Support

/// Return the appropriate unit to use with an HKSample based on the identifier. Asserts for compatible units.
func preferredUnit(for sample: HKSample) -> HKUnit? {
    let unit = preferredUnit(for: sample.sampleType.identifier, sampleType: sample.sampleType)
    
    if let quantitySample = sample as? HKQuantitySample, let unit = unit {
        assert(quantitySample.quantity.is(compatibleWith: unit),
               "The preferred unit is not compatible with this sample.")
    }
    
    return unit
}

/// Returns the appropriate unit to use with an identifier corresponding to a HealthKit data type.
func preferredUnit(for sampleIdentifier: String) -> HKUnit? {
    return preferredUnit(for: sampleIdentifier, sampleType: nil)
}

private func preferredUnit(for identifier: String, sampleType: HKSampleType? = nil) -> HKUnit? {
    var unit: HKUnit?
    let sampleType = sampleType ?? getSampleType(for: identifier)
    
    if sampleType is HKQuantityType {
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: identifier)
        
        switch quantityTypeIdentifier {
        case .stepCount:
            unit = .count()
        case .distanceWalkingRunning, .sixMinuteWalkTestDistance:
            unit = .meter()
        case .walkingSpeed:
            unit = .meter().unitDivided(by: .second())
        default:
            break
        }
    }
    
    return unit
}

// MARK: - Query Support

/// Return an anchor date for a statistics collection query.
func createAnchorDate(dataInterval: DataInterval = .daily) -> Date {
    let calendar: Calendar = .current
    var anchorComponents: DateComponents!
    var date: Date
    switch dataInterval {
    case .daily:
        date = Date()
        anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: date)
        // Set the arbitrary anchor date to Monday
        let offset = (7 + (anchorComponents.weekday ?? 0) - 2) % 7
        
        anchorComponents.day! -= offset
        break
    case .weekly:
        date = getOneMonthAgoStartDate()
        anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: date)
        // Set the arbitrary anchor date to Sunday relative to given date
        let offset = (7 + (anchorComponents.weekday ?? 0) - 1) % 7
        
        anchorComponents.day! -= offset
        break
    case .monthly:
        date = getOneYearAgoStartDate()
        anchorComponents = calendar.dateComponents([.day, .month, .year], from: date)
        break
    }
    // set arbitrary time to 3:00 a.m. for all cases
    anchorComponents.hour = 3
    
    let anchorDate = calendar.date(from: anchorComponents)!
    
    return anchorDate
}

func getStartDate(for dataInterval: DataInterval = .daily) -> Date {
    switch dataInterval {
    case .daily:
        return Calendar.current.date(byAdding: .day, value: -1, to: getLastWeekStartDate())!
    case .weekly:
        return getOneMonthAgoStartDate()
    case .monthly:
        return getOneYearAgoStartDate()
    }
}

func getEndDate(for dataInterval: DataInterval = .daily) -> Date {
    var date = Date()
    switch dataInterval {
    case .daily:
        // average not calc on current day so end the day prior
        date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        return date
    case .weekly:
        date = Calendar.current.date(bySetting: .weekday, value: 7, of: date)!
        return date
    case .monthly:
        date = Calendar.current.date(bySetting: .day, value: 1, of: date)!
        date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        return date
    }
}

/// This is commonly used for date intervals so that we get the last seven days worth of data,
/// because we assume today (`Date()`) is providing data as well.
func getLastWeekStartDate(from date: Date = Date()) -> Date {
    return Calendar.current.date(byAdding: .day, value: -6, to: date)!
}
/// This is commonly used for date intervals so that we get the full week from the last 4 weeks worth of data,
/// because we assume today (`Date()`) is providing data as well.
func getOneMonthAgoStartDate(from date: Date = Date()) -> Date {
    var date = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: date)!
    // set start date to Sunday of that week
    date = Calendar.current.date(bySetting: .weekday, value: 1, of: date)!
    return date
}

func getOneYearAgoStartDate(from date: Date = Date()) -> Date {
    var date = Calendar.current.date(byAdding: .year, value: -1, to: date)!
    // set start date to 1st of that month
    date = Calendar.current.date(bySetting: .day, value: 1, of: date)!
    return date
}

func createIntervalDateComponents(dataInterval: DataInterval = .daily) -> DateComponents {
    switch dataInterval {
    case .daily:
        return DateComponents(day: 1)
    case .weekly:
        return DateComponents(weekOfYear: 1)
    case .monthly:
        return DateComponents(month: 1)
    }
}

func createIntervalPredicate(dataInterval: DataInterval = .daily, from endDate: Date = Date()) -> NSPredicate {
    switch dataInterval {
    case .daily:
        return createLastWeekPredicate(from: endDate)
    case .weekly:
        return createFiveWeeksPredicate(from: endDate)
    case .monthly:
        return createLastYearPredicate(from: endDate)
    }
}

func createLastWeekPredicate(from endDate: Date = Date()) -> NSPredicate {
    let startDate = getLastWeekStartDate(from: endDate)
    return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
}

func createFiveWeeksPredicate(from endDate: Date = Date()) -> NSPredicate {
    let startDate = getOneYearAgoStartDate(from: endDate)
    return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
}

func createLastYearPredicate(from endDate: Date = Date()) -> NSPredicate {
    let startDate = getOneYearAgoStartDate(from: endDate)
    return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
}

/// Return the most preferred `HKStatisticsOptions` for a data type identifier. Defaults to `.discreteAverage`.
func getStatisticsOptions(for dataTypeIdentifier: String) -> HKStatisticsOptions {
    var options: HKStatisticsOptions = .discreteAverage
    let sampleType = getSampleType(for: dataTypeIdentifier)
    
    if sampleType is HKQuantityType {
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)
        
        switch quantityTypeIdentifier {
        case .stepCount, .distanceWalkingRunning:
            options = .cumulativeSum
        case .sixMinuteWalkTestDistance, .walkingSpeed:
            options = .discreteAverage
        default:
            break
        }
    }
    
    return options
}

/// Return the statistics value in `statistics` based on the desired `statisticsOption`.
func getStatisticsQuantity(for statistics: HKStatistics, with statisticsOptions: HKStatisticsOptions) -> HKQuantity? {
    var statisticsQuantity: HKQuantity?
    
    switch statisticsOptions {
    case .cumulativeSum:
        statisticsQuantity = statistics.sumQuantity()
    case .discreteAverage:
        statisticsQuantity = statistics.averageQuantity()
    default:
        break
    }
    
    return statisticsQuantity
}
