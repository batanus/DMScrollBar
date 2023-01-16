extension DMScrollBar.Configuration.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        switch self {
        case .topLeft: return .layerMinXMinYCorner
        case .bottomLeft: return .layerMinXMaxYCorner
        case .topRight: return .layerMaxXMinYCorner
        case .bottomRight: return .layerMaxXMaxYCorner
        }
    }
}

extension DMScrollBar.Configuration.Indicator.StateConfig {
    func applying(scaleFactor: CGFloat) -> DMScrollBar.Configuration.Indicator.StateConfig {
        .init(
            size: CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor),
            backgroundColor: backgroundColor,
            insets: insets,
            image: image,
            imageSize: CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor),
            roundedCorners: roundedCorners
        )
    }
}

extension DMScrollBar.Configuration.Indicator.ActiveStateConfig {
    var textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig? {
        switch self {
        case .custom(_, let textConfig): return textConfig
        default: return nil
        }
    }
}
