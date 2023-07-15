//
//  KKDragableView.swift
//  Polytime
//  可拖拽控件
//  Created by gavin on 2021/8/31.
//  Copyright © 2021 cn.kroknow. All rights reserved.
//

import UIKit
import SwiftUI
import GM
import SnapKit

@objc public protocol DragableViewDelegate {
    @objc optional func dragableView(_ dragableView:DragableView, didUpdateDragable height:CGFloat) -> Void
    @objc optional func dragableViewWillMoveToMaxHeight(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewWillMoveToMinHeight(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewDidMoveToMinHeight(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewDidMoveToMaxHeight(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewWillBeginDrag(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewWillEndDrag(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewDidEndDrag(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewWillDismiss(_ dragableView:DragableView) -> Void
    @objc optional func dragableViewDidAppear(_ dragableView:DragableView) -> Void
}

open class DragableView: UIView, UIGestureRecognizerDelegate {
    class DragableContentView : UIView {
        var prepareDestroy:Bool = false
        override func layoutSubviews() {
            super.layoutSubviews()
            if !prepareDestroy, let dragableView = self.superview as? DragableView {
                dragableView.delegate?.dragableView?(dragableView, didUpdateDragable: self.bounds.height)
            }
        }
    }
    
    /// 可拖拽控件内容
    private var contentView:DragableContentView = {
        let view = DragableContentView()
        view.backgroundColor = .clear
        view.layer.cornerRadius =  16
        view.layer.masksToBounds = true
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.frame = CGRect(x: 0, y: UIScreen.main.bounds.size.height, width: UIScreen.main.bounds.size.width, height: 10)
        return view
    }()
    
    /// 拖拽的小横杠
    lazy private var indicatorView:UIView = {
        let view = UIView()
        let indicator = UIView()
        indicator.backgroundColor = indicatorColor
        indicator.layer.cornerRadius = 3
        indicator.layer.masksToBounds = true
        view.addSubview(indicator)
        indicator.snp.makeConstraints { maker in
            maker.center.equalTo(view.snp.center)
            maker.height.equalTo(6)
            maker.width.equalTo(48)
        }
        view.backgroundColor = .clear
        return view
    }()
    
    /// 显示的controllers
    private(set) var viewControllers:[UIViewController] = []
    
    /// 拖拽起始位置
    private var dragBeginPostion:CGPoint?
    
    /// 备份contentHeight
    private var bakeContentHeight:CGFloat = 0
    
    /// 初始contentHeight
    private var initialContentHeight:CGFloat = 0

    /// 最大高度
    private var maxHeight:CGFloat = 0
    
    /// 是否正在执行动画
    private var isAnimating = false
    
    /// 是否键盘呼起
    private var isKeyboardShow = false
    
    /// 显示后调用
    public var onShow:VoidCallBack?
    
    /// dismiss后调用
    public var onDismiss:VoidCallBack?
    
    /// 是否显示背景阴影
    public var showBackgroundShadow:Bool = false {
        didSet {
            backgroundLayer.isHidden = !showBackgroundShadow
        }
    }
    
    /// 键盘高度
    private var keyboardHeight:CGFloat = 0

    /// 不允许手势关闭
    public var disableGestureClose:Bool = false {
        didSet {
            self.dragEnabled = !disableGestureClose
        }
    }
    
    /// 发生手势冲突的scrollView
    private var simultaneouslyScrollView:UIScrollView? = nil
        
    /// indicator backgroundColor
    public var indicatorColor:UIColor = UIColor(red: 241 / 255, green: 243 / 255, blue: 245 / 255, alpha: 1) {
        didSet {
            indicatorView.backgroundColor = indicatorColor
        }
    }
    
    /// background shadowColor
    public var backgroundShadowColor:UIColor = UIColor(red: 233 / 255, green: 236 / 255, blue: 239 / 255, alpha: 1) {
        didSet {
            backgroundLayer.shadowColor = backgroundShadowColor.cgColor
        }
    }

    /// 背景
    public lazy var backgroundLayer:CALayer = {
        let layer =  CALayer()
        layer.cornerRadius =  16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.backgroundColor = UIColor.white.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: -1)
        layer.shadowColor = backgroundShadowColor.cgColor
        layer.isHidden = true
        return layer
    }()
    
    /// 拖拽手势
    lazy private var pan:UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(pan(_:)))
        return gesture
    }()
    
    /// 是否允许拖拽
    public var dragEnabled = true {
        didSet {
            pan.isEnabled = dragEnabled
        }
    }
    
    /// 显示indicator
    public var showIndicator: Bool = true {
        didSet {
            indicatorView.isHidden = !showIndicator
        }
    }
    
    /// 当前内容高度
    public var contentHeight:CGFloat  = 462 {
        didSet {
            contentView.snp.updateConstraints { maker in
                maker.height.equalTo(contentHeight)
            }
            layoutIfNeeded()
        }
    }
    
    /// 根视图控制器
    public var rootViewController:UIViewController? {
        didSet {
            if let newVc = rootViewController {
                viewControllers = [newVc]
                contentView.addSubview(newVc.view)
                newVc.view.snp.makeConstraints { maker in
                    maker.edges.equalTo(UIEdgeInsets.zero)
                }
            } else {
                viewControllers.forEach { vc in
                    vc.view.removeFromSuperview()
                }
                viewControllers.removeAll()
            }
        }
    }
    
    public let passthroughView:UIView?

    open weak var delegate:DragableViewDelegate?
    
    public init(frame: CGRect, backgroundColor:UIColor, passthroughView:UIView?) {
        self.passthroughView = passthroughView
        super.init(frame: frame)
        self.backgroundColor = backgroundColor
        layer.addSublayer(backgroundLayer)
        addSubview(contentView)
        addKeyboardListener()
        contentView.snp.makeConstraints { maker in
            maker.left.right.equalTo(0)
            maker.bottom.equalTo(0)
            maker.height.equalTo(0)
        }
        addSubview(indicatorView)
        indicatorView.snp.makeConstraints { maker in
            maker.left.right.equalTo(0)
            maker.bottom.equalTo(contentView.snp.top)
            maker.height.equalTo(26)
        }
        pan.delegate = self
        addGestureRecognizer(pan)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.frame = contentView.frame
        CATransaction.commit()
        if maxHeight == 0 {
            maxHeight = self.bounds.height - 64
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addKeyboardListener() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameWillChanged), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(_ notify:Notification) {
        
        guard !self.isKeyboardShow else {
            return
        }
        self.pan.isEnabled = false
        self.isKeyboardShow = true
        let duration = notify.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        let endFrame = (notify.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.keyboardHeight = endFrame.height
        let height = min(self.contentHeight + self.keyboardHeight, self.bounds.height - 64) - self.keyboardHeight
        UIView.animate(withDuration: duration) {
            self.contentView.snp.updateConstraints { make in
                make.bottom.equalTo(-self.keyboardHeight)
                make.height.equalTo(height)
            }
            self.layoutIfNeeded()
            self.contentView.setNeedsLayout()
        }
    }
    
    @objc func keyboardWillHidden(_ notify:Notification) {
        guard self.isKeyboardShow else {
            return
        }
        self.pan.isEnabled = true
        self.isKeyboardShow = false
        let duration = notify.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        UIView.animate(withDuration: duration) {
            self.contentView.snp.updateConstraints { make in
                make.bottom.equalTo(0)
                make.height.equalTo(self.contentHeight)
            }
            self.layoutIfNeeded()
            self.contentView.setNeedsLayout()
        }
    }

    @objc func keyboardFrameWillChanged(_ notify:Notification) {
        guard self.isKeyboardShow else {
            return
        }
        let duration = notify.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        let endFrame = (notify.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.keyboardHeight = endFrame.height
        let height = min(self.contentHeight + self.keyboardHeight, self.bounds.height - 64) - self.keyboardHeight
        UIView.animate(withDuration: duration) {
            self.contentView.snp.updateConstraints { make in
                make.bottom.equalTo(-self.keyboardHeight)
                make.height.equalTo(height)
            }
            self.layoutIfNeeded()
            self.contentView.setNeedsLayout()
        }
    }
    
    /// 处理拖拽手势
    /// - Parameter gestureRecognizer: 拖拽手势
    @objc func pan(_ gestureRecognizer:UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            delegate?.dragableViewWillBeginDrag?(self)
            self.dragBeginPostion = gestureRecognizer.location(in: self)
            self.bakeContentHeight = self.contentHeight
            self.simultaneouslyScrollView?.contentOffset = .zero
            self.simultaneouslyScrollView?.isScrollEnabled = false
        case .changed:
            let postion = gestureRecognizer.location(in: self)
            let absY = self.dragBeginPostion!.y - postion.y
            let height = min(maxHeight, self.bakeContentHeight + absY)
            if disableGestureClose, height < initialContentHeight {
                
            } else {
                self.contentHeight = height
            }
            self.simultaneouslyScrollView?.contentOffset = .zero
        case .cancelled:fallthrough
        case .failed:fallthrough
        case .ended:
            delegate?.dragableViewWillEndDrag?(self)
            let postion = gestureRecognizer.location(in: self)
            var finalHeight = self.bakeContentHeight
            let absY = self.dragBeginPostion!.y - postion.y
            let middleHeight = self.initialContentHeight
            if (self.contentHeight >= (self.initialContentHeight + 64) && absY > 0) || (self.contentHeight >= (maxHeight - 64) && absY < 0) {
                finalHeight = maxHeight
                delegate?.dragableViewWillMoveToMaxHeight?(self)
            } else if self.contentHeight >= (middleHeight - 64) && ((self.contentHeight < (middleHeight + 64)  && absY > 0) || (self.contentHeight < (maxHeight - 64) && absY < 0)) {
                finalHeight = initialContentHeight
            } else if self.contentHeight < (middleHeight - 64) {
                if !disableGestureClose {
                    self.dismiss()
                    return
                }
                finalHeight = self.initialContentHeight
            }
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
                self.contentHeight = finalHeight
            }) { finished in
                self.contentView.setNeedsLayout()
                if finalHeight == self.maxHeight {
                    self.delegate?.dragableViewDidMoveToMaxHeight?(self)
                } else if (finalHeight == self.initialContentHeight) {
                    self.delegate?.dragableViewDidMoveToMinHeight?(self)
                }
                self.delegate?.dragableViewDidEndDrag?(self)
            }
            self.simultaneouslyScrollView?.isScrollEnabled = true
            self.simultaneouslyScrollView = nil
        default: break
            
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        guard self.contentHeight != maxHeight else {
            return super.hitTest(point, with: event)
        }
        
        let rect = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.contentView.frame.minY - 40)
        if rect.contains(point) {
            if let passthroughView = passthroughView {
                let passPoint = self.convert(point, to: passthroughView)
                return passthroughView.hitTest(passPoint, with: event)
            }
        }
        return super.hitTest(point, with: event)
    }
    
    
    /// 是否响应手势
    /// - Parameter gestureRecognizer: 手势
    /// - Returns: 是否响应
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer{
            let position = gestureRecognizer.location(in: self)
            var frame = indicatorView.frame
            let velocity = pan.velocity(in: self)
            guard abs(velocity.y) > abs(velocity.x)  else {
                return false
            }
            if velocity.y > 0 {
                return position.y > (frame.origin.y + frame.size.height)
            }
            frame.origin.y -= 20
            frame.size.height = self.contentHeight + 26 + 20
            return frame.contains(position)
        }
        return true
    }
        
    /// 多手势处理，是否多手势都响应
    /// - Parameters:
    ///   - gestureRecognizer: 手势1
    ///   - otherGestureRecognizer: 其他手势
    /// - Returns: 是否支持多手势响应
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.view is UIScrollView {
            let scrollView = otherGestureRecognizer.view as! UIScrollView
            if scrollView.contentSize == scrollView.frame.size || scrollView.contentSize.width > scrollView.frame.width {
                return false
            }
            if !self.disableGestureClose, (scrollView.contentOffset.y <= 0 && scrollView.panGestureRecognizer.velocity(in: scrollView).y > 0) || (self.contentHeight < maxHeight && scrollView.panGestureRecognizer.velocity(in: scrollView).y < 0) {
                self.simultaneouslyScrollView = scrollView
                return true
            }
        }
        return false
    }
    
    /// 显示动画
    /// - Parameter contentHeight: 内容初始高度
    public func show(_ contentHeight:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat = (GM.windowSize.height - GM.safeArea.top - 26)) {
        if isAnimating {
            return
        }
        GM.shakeSoft()
        self.maxHeight = maxHeight
        self.initialContentHeight = min(contentHeight, maxHeight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
                self.contentHeight = self.initialContentHeight
            }) { complete in
                self.contentView.setNeedsLayout()
                self.delegate?.dragableViewDidAppear?(self)
                self.onShow?()
            }
        }
    }
    
