# DMScrollBar

[![CI Status](https://img.shields.io/travis/batanus/DMScrollBar.svg?style=flat)](https://travis-ci.org/batanus/DMScrollBar)
[![Version](https://img.shields.io/cocoapods/v/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)
[![License](https://img.shields.io/cocoapods/l/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)
[![Platform](https://img.shields.io/cocoapods/p/DMScrollBar.svg?style=flat)](https://cocoapods.org/pods/DMScrollBar)

## Example
iOS style | Default style | iOS & Default combined style  | Absolutely custom style | Easy to change
:-: | :-: | :-: | :-: | :-:
| <img width="170" src="https://user-images.githubusercontent.com/25244017/209937427-7274d753-c4f1-45f8-93be-659b7d3b4434.gif"> | <img width="170" src="https://user-images.githubusercontent.com/25244017/209937470-d76a558c-6350-4d96-a142-13a6ef32e0f8.gif"> | <img width="170" src="https://user-images.githubusercontent.com/25244017/209937479-e7acbbd1-fba1-4fa8-a34f-9bb4b3ee790e.gif"> | <img width="170" src="https://user-images.githubusercontent.com/25244017/209937494-f61232a5-319a-4f88-abaf-b9340105746a.gif"> | <img width="170" src="https://user-images.githubusercontent.com/25244017/209937517-be2e6f54-53f9-447d-ad38-4fab39624551.gif">



## Description 

DMScrollBar is best in class customizable ScrollBar for ScrollView. It has: 
- Showing info label when user interaction with ScrollBar is started
- Decelerating & Bounce mechanism 
- Super customizable configuration
- Different states for active / inactive states
- Haptic feedback on interaction start / end and when info label changes on specified offset
- Super Fancy animations


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

On any ScrollView you want to add the ScrollBar with default configuration, just call (see result on Gid #2):
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


If you want to have iOS style scroll bar, configure ScrollBar with `.iosStyle` config (_Next code will create config for the Scroll Bar for Gif #1_):
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
    shouldDecelerate: true,
    indicator: DMScrollBar.Configuration.Indicator(
        normalState: .init(
            size: CGSize(width: 35, height: 35),
            backgroundColor: UIColor(red: 200 / 255, green: 150 / 255, blue: 80 / 255, alpha: 1),
            insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
            image: UIImage(systemName: "arrow.up.and.down.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.white),
            imageSize: CGSize(width: 20, height: 20),
            roundedCorners: .roundedLeftCorners
        ),
        activeState: .init(
            size: CGSize(width: 50, height: 50),
            backgroundColor: UIColor.brown,
            insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 6),
            image: UIImage(systemName: "calendar.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.cyan),
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
