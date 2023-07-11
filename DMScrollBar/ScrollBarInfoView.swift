import UIKit

final class ScrollBarInfoView: UIView {
    private let offsetLabel = UILabel()

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
    }

    func setup(config: DMScrollBar.Configuration.InfoLabel) {
        addSubview(offsetLabel)

        let textInsets = config.textInsets
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false
        offsetLabel.font = config.font
        offsetLabel.textColor = config.textColor
        offsetLabel.topAnchor.constraint(equalTo: topAnchor, constant: textInsets.top).isActive = true
        offsetLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -textInsets.bottom).isActive = true
        offsetLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textInsets.left).isActive = true
        offsetLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -textInsets.right).isActive = true
        offsetLabel.accessibilityIdentifier = config.accessibilityIdentifier

        backgroundColor = config.backgroundColor
        layer.maskedCorners = config.roundedCorners.corners.cornerMask
        layer.cornerRadius = cornerRadius(
            from: config.roundedCorners.radius,
            viewSize: CGSize(
                width: config.maximumWidth ?? CGFloat.greatestFiniteMagnitude,
                height: config.font.lineHeight + textInsets.top + textInsets.bottom
            )
        )

        alpha = 0
        clipsToBounds = true
    }

    func updateText(text: String, direction: CATransitionSubtype?) {
        if text == offsetLabel.text { return }
        offsetLabel.setup(text: text, direction: direction)
        layoutIfNeeded()
        generateHapticFeedback(style: .light)
    }
}
