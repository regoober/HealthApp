//
//  IntervalAverageWalkSpeedReportsViewController.swift
//  SmoothWalker
//
//  Created by Brian Goo on 3/27/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit
import HealthKit

class IntervalAverageWalkSpeedReportsViewController: HealthQueryTableViewController {
    /// The date from the latest server response.
    private var dateLastUpdated: Date?
    
    let calendar: Calendar = .current
    let healthStore = HealthData.healthStore
    
    var quantityTypeIdentifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)
    }
    
    var quantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: quantityTypeIdentifier)!
    }
    
    var query: HKStatisticsCollectionQuery?
    
    // MARK: Initializers
    
    init(dataInterval: DataInterval = .daily) {
        super.init(dataTypeIdentifier: HKQuantityTypeIdentifier.walkingSpeed.rawValue, dataInterval: dataInterval)
        supportsMultipleIntervals = true
        // Set interval predicate
        queryPredicate = createIntervalPredicate(dataInterval: dataInterval)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Life Cycle Overrides
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
            // Authorization
        if !dataValues.isEmpty { return }
        
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [dataTypeIdentifier]) { (success) in
            if success {
                // Perform the query and reload the data.
                self.loadData()
            }
        }
    }
    
    // MARK: - Selector Overrides
    
    @objc
    override func didTapFetchButton() {
        Network.pull() { [weak self] (serverResponse) in
            self?.dateLastUpdated = serverResponse.date
            self?.queryPredicate = createIntervalPredicate(dataInterval: self?.dataInterval ?? .daily)
            self?.handleServerResponse(serverResponse)
        }
    }
    
    // MARK: - Network

    /// Handle a response fetched from a remote server. This function will also save any HealthKit samples and update the UI accordingly.
    override func handleServerResponse(_ serverResponse: ServerResponse) {
        let avgWalkSpeeds = serverResponse.avgWalkSpeeds
        let addedSamples = avgWalkSpeeds.samples.map { (serverHealthSample) -> HKQuantitySample in
            
            // Set the sync identifier and version
            var metadata = [String: Any]()
            let sampleSyncIdentifier = String(format: "%@_%@", avgWalkSpeeds.identifier, serverHealthSample.syncIdentifier)
            
            metadata[HKMetadataKeySyncIdentifier] = sampleSyncIdentifier
            metadata[HKMetadataKeySyncVersion] = serverHealthSample.syncVersion
            
            // Create HKQuantitySample
            let quantity = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: serverHealthSample.value)
            let sampleType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed)!
            let quantitySample = HKQuantitySample(type: sampleType,
                                                  quantity: quantity,
                                                  start: serverHealthSample.startDate,
                                                  end: serverHealthSample.endDate,
                                                  metadata: metadata)
            
            return quantitySample
        }
        
        HealthData.healthStore.save(addedSamples) { (success, error) in
            if success {
                self.loadData()
            }
        }
    }
    
    // MARK: Function Overrides
    
    override func performQuery(completion: @escaping () -> Void) {
        let predicate = createIntervalPredicate(dataInterval: dataInterval)
        let anchorDate = createAnchorDate(dataInterval: dataInterval)
        let intervalDateComps = createIntervalDateComponents(dataInterval: dataInterval)
        let statisticsOptions = getStatisticsOptions(for: dataTypeIdentifier)
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: statisticsOptions,
                                                anchorDate: anchorDate,
                                                intervalComponents: intervalDateComps)
        
        // The handler block for the HKStatisticsCollection object.
        let updateInterfaceWithStatistics: (HKStatisticsCollection) -> Void = { statisticsCollection in
            self.dataValues = []
            
            let startDate = getStartDate(for: self.dataInterval)
            let endDate = getEndDate(for: self.dataInterval)
            
            statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { [weak self] (statistics, stop) in
                var dataValue = HealthDataTypeValue(startDate: statistics.startDate,
                                                    endDate: statistics.endDate,
                                                    value: 0)
                
                if let quantity = getStatisticsQuantity(for: statistics, with: statisticsOptions),
                   let identifier = self?.dataTypeIdentifier,
                   let unit = preferredUnit(for: identifier) {
                    dataValue.value = quantity.doubleValue(for: unit)
                }
                
                self?.dataValues.append(dataValue)
            }
            
            completion()
        }
        
        query.initialResultsHandler = { query, statisticsCollection, error in
            if let statisticsCollection = statisticsCollection {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        query.statisticsUpdateHandler = { [weak self] query, statistics, statisticsCollection, error in
            // Ensure we only update the interface if the visible data type is updated
            if let statisticsCollection = statisticsCollection, query.objectType?.identifier == self?.dataTypeIdentifier {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        self.healthStore.execute(query)
        self.query = query
    }
    
    override func reloadData() {
        super.reloadData()
        
        DispatchQueue.main.async {
            // Change horizontal axis labels for avg walking speed
            switch (self.dataInterval) {
            case .daily:
                self.chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers(weekdayOffset: -1) // offset to remove today as last axis marker
                break
            case .weekly:
                self.chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers(for: self.dataValues.map { $0.startDate }, dataInterval: self.dataInterval).reversed()
                break
            case .monthly:
                self.chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers(for: self.dataValues.map { $0.startDate }, dataInterval: self.dataInterval).reversed()
                break
            }
            
            if let dateLastUpdated = self.dateLastUpdated {
                self.chartView.headerView.detailLabel.text = createChartDateLastUpdatedLabel(dateLastUpdated)
            }
        }
    }
}
