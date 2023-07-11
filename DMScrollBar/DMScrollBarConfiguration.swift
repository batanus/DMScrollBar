import UIKit

extension DMScrollBar {
    public struct Configuration: Equatable {
        /// Indicates if the scrollbar should always be visible
        public let isAlwaysVisible: Bool

        /// Number of seconds after which the scrollbar should be hidden after being inactive
        public let hideTimeInterval: TimeInterval

        /// Indicates if scroll view should decelerate when ending scroll bar interaction with velocity
        public let shouldDecelerate: Bool

        /// Inficator configuration, which is placed on the right side
        public let indicator: Indicator
        
        /// Info label configuration, which appears during indicator scrolling. If nil - the info label will be hidden
        public let infoLabel: InfoLabel?

        /// - Parameters:
        ///   - isAlwaysVisible: Indicates if the scrollbar should always be visible
        ///   - hideTimeInterval: Number of seconds after which the scrollbar should be hidden after being inactive
        ///   - shouldDecelerate: Indicates if scroll view should decelerate when ending scroll bar interaction with velocity
        ///   - indicator: Scroll bar indicator configuration, which is placed on the right side
        ///   - infoLabel: Info label configuration, which appears during indicator scrolling. If passing nil - the info label will be hidden
        public init(
            isAlwaysVisible: Bool = false,
            hideTimeInterval: TimeInterval = 2,
            shouldDecelerate: Bool = true,
            indicator: Indicator = .default,
            infoLabel: InfoLabel? = .default
        ) {
            self.isAlwaysVisible = isAlwaysVisible
            self.hideTimeInterval = hideTimeInterval
            self.shouldDecelerate = shouldDecelerate
            self.indicator = indicator
            self.infoLabel = infoLabel
        }

        /// Default scroll bar configuration
        public static let `default` = Configuration()

        /// iOS native scroll bar style configuration
        public static let iosStyle = Configuration(
            indicator: .init(
                normalState: .iosStyle(width: 3),
                activeState: .custom(config: .iosStyle(width: 8)),
                animation: .defaultTiming(with: .fade)
            )
        )
    }
}

extension DMScrollBar.Configuration {
    public struct RoundedCorners: Equatable {
        /// Corner radius, which will be applied to all corners
        public let radius: Radius

        /// Set of corners that will be rounded
        public let corners: Set<Corner>

        /// - Parameters:
        ///   - radius: Corner radius, which will be applied to all corners
        ///   - corners: Set of corners that will be rounded
        public init(radius: Radius, corners: Set<Corner>) {
            self.radius = radius
            self.corners = corners
        }

        /// All corners will not be rounded
        public static let notRounded = RoundedCorners(radius: .notRounded, corners: [])

        /// Top left and bottom left corners will be rounded by a radius equal to half the view's height
        public static let roundedLeftCorners = RoundedCorners(radius: .rounded, corners: [.topLeft, .bottomLeft])

        /// Top right and bottom right corners will be rounded by a radius equal to half the view's height
        public static let roundedRightCorners = RoundedCorners(radius: .rounded, corners: [.topRight, .bottomRight])

        /// All corners will be rounded by a radius equal to half the view's height
        public static let allRounded = RoundedCorners(radius: .rounded, corners: Set(Corner.allCases))

        public enum Radius: Equatable {
            /// Not rounded corners
            case notRounded
            /// Half of the view's height
            case rounded
            /// User defined corner radius
            case custom(CGFloat)
        }

        public enum Corner: CaseIterable, Equatable {
            /// Represents the top left corner.
            case topLeft
            /// Represents the top right corner.
            case topRight
            /// Represents the bottom left corner.
            case bottomLeft
            /// Represents the bottom right corner.
            case bottomRight
        }
    }

    public enum AnimationType: Equatable {
        /// Alpha appearance / disappearance animation
        case fade
        /// Alpha & side appearance / disappearance animation
        case fadeAndSide
    }

    public struct Animation: Equatable {
        /// Time in seconds for the appearance animation to take place
        public let showDuration: TimeInterval

        /// Time in seconds for the disappearance animation to take place
        public let hideDuration: TimeInterval

        /// Animation type for appearance / disappearance
        public let animationType: AnimationType

