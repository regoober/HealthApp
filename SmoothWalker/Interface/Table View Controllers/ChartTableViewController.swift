/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A table view controller that displays health data with a chart header view.
*/

import UIKit
import CareKitUI
import HealthKit

private extension CGFloat {
    static let inset: CGFloat = 20
    static let itemSpacing: CGFloat = 12
    static let itemSpacingWithTitle: CGFloat = 0
}

/// A `DataTableViewController` with a chart header view.
class ChartTableViewController: DataTableViewController {
    var supportsMultipleIntervals: Bool = false
    
    // MARK: - UI Properties
    
    lazy var headerView: UIView = {
        let view = UIView()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
        
    lazy var chartView: OCKCartesianChartView = {
        let chartView = OCKCartesianChartView(type: .bar)
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.applyHeaderStyle()
        
        return chartView
    }()
    
    static let segmentItems = ["Daily", "Weekly", "Monthly"]
    lazy var segmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: Self.segmentItems)
        segmentedControl.selectedSegmentIndex = 0
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        return segmentedControl
    }()
    
    // MARK: - View Life Cycle Overrides
    
    override func updateViewConstraints() {
        chartViewBottomConstraint?.constant = showGroupedTableViewTitle ? .itemSpacingWithTitle : .itemSpacing
        
        super.updateViewConstraints()
    }
    
    override func setUpViewController() {
        super.setUpViewController()
        
        setUpHeaderView()
        setUpConstraints()
    }
    
    override func setUpTableView() {
        super.setUpTableView()
        
        showGroupedTableViewTitle = true
    }
    
    private func setUpHeaderView() {
        if supportsMultipleIntervals {
            headerView.addSubview(segmentedControl)
        }
        headerView.addSubview(chartView)
        
        tableView.tableHeaderView = headerView
    }

    private func setUpConstraints() {
        var constraints: [NSLayoutConstraint] = []
        
        constraints += createHeaderViewConstraints()
        if supportsMultipleIntervals {
            constraints += createSegmentViewConstraints()
        }
        constraints += createChartViewConstraints()
        
        NSLayoutConstraint.activate(constraints)
    }
    
    private func createHeaderViewConstraints() -> [NSLayoutConstraint] {
        let leading = headerView.leadingAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.leadingAnchor, constant: .inset)
        let trailing = headerView.trailingAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.trailingAnchor, constant: -.inset)
        let top = headerView.topAnchor.constraint(equalTo: tableView.topAnchor, constant: .itemSpacing)
        let centerX = headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor)
        
        return [leading, trailing, top, centerX]
    }
    
    private func createSegmentViewConstraints() -> [NSLayoutConstraint] {
        let leading = segmentedControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor)
        let top = segmentedControl.topAnchor.constraint(equalTo: headerView.topAnchor)
        let trailing = segmentedControl.trailingAnchor.constraint(equalTo: headerView.trailingAnchor)
        let bottomConstant: CGFloat = .itemSpacing
        let bottom = segmentedControl.bottomAnchor.constraint(equalTo: chartView.topAnchor, constant: bottomConstant)
        
        chartViewBottomConstraint = bottom
        
        // increase priorities to override when visible
        top.priority -= 1
        bottom.priority -= 1
        
        return [leading, top, trailing, bottom]
    }
    
    private var chartViewBottomConstraint: NSLayoutConstraint?
    private func createChartViewConstraints() -> [NSLayoutConstraint] {
        let leading = chartView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor)
        let top = supportsMultipleIntervals
                    ? chartView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: .itemSpacing)
                    : chartView.topAnchor.constraint(equalTo: headerView.topAnchor)
        let trailing = chartView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor)
        let bottomConstant: CGFloat = showGroupedTableViewTitle ? .itemSpacingWithTitle : .itemSpacing
        let bottom = chartView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -bottomConstant)
        
        chartViewBottomConstraint = bottom
        
        trailing.priority -= 1
        bottom.priority -= 1

        return [leading, top, trailing, bottom]
    }
}
