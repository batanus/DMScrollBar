# DMScrollBar

[![CI Status](https://img.shields.io/travis/batanus/DMScrollBar.svg?style=flat)](https://travis-ci.org/batanus/DMScrollBar)
[![Version](https://img.shields.io/cocoapods/v/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)
[![License](https://img.shields.io/cocoapods/l/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)
[![Platform](https://img.shields.io/cocoapods/p/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

DMScrollBar is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DMScrollBar', '~> 1.0.0'
```
and run 

```ruby
pod install
```

## Usage

On any ScrollView you want to add the ScrollBar with default configuration, just call:
```swift
scrollView.configureScrollBar()
```


If you want to provide title for info label, implement `DMScrollBarDelegate` protocol on your ViewController:
```swift
extension ViewController: DMScrollBarDelegate {
    /// In this example, this method returns the section header title for the top visible section
    func indicatorTitle(forOffset offset: CGFloat) -> String? {
        return "Your title for info label"
    }
}
```


If you want to have iOS style scroll bar, configure ScrollBar with `.iosStyle` config (_Next code will create config for the Scroll Bar for Gif #2_):
```swift
scrollView.configureScrollBar(with: .iosStyle, delegate: self)
```


Any ScrollBar configuration can be easily combined with another one (_Next code will create config for the Scroll Bar for Gif #3_):
```swift
let iosCombinedDefaultConfig = DMScrollBar.Configuration(
    indicator: .init(
        normalState: .iosStyle(width: 3),
        activeState: .default
    )
)
scrollView.configureScrollBar(with: iosCombinedDefaultConfig, delegate: self)
```


If you want to configure scroll bar, with custom config, create configuration and call `configureScrollBar` (_Next code will create config for the Scroll Bar for Gif #4_):
```swift
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
)
scrollView.configureScrollBar(with: customConfig, delegate: self)
```

## Author

Dmitrii Medvedev, dima7711@gmail.com

## License

DMScrollBar is available under the MIT license. See the LICENSE file for more info.
