# GM-Dragable

A DragableView extension for GM

# Installation

##  SwiftPackageManager

The preferred way of installing SwiftUIX is via the [Swift Package Manager](https://swift.org/package-manager/).

>Xcode 11 integrates with libSwiftPM to provide support for iOS, watchOS, macOS and tvOS platforms.

1. In Xcode, open your project and navigate to **File** → **Swift Packages** → **Add Package Dependency...**
2. Paste the repository URL (`https://github.com/shaokui-gu/GM-Dragable.git`) and click **Next**.
3. Click **Finish**.

## CocoaPods 

```
pod 'GM+Dragable', :git => "https://github.com/shaokui-gu/GM-Dragable.git", :tag => '0.2.7'
```

# How to use it

* UIViewController

```
try? self.showDragableFragment("/main", params: [
            "id": 1
            ...
        ], backgroundColor: .clear, showShadow: true, disableGestureClose: true, height: 320, onDismiss: {
           /// do something on dismiss
           ...
        })
```

* GM

```
  GM.showDragableFragment("/main", params: [
            "id": 1
            ...
        ], backgroundColor: .clear, showShadow: true, disableGestureClose: true, height: 320, onDismiss: {
           /// do something on dismiss
           ...
        })
```
