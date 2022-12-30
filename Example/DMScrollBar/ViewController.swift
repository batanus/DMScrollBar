import UIKit
import DMScrollBar

struct Section {
    let title: String
    let items: [String]
}

final class ViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var configsButton: UIButton!
    @IBOutlet private var statesStackView: UIStackView!
    @IBOutlet private var stackViewLeading: NSLayoutConstraint!
    @IBOutlet private var configsButtonLeading: NSLayoutConstraint!

    private var exampleStates: [(name: String, config: DMScrollBar.Configuration)] = [
        ("Default", DMScrollBar.Configuration.default),
        ("iOS", DMScrollBar.Configuration.iosStyle),
        ("Combined", DMScrollBar.Configuration(
            indicator: .init(
                normalState: .iosStyle(width: 3),
                activeState: .custom(config: .default)
            )
        )),
        ("Custom", DMScrollBar.Configuration(
            isAlwaysVisible: false,
            hideTimeInterval: 1.5,
            shouldDecelerate: false,
            indicator: DMScrollBar.Configuration.Indicator(
                normalState: .init(
                    size: CGSize(width: 35, height: 35),
                    backgroundColor: UIColor(red: 200 / 255, green: 150 / 255, blue: 80 / 255, alpha: 1),
                    insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                    image: UIImage(systemName: "arrow.up.and.down.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.white),
                    imageSize: CGSize(width: 20, height: 20),
                    roundedCorners: .roundedLeftCorners
                ),
                activeState: .custom(config: .init(
                    size: CGSize(width: 50, height: 50),
                    backgroundColor: UIColor.brown,
                    insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 6),
                    image: UIImage(systemName: "calendar.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.cyan),
                    imageSize: CGSize(width: 28, height: 28),
                    roundedCorners: .allRounded
                )),
                insetsFollowsSafeArea: true,
                animation: .init(showDuration: 0.75, hideDuration: 0.75, animationType: .fadeAndSide)
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
        ))
    ]
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
        setupStateButtons()
        setupConfigsButton()
        setupScrollBarConfig(exampleStates[0].config)
        title = "DMScrollBar"
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.contentInset.top = 16
    }

    private func setupStateButtons() {
        exampleStates.enumerated().forEach { offset, item in
            let button = UIButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(item.name, for: .normal)
            button.setTitleColor(.systemBackground, for: .normal)
            button.backgroundColor = UIColor(white: 0.7, alpha: 1)
            button.layer.cornerRadius = 20
            button.contentEdgeInsets = .init(top: 0, left: 8, bottom: 0, right: 8)
            button.addAction(UIAction { _ in self.handleStateButtonTap(item.config) }, for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            statesStackView.addArrangedSubview(button)
        }
    }

    private func handleStateButtonTap(_ config: DMScrollBar.Configuration) {
        hideStateButtons()
        setupScrollBarConfig(config)
    }

    private func showStateButtons() {
        animate {
            self.stackViewLeading.constant = 16
            self.configsButtonLeading.constant = -50
            self.view.layoutIfNeeded()
        }
    }

    private func hideStateButtons() {
        animate {
            self.stackViewLeading.constant = -100
            self.configsButtonLeading.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    private func animate(duration: CGFloat = 0.3, animation: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
            animations: animation
        )
    }

    private func setupConfigsButton() {
        configsButton.layer.cornerRadius = 25
        configsButton.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        configsButton.setTitle("", for: .normal)
        configsButton.backgroundColor = UIColor(white: 0.7, alpha: 1)
        configsButton.addAction(UIAction { _ in self.showStateButtons() }, for: .touchUpInside)
        configsButton.setImage(
            UIImage(systemName: "arrow.forward.circle")?
                .withRenderingMode(.alwaysOriginal)
                .withTintColor(.systemBackground),
            for: .normal
        )
    }

    private func setupScrollBarConfig(_ config: DMScrollBar.Configuration) {
        tableView.configureScrollBar(with: config, delegate: self)
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
        headerTitle(in: tableView, forOffset: offset)
    }
}
