extension DMScrollBar {
    public struct Configuration: Equatable {
        public struct Indicator: Equatable {
            public let size: CGSize
            public let backgroundColor: UIColor
            public let insets: UIEdgeInsets
            public let insetsFollowsSafeArea: Bool
            public let image: UIImage?
            public let imageSize: CGSize

            public init(
                size: CGSize = CGSize(width: 34, height: 34),
                backgroundColor: UIColor = UIColor.systemGray,
                insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                insetsFollowsSafeArea: Bool = true,
                image: UIImage? = UIImage(systemName: "calendar.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.systemBackground),
                imageSize: CGSize = CGSize(width: 20, height: 20)
            ) {
                self.size = size
                self.backgroundColor = backgroundColor
                self.insets = insets
                self.insetsFollowsSafeArea = insetsFollowsSafeArea
                self.image = image
                self.imageSize = imageSize
            }

            public static let `default` = Indicator()
        }

        public struct InfoLabel: Equatable {
            public let font: UIFont
            public let textColor: UIColor
            public let distanceToScrollIndicator: CGFloat
            public let backgroundColor: UIColor
            public let textInsets: UIEdgeInsets

            public init(
                font: UIFont = UIFont.systemFont(ofSize: 13),
                textColor: UIColor = UIColor.systemBackground,
                distanceToScrollIndicator: CGFloat = 40,
                backgroundColor: UIColor = UIColor.systemGray,
                textInsets: UIEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            ) {
                self.font = font
                self.textColor = textColor
                self.distanceToScrollIndicator = distanceToScrollIndicator
                self.backgroundColor = backgroundColor
                self.textInsets = textInsets
            }

            public static let `default` = InfoLabel()
        }

        public let isAlwaysVisible: Bool
        public let hideTimeInterval: TimeInterval
        public let indicator: Indicator
        public let infoLabel: InfoLabel

        public init(
            isAlwaysVisible: Bool = true,
            hideTimeInterval: TimeInterval = 2,
            indicator: Indicator = .default,
            infoLabel: InfoLabel = .default
        ) {
            self.isAlwaysVisible = isAlwaysVisible
            self.hideTimeInterval = hideTimeInterval
            self.indicator = indicator
            self.infoLabel = infoLabel
        }

        public static let `default` = Configuration()
    }
}
