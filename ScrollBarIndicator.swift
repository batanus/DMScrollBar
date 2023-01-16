final class ScrollBarIndicator: UIView {
    private var indicatorImageWidthConstraint: NSLayoutConstraint?
    private var indicatorImageHeightConstraint: NSLayoutConstraint?
    private var indicatorImageLabelStackViewLeadingConstraint: NSLayoutConstraint?
    private var indicatorImageLabelStackViewTrailingConstraint: NSLayoutConstraint?
    private var indicatorImage: UIImageView?
    private var indicatorLabel: UILabel?
    private var indicatorImageLabelStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    var isIndicatorLabelVisible: Bool {
        indicatorLabel?.alpha == 1 && indicatorLabel?.isHidden == false
    }

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

    func setup(
        stateConfig: DMScrollBar.Configuration.Indicator.StateConfig,
        textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        backgroundColor = stateConfig.backgroundColor
        layer.maskedCorners = stateConfig.roundedCorners.corners.cornerMask
        layer.cornerRadius = cornerRadius(
            from: stateConfig.roundedCorners.radius,
            viewSize: stateConfig.size
        )
        if indicatorImageLabelStackView.superview == nil {
            addSubview(indicatorImageLabelStackView)
            let centerX = indicatorImageLabelStackView.centerXAnchor.constraint(equalTo: centerXAnchor)
            centerX.priority = .init(999)
            centerX.isActive = true
            indicatorImageLabelStackView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        let defaultInset: CGFloat = 8
        let leadingInset: CGFloat = {
            guard let textConfig else { return 0 }
            return stateConfig.image == nil ? textConfig.insets.left : defaultInset
        }()
        setupConstraint(
            constraint: &indicatorImageLabelStackViewLeadingConstraint,
            build: { indicatorImageLabelStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: $0) },
            value: leadingInset
        )
        setupConstraint(
            constraint: &indicatorImageLabelStackViewTrailingConstraint,
            build: { trailingAnchor.constraint(equalTo: indicatorImageLabelStackView.trailingAnchor, constant: $0) },
            value: textConfig != nil ? textConfig?.insets.right ?? defaultInset : 0
        )
        setupIndicatorImageViewState(image: stateConfig.image, size: stateConfig.imageSize)
        setupIndicatorLabelState(config: textConfig)
    }

    func updateScrollIndicatorText(
        direction: CATransitionSubtype?,
        scrollBarLabelText: String?,
        textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        guard let scrollBarLabelText = scrollBarLabelText, textConfig != nil else { return hideIndicatorLabel() }
        if scrollBarLabelText == indicatorLabel?.text { return }
        indicatorLabel?.setup(text: scrollBarLabelText, direction: direction)
        indicatorImageLabelStackView.layoutIfNeeded()
        generateHapticFeedback(style: .light)
    }

    // MARK: - Private

    private func setupIndicatorImageViewState(image: UIImage?, size: CGSize) {
        buildIndicatorImageViewIfNeeded()
        if let image {
            indicatorImage?.isHidden = false
            indicatorImage?.alpha = 1
            indicatorImage?.image = image
            setupConstraint(
                constraint: &indicatorImageWidthConstraint,
                build: indicatorImage?.widthAnchor.constraint(equalToConstant:),
                value: size.width,
                priority: .init(999)
            )
            setupConstraint(
                constraint: &indicatorImageHeightConstraint,
                build: indicatorImage?.heightAnchor.constraint(equalToConstant:),
                value: size.height
            )
        } else {
            indicatorImage?.isHidden = true
            indicatorImage?.alpha = 0
        }
    }

    private func setupIndicatorLabelState(config: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?) {
        buildIndicatorLabelIfNeeded()
        if let config {
            showIndicatorLabel()
            indicatorLabel?.font = config.font
            indicatorLabel?.textColor = config.color
            indicatorImageLabelStackView.spacing = config.insets.left
        } else {
            hideIndicatorLabel()
        }
    }

    private func buildIndicatorImageViewIfNeeded() {
        guard indicatorImage == nil else { return }
        let imageView = UIImageView()
        indicatorImageLabelStackView.addArrangedSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        self.indicatorImage = imageView
    }

    private func buildIndicatorLabelIfNeeded() {
        guard indicatorLabel == nil else { return }
        let label = UILabel()
        indicatorImageLabelStackView.addArrangedSubview(label)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.indicatorLabel = label
    }

    private func showIndicatorLabel() {
        indicatorLabel?.alpha = 1
        indicatorLabel?.isHidden = false
    }

    private func hideIndicatorLabel() {
        indicatorLabel?.alpha = 0
        indicatorLabel?.isHidden = true
    }
}
