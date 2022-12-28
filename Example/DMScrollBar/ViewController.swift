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
        let sectionHeaderTitle = tableView(tableView, titleForHeaderInSection: section)

        return sectionHeaderTitle
    }
}
