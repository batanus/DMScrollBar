import UIKit
import DMScrollBar

struct Section {
    let title: String
    let items: [String]
}

final class ViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    private var sections = [Section]()
    private let headerDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupSections()
        title = "DMScrollBar"
    }

    private func setupTableView() {
        let defaultConfig = DMScrollBar.Configuration.default
        let iosStyleConfig = DMScrollBar.Configuration.iosStyle
        let iosCombinedDefaultConfig = DMScrollBar.Configuration(
            indicator: .init(
                normalState: .iosStyle(width: 3),
                activeState: .init(backgroundColor: .green)
            )
        )
        let customConfig = DMScrollBar.Configuration(
            isAlwaysVisible: false,
            hideTimeInterval: 1.5,
            indicator: DMScrollBar.Configuration.Indicator(
                normalState: .init(
                    size: CGSize(width: 35, height: 35),
                    backgroundColor: UIColor.brown.withAlphaComponent(0.8),
                    insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                    image: UIImage(systemName: "arrow.up.and.down.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.white),
                    imageSize: CGSize(width: 20, height: 20),
                    roundedCorners: .roundedLeftCorners
                ),
                activeState: .init(
                    size: CGSize(width: 50, height: 50),
                    backgroundColor: UIColor.brown,
                    insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 6),
                    image: UIImage(systemName: "arrow.up.and.down.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.cyan),
                    imageSize: CGSize(width: 28, height: 28),
                    roundedCorners: .allRounded
                ),
                insetsFollowsSafeArea: true,
                animation: .init(showDuration: 0.75, hideDuration: 0.75, animationType: .fade)
            ),
            infoLabel: DMScrollBar.Configuration.InfoLabel(
                font: .systemFont(ofSize: 15),
                textColor: .white,
                distanceToScrollIndicator: 40,
                backgroundColor: .brown,
                textInsets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                maximumWidth: 300,
                roundedCorners: .init(radius: .rounded, corners: [.topLeft, .bottomRight]),
                animation: .init(showDuration: 0.75, hideDuration: 0.75, animationType: .fadeAndSide)
            )
        )
        tableView.dataSource = self
        tableView.contentInset.top = 16
        tableView.configureScrollBar(with: .default, delegate: self)
    }

    private func setupSections() {
        sections = (0..<20).map { sectionNumber in
            Section(
                title: headerDateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(86400 * sectionNumber))),
                items: (0..<10).map { "Item #\($0)" }
            )
        }
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = sections[indexPath.section].items[indexPath.item]
        cell.contentConfiguration = configuration

        return cell
    }
}

extension ViewController: DMScrollBarDelegate {
    /// In this example, this method returns the section header title for the top visible section
    func indicatorTitle(forOffset offset: CGFloat) -> String? {
        guard let section = (0..<tableView.numberOfSections).first(where: { section in
            let sectionRect = tableView.rect(forSection: section)
            let minY: CGFloat = section == 0 ? -.greatestFiniteMagnitude : sectionRect.minY
            let maxY: CGFloat = section == tableView.numberOfSections - 1 ? .greatestFiniteMagnitude : sectionRect.maxY
            return minY...maxY ~= offset
        }) else { return nil }

        return tableView(tableView, titleForHeaderInSection: section)
    }
}
