# GM-Dragable
A DragableView extension for GM

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