    public func transitionToMaxHeight() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
            self.contentHeight = self.maxHeight
        }) { finished in
            self.contentView.setNeedsLayout()
        }
    }
    
    public func transitionToMinHeight() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
            self.contentHeight = self.initialContentHeight
        }) { finished in
            self.contentView.setNeedsLayout()
        }
    }
    
    public func updateDragableHeight(contentHeight:CGFloat, maxHeight:CGFloat = (GM.windowSize.height - GM.safeArea.top - 26), animated:Bool = true) {
        guard !self.contentView.prepareDestroy else {
            return
        }
        self.maxHeight = maxHeight
        self.contentHeight = contentHeight
        self.initialContentHeight = min(contentHeight, maxHeight)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
            self.contentHeight = self.initialContentHeight
            self.layoutIfNeeded()
        }) { finished in
            self.contentView.setNeedsLayout()
        }
    }

    /// 隐藏关闭
    public func dismiss() {
        if isAnimating {
            return
        }
        GM.shakeSoft()
        self.contentView.prepareDestroy = true
        delegate?.dragableViewWillDismiss?(self)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 12, options: .curveEaseInOut, animations: {
            self.contentHeight = 0
        }) { complete in
            self.removeFromSuperview()
            self.viewControllers.removeAll()
            self.onDismiss?()
        }
    }
        
    
    /// 点击事件，空白处关闭页面
    /// - Parameters:
    ///   - touches: touch列表
    ///   - event: 事件
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let positon = touches.first?.location(in: self) ?? .zero
        let rect = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.contentView.frame.minY - (indicatorView.isHidden ? 0 : 40) )
        if rect.contains(positon) {
            if self.isKeyboardShow {
                UIApplication.shared.getFirstKeyWindow?.endEditing(true)
            }
            self.dismiss()
        }
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}

