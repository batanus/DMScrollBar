import UIKit

public protocol DMScrollBarDelegate: AnyObject {
    /// This method is triggered every time when scroll bar offset changes while the user is dragging it
    /// - Parameter offset: Scroll view content offset
    /// - Returns: Indicator title to present in info label. If returning nil - the info label will not show
    func indicatorTitle(forOffset offset: CGFloat) -> String?
}

// MARK: - DMScrollBarDelegate extension for Table View

public extension DMScrollBarDelegate {
    /// This is a convenience method to get the header title for the section at the specified content offset. This method will not work for table views with custom headers
    /// - Parameters:
    ///   - tableView: Table view in which the scroll bar is located
    ///   - offset: Table View content offset
    /// - Returns: Indicator title to present in info label. If returning nil - the info label will not show
    func headerTitle(in tableView: UITableView, forOffset offset: CGFloat) -> String? {
        guard let section = sectionIndex(in: tableView, forOffset: offset) else { return nil }

        return tableView.dataSource?.tableView?(tableView, titleForHeaderInSection: section) ??
            tableView.headerView(forSection: section)?.textLabel?.text ??
            (tableView.headerView(forSection: section)?.contentConfiguration as? UIListContentConfiguration)?.text
    }

    /// This is a convenience method to get section index for specified table view content offset
    /// - Parameters:
    ///   - tableView: Table view in which the scroll bar is located
    ///   - offset: Table View content offset
    /// - Returns: Section index in table view for specified table view content offset
    func sectionIndex(in tableView: UITableView, forOffset offset: CGFloat) -> Int? {
        (0..<tableView.numberOfSections).first { section in
            let sectionRect = tableView.rect(forSection: section)
            let minY: CGFloat = section == 0 ? -.greatestFiniteMagnitude : sectionRect.minY
            let maxY: CGFloat = section == tableView.numberOfSections - 1 ? .greatestFiniteMagnitude : sectionRect.maxY
            return minY...maxY ~= offset
        }
    }
}
