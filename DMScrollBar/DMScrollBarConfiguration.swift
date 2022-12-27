extension DMScrollBar {
    public struct RoundedCorners: Equatable {
        public enum Radius: Equatable {
            /// Not rounded corners
            case notRounded
            /// Half of the view's height
            case rounded
            /// User defined corner radius
            case custom(CGFloat)
        }

        public enum Corner: CaseIterable, Equatable {
            case leftTop
            case leftBottom
            case rightTop
            case rightBottom
        }

        public let radius: Radius
        public let corners: [Corner]

        public static let notRounded = RoundedCorners(radius: .notRounded, corners: [])
        public static let roundedLeftCorners = RoundedCorners(radius: .rounded, corners: [.leftTop, .leftBottom])
        public static let allRounded = RoundedCorners(radius: .rounded, corners: Corner.allCases)
    }

    public struct Configuration: Equatable {
        public struct Indicator: Equatable {
            public let size: CGSize
            public let backgroundColor: UIColor
            public let insets: UIEdgeInsets
            public let insetsFollowsSafeArea: Bool
            public let image: UIImage?
            public let imageSize: CGSize
            public let rounderCorners: RoundedCorners

            /// - Parameters:
            ///   - size: Size of the scroll bar indicator, which is placed on the right side
            ///   - backgroundColor: Background color of the scroll bar indicator
            ///   - insets: Scroll bar indicator insets
            ///   - insetsFollowsSafeArea: Indicates if safe area insets should be taken into account
            ///   - image: Scroll bar image
            ///   - imageSize: Scroll bar image size
            ///   - rounderCorners: Scroll bar indicator corners which should be rounded
            public init(
                size: CGSize = CGSize(width: 34, height: 34),
                backgroundColor: UIColor = UIColor.defaultScrollBarBackground,
                insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                insetsFollowsSafeArea: Bool = true,
                image: UIImage? = UIImage(systemName: "calendar.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.systemBackground),
                imageSize: CGSize = CGSize(width: 20, height: 20),
                rounderCorners: RoundedCorners = .roundedLeftCorners
            ) {
                self.size = size
                self.backgroundColor = backgroundColor
                self.insets = insets
                self.insetsFollowsSafeArea = insetsFollowsSafeArea
                self.image = image
                self.imageSize = imageSize
                self.rounderCorners = rounderCorners
            }

            /// Default indicator configuration
            public static let `default` = Indicator()
        }

        public struct InfoLabel: Equatable {
            public let font: UIFont
            public let textColor: UIColor
            public let distanceToScrollIndicator: CGFloat
            public let backgroundColor: UIColor
            public let textInsets: UIEdgeInsets
            public let rounderCorners: RoundedCorners

            /// - Parameters:
            ///   - font: Indicates the font that should be used for info label, which appears during indicator scrolling
            ///   - textColor: Text color of the info label
            ///   - distanceToScrollIndicator: Horizontal distance from the info label to the scroll indicator
            ///   - backgroundColor: Background color of the info label
            ///   - textInsets: Indicates text insets from the info label to its background
            ///   - rounderCorners: Info label corenrs which should be rounded
            public init(
                font: UIFont = UIFont.systemFont(ofSize: 13),
                textColor: UIColor = UIColor.systemBackground,
                distanceToScrollIndicator: CGFloat = 40,
                backgroundColor: UIColor = UIColor.defaultScrollBarBackground,
                textInsets: UIEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10),
                rounderCorners: RoundedCorners = .allRounded
            ) {
                self.font = font
                self.textColor = textColor
                self.distanceToScrollIndicator = distanceToScrollIndicator
                self.backgroundColor = backgroundColor
                self.textInsets = textInsets
                self.rounderCorners = rounderCorners
            }

            /// Default info label configuration
            public static let `default` = InfoLabel()
        }

        public let isAlwaysVisible: Bool
        public let hideTimeInterval: TimeInterval
        public let indicator: Indicator
        public let infoLabel: InfoLabel

        /// - Parameters:
        ///   - isAlwaysVisible: Indicates if the scrollbar should always be visible
        ///   - hideTimeInterval: Number of seconds after which the scrollbar should be hidden after being inactive
        ///   - indicator: Scroll bar indicator configuration, which is placed on the right side
        ///   - infoLabel: Info label configuration, which appears during indicator scrolling
        public init(
            isAlwaysVisible: Bool = false,
            hideTimeInterval: TimeInterval = 2,
            indicator: Indicator = .default,
            infoLabel: InfoLabel = .default
        ) {
            self.isAlwaysVisible = isAlwaysVisible
            self.hideTimeInterval = hideTimeInterval
            self.indicator = indicator
            self.infoLabel = infoLabel
        }

        /// Default scroll bar configuration
        public static let `default` = Configuration()
    }
}