        /// - Parameters:
        ///   - showDuration: Time in seconds for the appearance animation to take place
        ///   - hideDuration: Time in seconds for the disappearance animation to take place
        ///   - animationType: Animation type for appearance / disappearance
        public init(showDuration: TimeInterval, hideDuration: TimeInterval, animationType: AnimationType) {
            self.showDuration = showDuration
            self.hideDuration = hideDuration
            self.animationType = animationType
        }

        /// Default animation configuration
        public static var `default` = defaultTiming(with: .fadeAndSide)

        /// Animation with default timings and passed animation type
        public static func defaultTiming(with animationType: AnimationType) -> Animation {
            Animation(showDuration: 0.2, hideDuration: 0.4, animationType: animationType)
        }
    }

    public struct Indicator: Equatable {
        /// Configuration for indicator state while the user is not interacting with it
        public let normalState: StateConfig

        /// Configuration for indicator state while the user interacting with it
        public let activeState: ActiveStateConfig

        /// Time in seconds for the state change animation to take place
        public let stateChangeAnimationDuration: TimeInterval

        /// Indicates if safe area insets should be taken into account
        public let insetsFollowsSafeArea: Bool

        /// Scroll bar indicator show / hide animation settings
        public let animation: Animation

        /// Accessibility identifier of the indicator
        public let accessibilityIdentifier: String?

        /// - Parameters:
        ///   - normalState: Configuration for indicator state while the user is not interacting with it
        ///   - activeState: Configuration for indicator state while the user interacting with it
        ///   - stateChangeAnimationDuration: Time in seconds for the state change animation to take place
        ///   - insetsFollowsSafeArea: Indicates if safe area insets should be taken into account
        ///   - animation: Scroll bar indicator show / hide animation settings
        ///   - accessibilityIdentifier: Accessibility identifier of the indicator
        public init(
            normalState: StateConfig = .default,
            activeState: ActiveStateConfig = .unchanged,
            stateChangeAnimationDuration: TimeInterval = 0.3,
            insetsFollowsSafeArea: Bool = true,
            animation: Animation = .default,
            accessibilityIdentifier: String? = nil
        ) {
            self.normalState = normalState
            self.activeState = activeState
            self.stateChangeAnimationDuration = stateChangeAnimationDuration
            self.insetsFollowsSafeArea = insetsFollowsSafeArea
            self.animation = animation
            self.accessibilityIdentifier = accessibilityIdentifier
        }

        /// Default indicator configuration
        public static let `default` = Indicator()

        public struct StateConfig: Equatable {
            /// Size of the scroll bar indicator, which is placed on the right side
            public let size: CGSize

            /// Background color of the scroll bar indicator
            public let backgroundColor: UIColor

            /// Scroll bar indicator insets
            public let insets: UIEdgeInsets

            /// Scroll bar indicator content insets
            public let contentInsets: UIEdgeInsets

            /// Scroll bar image
            public let image: UIImage?

            /// Scroll bar image size
            public let imageSize: CGSize

            /// Accessibility identifier of the image
            public let imageAccessibilityIdentifier: String?

            /// Scroll bar indicator corners which should be rounded
            public let roundedCorners: RoundedCorners

            /// - Parameters:
            ///   - size: Size of the scroll bar indicator, which is placed on the right side
            ///   - backgroundColor: Background color of the scroll bar indicator
            ///   - insets: Scroll bar indicator insets
            ///   - contentInsets: Scroll bar indicator content insets
            ///   - image: Scroll bar image
            ///   - imageSize: Scroll bar image size. If a nil image is passed - this parameter is ignored
            ///   - imageAccessibilityIdentifier: Accessibility identifier of the image
            ///   - roundedCorners: Scroll bar indicator corners which should be rounded
            public init(
                size: CGSize = CGSize(width: 34, height: 34),
                backgroundColor: UIColor = UIColor.defaultScrollBarBackground,
                insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
                image: UIImage? = UIImage(systemName: "arrow.up.and.down.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.systemBackground),
                imageSize: CGSize = CGSize(width: 20, height: 20),
                imageAccessibilityIdentifier: String? = nil,
                roundedCorners: RoundedCorners = .roundedLeftCorners
            ) {
                self.size = size
                self.backgroundColor = backgroundColor
                self.insets = insets
                self.contentInsets = contentInsets
                self.image = image
                self.imageSize = imageSize
                self.imageAccessibilityIdentifier = imageAccessibilityIdentifier
                self.roundedCorners = roundedCorners
            }

            /// Default state configuration
            public static let `default` = StateConfig()

            /// iOS native style configuration for scroll bar indicator
            public static func iosStyle(width: CGFloat) -> StateConfig {
                StateConfig(
                    size: .init(width: width, height: 100),
                    backgroundColor: UIColor.label.withAlphaComponent(0.35),
                    insets: .init(top: 4, left: 0, bottom: 4, right: 2),
                    contentInsets: .zero,
                    image: nil,
                    roundedCorners: .allRounded
                )
            }
        }