public extension Router.Page {
    
    var isShowingDragableView:Bool {
        return self.controller?.isShowingDragableView ?? false
    }
    
    func showDragableFragment(_ name:String, params:[String : Any]? = nil, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) throws -> Void {
        guard let routePage = GM.pages[name] else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        let viewController = routePage.page(params)
        self.controller?.showDragableFragmentControlller(destination: viewController,backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose:disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
    
    @available(iOS 13.0, *)
    func showDragableHostingFragment<Content:GMSwiftUIPageView>(_ name:String, params:[String : Any]? = nil, contentType:Content.Type, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) throws -> Void {
        guard let routePage = GM.pages[name] else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        let viewController = routePage.page(params)
        self.controller?.showDragableHostingFragmentControlller(destination: viewController, contentType: Content.self, backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose:disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
    
    func popDragableFragment(_ isAll:Bool = true) {
        self.controller?.popDragableView(isAll: isAll)
    }
}

public extension GMSwiftUIPageController {
    func showDragableFragment(_ name:String, params:[String : Any]? = nil, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) throws -> Void {
        guard let routePage = GM.pages[name] else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        let viewController = routePage.page(params)
        self.uiViewController?.showDragableFragmentControlller(destination: viewController, backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose:disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
    
    func popDragableFragment(_ isAll:Bool = true) {
        self.uiViewController?.popDragableView(isAll: isAll)
    }
}

public extension UIViewController {
    func showDragableFragment(_ name:String, params:[String : Any]? = nil, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) throws -> Void {
        guard let routePage = GM.pages[name] else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        let viewController = routePage.page(params)
        self.showDragableFragmentControlller(destination: viewController, backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose:disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
    
    @available(iOS 13.0, *)
    func showDragableHostingFragment<Content:GMSwiftUIPageView>(_ name:String, params:[String : Any]? = nil, contentType:Content.Type, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) throws -> Void {
        guard let routePage = GM.pages[name] else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        let viewController = routePage.page(params)
        self.showDragableHostingFragmentControlller(destination: viewController, contentType: contentType, backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose:disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
}

public extension DragableView {
    
    /// push new
    func toNamed(_ name:String, id:AnyHashable? = nil, params:[String : Any]? = nil, animated:Bool? = nil, completion:VoidCallBack? = nil) throws -> Void {
        guard let navigation = self.rootViewController as? UINavigationController else {
            return
        }
        let routePage = GM.routePageFor(name)
        guard let routePage = routePage else {
            throw Router.RouteError.init(code: Router.RouteErrorCode.notFound.rawValue, msg: Router.RouteErrorDescription.notFound.rawValue)
        }
        
        let viewController = routePage.page(params)
        navigation.pushViewController(viewController, animated: animated ?? routePage.animated)
        completion?()
    }
    
    func back(_ root:Bool = false, animated:Bool = false) {
        guard let navigation = self.rootViewController as? UINavigationController else {
            return
        }
        if root {
            navigation.popToRootViewController(animated: animated)
        } else {
            navigation.popViewController(animated: animated)
        }
    }
}

public extension UIViewController {
    
    private struct DragableAssociatedKeys {
        static var dragViewKey = "DragViewKey"
    }
    
    var isShowingDragableView:Bool {
        return dragableViews.count > 0
    }
    
    /// 可拖动改变高度的控件
    var dragableViews:[DragableView] {
        get {
            var views:[DragableView]? = objc_getAssociatedObject(self, &DragableAssociatedKeys.dragViewKey) as? [DragableView]
            if views == nil {
                views = []
            }
            objc_setAssociatedObject(self, &DragableAssociatedKeys.dragViewKey, views, .OBJC_ASSOCIATION_RETAIN)
            return views!
        }
        set {
            objc_setAssociatedObject(self, &DragableAssociatedKeys.dragViewKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// 展示一个可拖拽高度的页面
    /// - Parameters:
    ///   - controller: 根视图控制器
    ///   - height: 内容高度
    func showDragableFragmentControlller(destination:UIViewController, backgroundColor:UIColor, showShadow:Bool, showIndicator:Bool, disableGestureClose:Bool = false, passthroughView:UIView?, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss: VoidCallBack?) {
        
//        if let currentDragable = self.dragableViews.last {
//            currentDragable.isHidden = true
//        }
        destination.isDragable = true
        let dragableView = DragableView(frame: self.view.bounds, backgroundColor: backgroundColor, passthroughView: passthroughView)
        dragableView.rootViewController = destination
        dragableView.showBackgroundShadow = showShadow
        dragableView.disableGestureClose = disableGestureClose
        dragableView.showIndicator = showIndicator
        self.view.addSubview(dragableView)
        dragableView.snp.makeConstraints({ maker in
            maker.edges.equalTo(UIEdgeInsets.zero)
        })
        dragableView.show(height, maxHeight: maxHeight ?? self.view.bounds.size.height - self.view.safeAreaInsets.top - 26)
        dragableView.onDismiss = { [weak self] in
            self?.removeDragable(isAll: false)
            onDismiss?()
        }
        dragableView.delegate = (destination as? DragableViewDelegate)
        self.dragableViews.append(dragableView)
    }
    
    /// 展示一个可拖拽高度的页面
    /// - Parameters:
    ///   - controller: 根视图控制器
    ///   - height: 内容高度
    @available(iOS 13.0, *)
    func showDragableHostingFragmentControlller<Content:GMSwiftUIPageView>(destination:UIViewController, contentType:Content.Type, backgroundColor:UIColor, showShadow:Bool, showIndicator:Bool, disableGestureClose:Bool = false, passthroughView:UIView?, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss: VoidCallBack?) {
        
//        if let currentDragable = self.dragableViews.last {
//            currentDragable.isHidden = true
//        }
        let dragableView = DragableView(frame: self.view.bounds, backgroundColor: backgroundColor, passthroughView: passthroughView)
        destination.isDragable = true
        if let navigation = destination as? UINavigationController {
            let page = navigation.viewControllers.first! as! GMSwiftUIPage<Content>
            page.isDragable = true
            page.rootView.observedController?.isDragable = true
            dragableView.delegate = (page.rootView.observedController as? DragableViewDelegate)
        } else {
            let page = destination as! GMSwiftUIPage<Content>
            page.rootView.observedController?.isDragable = true
            dragableView.delegate = (page.rootView.observedController as? DragableViewDelegate)
        }
        dragableView.rootViewController = destination
        dragableView.disableGestureClose = disableGestureClose
        dragableView.showBackgroundShadow = showShadow
        dragableView.showIndicator = showIndicator
        self.view.addSubview(dragableView)
        dragableView.snp.makeConstraints({ maker in
            maker.edges.equalTo(UIEdgeInsets.zero)
        })
        dragableView.show(height, maxHeight: maxHeight ?? self.view.bounds.size.height - self.view.safeAreaInsets.top - 26)
        dragableView.onDismiss = { [weak self] in
            self?.removeDragable(isAll: false)
            onDismiss?()
        }
        self.dragableViews.append(dragableView)
    }
    
    /// 关闭可拖拽控件
    /// - Parameter isAll: 是否关闭所有，否则只关闭最上层
    func popDragableView(isAll:Bool = true) {
        let last = self.dragableViews.last
        if isAll {
            if last != nil {
                self.dragableViews.removeLast()
            }
            self.removeDragable(isAll: isAll)
        }
        last?.dismiss()
    }
    
    /// 清除已展示的可拖拽控件
    /// - Parameter isAll: 是否清除所有，否则只清除最后一个
    fileprivate func removeDragable(isAll:Bool = true) {
        guard self.dragableViews.count > 0 else {
            return
        }
        if isAll {
            self.dragableViews.forEach { dragableView in
                dragableView.removeFromSuperview()
            }
            self.dragableViews.removeAll()
        } else {
            self.dragableViews.removeLast()
        }
    }
    
    /// 展示上一个可拖拽控件
    fileprivate func showPreDragableView() {
        if let lastDragable = self.dragableViews.last {
            lastDragable.isHidden = false
        }
    }
    
    /*
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

public extension UIViewController {
    private struct DragableKeys {
        static var isDragableKey = "isDragableView"
    }
    
    var isDragable:Bool {
        set {
            objc_setAssociatedObject(self, &DragableKeys.isDragableKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return (objc_getAssociatedObject(self, &DragableKeys.isDragableKey) as? Bool) ?? false
        }
    }
}


public extension GMSwiftUIPageController {
    
    private struct DragableKeys {
        static var isDragableKey = "isDragableView"
    }
    
    var isDragable:Bool {
        set {
            objc_setAssociatedObject(self, &DragableKeys.isDragableKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return (objc_getAssociatedObject(self, &DragableKeys.isDragableKey) as? Bool) ?? false
        }
    }
}



public extension GM {
    static let AppleLoginLogPrefix = "【APPLE LOGIN】:"
    static let ApnsLogPrefix = "【APNS】:"
    static let CalendarLogPrefix = "【CALENDAR】:"
    static let MqttLogPrefix = "【MQTT】:"
    static let TracingLogPrefix = "【TRACKING EVENT】:"
}



/// 路由相关
public extension GM {
        
    static func showDragableFragment(_ name:String, params:[String : Any]? = nil, fromPage:Router.Page? = nil, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) {
        try? (fromPage ?? GM.topPage())?.showDragableFragment(name, params: params, backgroundColor:backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose: disableGestureClose, passthroughView:passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
        
    @available(iOS 13.0, *)
    static func showDragableHostingFragment<Content:GMSwiftUIPageView>(_ name:String, params:[String : Any]? = nil, contentType:Content.Type, fromPage:Router.Page? = nil, backgroundColor:UIColor = UIColor.init(white: 0, alpha: 0.5), showShadow:Bool = false, showIndicator:Bool = true, disableGestureClose:Bool = false, passthroughView:UIView? = nil, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss:VoidCallBack? = nil) {
        try? (fromPage ?? GM.topPage())?.showDragableHostingFragment(name, params: params, contentType: Content.self, backgroundColor: backgroundColor, showShadow: showShadow, showIndicator: showIndicator, disableGestureClose: disableGestureClose, passthroughView: passthroughView, height: height, maxHeight: maxHeight, onDismiss: onDismiss)
    }
    
    @available(iOS 13.0, *)
    static func showDragableHostingFragment<Content:GMSwiftUIPageView>(_ fragment:Content, contentType:Content.Type, backgroundColor:UIColor, showShadow:Bool, showIndicator:Bool, disableGestureClose:Bool = false, passthroughView:UIView?, height:CGFloat = GM.windowSize.height * 0.5, maxHeight:CGFloat? = nil, onDismiss: VoidCallBack?) {
        
        guard let currentViewController = GM.topPage()?.controller else {
            return
        }
//        if let currentDragable = self.dragableViews.last {
//            currentDragable.isHidden = true
//        }
        let destination = UIHostingController(rootView: fragment)
        let dragableView = DragableView(frame: currentViewController.view.bounds, backgroundColor: backgroundColor, passthroughView: passthroughView)
        destination.isDragable = true
        let page = destination as! GMSwiftUIPage<Content>
        page.rootView.observedController?.isDragable = true
        dragableView.delegate = (page.rootView.observedController as? DragableViewDelegate)
        dragableView.rootViewController = destination
        dragableView.disableGestureClose = disableGestureClose
        dragableView.showBackgroundShadow = showShadow
        dragableView.showIndicator = showIndicator
        currentViewController.view.addSubview(dragableView)
        dragableView.snp.makeConstraints({ maker in
            maker.edges.equalTo(UIEdgeInsets.zero)
        })
        dragableView.show(height, maxHeight: maxHeight ?? currentViewController.view.bounds.size.height - currentViewController.view.safeAreaInsets.top - 26)
        dragableView.onDismiss = { [weak currentViewController] in
            currentViewController?.removeDragable(isAll: false)
            onDismiss?()
        }
        currentViewController.dragableViews.append(dragableView)
    }

    
    static func popDragableView(from:Router.Page? = nil, isAll:Bool = true) {
        (from ?? GM.topPage())?.popDragableFragment(isAll)
    }
}
