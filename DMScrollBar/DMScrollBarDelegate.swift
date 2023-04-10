import UIKit

public protocol DMScrollBarDelegate: AnyObject {
    /// This method is triggered every time when scroll bar offset changes while the user is dragging it
    /// - Parameter contentOffset: Scroll view content offset
    /// - Parameter scrollIndicatorOffset: Scroll indicator offset
    /// - Returns: Text to present in info label (which appears during indicator scrolling to the left of the Scroll Bar) . If returning nil - the info label will not show
    func infoLabelText(forContentOffset contentOffset: CGFloat, scrollIndicatorOffset: CGFloat) -> String?

    /// This method is triggered every time when scroll bar offset changes while the user is dragging it
    /// - Parameter contentOffset: Scroll view content offset
    /// - Parameter scrollIndicatorOffset: Scroll indicator offset
    /// - Returns: Text to present in scroll bar label. This method is not triggered when Configuration.Indicator.StateConfig.TextConfig is nil.
    func scrollBarText(forContentOffset contentOffset: CGFloat, scrollIndicatorOffset: CGFloat) -> String?
}

// MARK: - DMScrollBarDelegate extension for Table View

public extension DMScrollBarDelegate {
    func infoLabelText(forContentOffset contentOffset: CGFloat, scrollIndicatorOffset: CGFloat) -> String? { nil }

    func scrollBarText(forContentOffset contentOffset: CGFloat, scrollIndicatorOffset: CGFloat) -> String? { nil }

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

    /// This is a convenience method to get section index for specified collection view content offset
    /// - Parameters:
    ///   - collectionView: Collection view in which the scroll bar is located
    ///   - offset: Collection View content offset
    /// - Returns: Section index in collection view for specified collection view content offset
    func sectionIndex(in collectionView: UICollectionView, forOffset offset: CGFloat) -> Int? {
        (0..<collectionView.numberOfSections).first { section in
            guard let currentSectionOrigin = headerOrigin(in: collectionView, atSection: section) else { return false }
            let nextSectionOrigin = headerOrigin(in: collectionView, atSection: section + 1)
            let sectionHeight = (nextSectionOrigin?.y ?? .greatestFiniteMagnitude) - currentSectionOrigin.y
            let sectionSize = CGSize(width: collectionView.frame.width, height: sectionHeight)
            let sectionRect = CGRect(origin: currentSectionOrigin, size: sectionSize)
            let minY: CGFloat = section == 0 ? -.greatestFiniteMagnitude : sectionRect.minY
            let maxY: CGFloat = section == collectionView.numberOfSections - 1 ?
                .greatestFiniteMagnitude :
                sectionRect.maxY

            return minY...maxY ~= offset
        }
    }

    // MARK: - Private

    private func headerOrigin(in collectionView: UICollectionView, atSection section: Int) -> CGPoint? {
        let indexPath = IndexPath(item: 0, section: section)
        let kind = UICollectionView.elementKindSectionHeader
        guard isValid(indexPath: indexPath, in: collectionView) else { return nil }
        guard let attributes = collectionView.layoutAttributesForSupplementaryElement(
            ofKind: kind,
            at: indexPath
        ) else { return nil }

        return attributes.frame.origin
    }

    private func isValid(indexPath: IndexPath, in collectionView: UICollectionView) -> Bool {
        guard indexPath.section < collectionView.numberOfSections else { return false }
        let numberOfItems = collectionView.numberOfItems(inSection: indexPath.section)

        return indexPath.row < numberOfItems || numberOfItems == 0
    }
}