        public enum ActiveStateConfig: Equatable {
            /// Use the same configuration as for normal state
            case unchanged
            /// Use the same configuration as for normal state but scaled with specified factor. F. e. factor = 1 will not scale indicator size, factor = 2 will scale indicator size by 2 times. If in normal state indicator size is 30x30, active state with scale factor = 2 will have size 60x60
            case scaled(factor: CGFloat)
            /// Use custom configuration for active state
            /// - Parameters:
            ///   - config: State configuration for indicator state while the user is interacting with it
            ///   - text: Scroll bar text config that appears to the right of the image
            case custom(config: StateConfig, textConfig: TextConfig? = nil)

            public struct TextConfig: Equatable {
                /// Text label insets from
                public let insets: UIEdgeInsets
                /// Font that should be used for text
                public let font: UIFont
                /// Text color of the label
                public let color: UIColor
                /// Accessibility identifier of the label
                public let accessibilityIdentifier: String?

                /// - Parameters:
                ///   - insets: Text label insets from
                ///   - font: Font that should be used for text
                ///   - color: Text color of the label
                ///   - accessibilityIdentifier: Accessibility identifier of the label
                public init(
                    insets: UIEdgeInsets,
                    font: UIFont,
                    color: UIColor,
                    accessibilityIdentifier: String? = nil
                ) {
                    self.insets = insets
                    self.font = font
                    self.color = color
                    self.accessibilityIdentifier = accessibilityIdentifier
                }
            }
        }
    }

    public struct InfoLabel: Equatable {
        /// Indicates the font that should be used for info label, which appears during indicator scrolling
        public let font: UIFont

        /// Text color of the info label
        public let textColor: UIColor

        /// Horizontal distance from the info label to the scroll indicator
        public let distanceToScrollIndicator: CGFloat

        /// Background color of the info label
        public let backgroundColor: UIColor

        /// Indicates text insets from the info label to its background
        public let textInsets: UIEdgeInsets

        /// Indicates maximum width of info label. If nil is passed - the info label will grow maximum to the leading side of the screen
        public let maximumWidth: CGFloat?

        /// Info label corenrs which should be rounded
        public let roundedCorners: RoundedCorners

        /// Info label show/hide animation settings
        public let animation: Animation

        /// Accessibility identifier of the info label
        public let accessibilityIdentifier: String?

        /// - Parameters:
        ///   - font: Indicates the font that should be used for info label, which appears during indicator scrolling
        ///   - textColor: Text color of the info label
        ///   - distanceToScrollIndicator: Horizontal distance from the info label to the scroll indicator
        ///   - backgroundColor: Background color of the info label
        ///   - textInsets: Indicates text insets from the info label to its background
        ///   - maximumWidth: Indicates maximum width of info label. If nil is passed - the info label will grow maximum to the leading side of the screen
        ///   - roundedCorners: Info label corenrs which should be rounded
        ///   - animation: Info label show/hide animation settings
        ///   - accessibilityIdentifier: Accessibility identifier of the info label
        public init(
            font: UIFont = UIFont.systemFont(ofSize: 13),
            textColor: UIColor = UIColor.systemBackground,
            distanceToScrollIndicator: CGFloat = 40,
            backgroundColor: UIColor = UIColor.defaultScrollBarBackground,
            textInsets: UIEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10),
            maximumWidth: CGFloat? = nil,
            roundedCorners: RoundedCorners = .allRounded,
            animation: Animation = .default,
            accessibilityIdentifier: String? = nil
        ) {
            self.font = font
            self.textColor = textColor
            self.distanceToScrollIndicator = distanceToScrollIndicator
            self.backgroundColor = backgroundColor
            self.textInsets = textInsets
            self.maximumWidth = maximumWidth
            self.roundedCorners = roundedCorners
            self.animation = animation
            self.accessibilityIdentifier = accessibilityIdentifier
        }

        /// Default info label configuration
        public static let `default` = InfoLabel()
    }
}
