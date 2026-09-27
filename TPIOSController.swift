import UIKit

// Window chỉ giữ touch khi touch thực sự nằm trên
// một view của TPIOS. Các vùng còn lại xuyên xuống app.
final class TPIOSPassThroughWindow: UIWindow {

    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {

        guard isHidden == false,
              alpha > 0.01,
              isUserInteractionEnabled else {
            return nil
        }

        let hitView = super.hitTest(
            point,
            with: event
        )

        if hitView === rootViewController?.view {
            return nil
        }

        return hitView
    }
}

final class TPIOSController {

    static let shared = TPIOSController()

    private var overlayWindow: TPIOSPassThroughWindow?
    private var floatingButton: FloatingButton?
    private var menu: TPIOSMenu?

    private var startRetryCount = 0
    private let maxStartRetries = 20

    private var idleWorkItem: DispatchWorkItem?
    private let idleDelay: TimeInterval = 2.5

    // Đánh dấu thao tác thật sự là kéo để không mở menu khi đang di chuyển nút.
    private var buttonDidDrag = false

    private init() {}

    func start() {
        TPIOSLog.shared.log("TPIOSStart được gọi")
        DispatchQueue.main.async { [weak self] in
            self?.startOnMain()
        }
    }

    private func startOnMain() {

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startOnMain()
            }
            return
        }

        guard overlayWindow == nil else {
            return
        }

        guard let scene =
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: {
                    $0.activationState == .foregroundActive
                }) else {

            TPIOSLog.shared.log(
                "Chưa có foregroundActive scene, retry lần \(startRetryCount + 1)"
            )
            retryStart()
            return
        }

        startRetryCount = 0

        let window = TPIOSPassThroughWindow(
            windowScene: scene
        )

        window.backgroundColor = .clear
        window.windowLevel = .alert + 1
        window.isHidden = false

        let root = UIViewController()
        root.view.backgroundColor = .clear
        root.view.isOpaque = false

        window.rootViewController = root
        overlayWindow = window

        TPIOSLog.shared.log("Overlay window đã khởi tạo")

        let buttonSize: CGFloat = 58
        let margin: CGFloat = 18

        let button = FloatingButton(
            frame: CGRect(
                x: window.bounds.width - buttonSize - margin,
                y: window.bounds.height / 2 - buttonSize / 2,
                width: buttonSize,
                height: buttonSize
            )
        )

        // Cơ chế giống nút Home ảo:
        // chạm -> giữ nếu muốn kéo -> thả tay mới thực hiện hành động.
        // Không còn phải chờ long-press 2.5 giây.
        button.addTarget(
            self,
            action: #selector(buttonReleased(_:)),
            for: .touchUpInside
        )

        // Kéo nút không mở menu.
        let dragGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(moveButton(_:))
        )
        dragGesture.cancelsTouchesInView = false
        button.addGestureRecognizer(dragGesture)

        root.view.addSubview(button)
        floatingButton = button

        scheduleButtonFade()

        TPIOSAdBlock.activateSavedProfileIfPossible()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeMenu),
            name: .tpiosCloseMenu,
            object: nil
        )
    }

    private func retryStart() {

        guard startRetryCount < maxStartRetries else {
            return
        }

        startRetryCount += 1

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.5
        ) { [weak self] in
            self?.startOnMain()
        }
    }

    @objc private func buttonReleased(_ button: UIButton) {
        // Nếu người dùng vừa kéo nút thì tuyệt đối không mở menu.
        guard buttonDidDrag == false else {
            buttonDidDrag = false
            return
        }

        TPIOSLog.shared.log("Floating button released")
        showButtonImmediately()
        toggleMenu()
    }

    @objc private func moveButton(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let button = floatingButton,
              let parent = button.superview else {
            return
        }

        switch gesture.state {

        case .began:
            buttonDidDrag = false
            showButtonImmediately()

        case .changed:
            let translation = gesture.translation(in: parent)

            // Chỉ coi là kéo khi ngón tay đã di chuyển đủ rõ ràng.
            // Tránh việc rung tay rất nhỏ làm mất thao tác chạm.
            if abs(translation.x) > 8 || abs(translation.y) > 8 {
                buttonDidDrag = true
            }

            var newFrame = button.frame
            newFrame.origin.x += translation.x
            newFrame.origin.y += translation.y

            let maxX = max(0, parent.bounds.width - newFrame.width)
            let maxY = max(0, parent.bounds.height - newFrame.height)

            newFrame.origin.x = max(
                0,
                min(newFrame.origin.x, maxX)
            )

            newFrame.origin.y = max(
                0,
                min(newFrame.origin.y, maxY)
            )

            button.frame = newFrame

            gesture.setTranslation(
                .zero,
                in: parent
            )

        case .ended, .cancelled, .failed:
            scheduleButtonFade()

            // Giữ cờ cho đến khi UIButton xử lý touchUpInside.
            DispatchQueue.main.async { [weak self] in
                self?.buttonDidDrag = false
            }

        default:
            break
        }
    }

    private func showButtonImmediately() {

        idleWorkItem?.cancel()

        guard let button = floatingButton else {
            return
        }

        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            button.alpha = self.menu == nil ? 1.0 : 0.35
        }
    }

    private func scheduleButtonFade() {

        idleWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  let button = self.floatingButton else {
                return
            }

            UIView.animate(
                withDuration: 0.7,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                button.alpha = self.menu == nil ? 0.28 : 0.20
            }
        }

        idleWorkItem = work

        DispatchQueue.main.asyncAfter(
            deadline: .now() + idleDelay,
            execute: work
        )
    }

    private func toggleMenu() {

        guard let rootView =
            overlayWindow?.rootViewController?.view else {
            return
        }

        if let menu {

            menu.removeFromSuperview()
            self.menu = nil

            floatingButton?.isHidden = false
            floatingButton?.alpha = 1.0

            TPIOSLog.shared.log("Đóng menu chính")
            scheduleButtonFade()
            return
        }

        let width: CGFloat = 310
        let height: CGFloat = 400

        let safeArea = rootView.safeAreaInsets

        let availableWidth =
            rootView.bounds.width -
            safeArea.left -
            safeArea.right

        let availableHeight =
            rootView.bounds.height -
            safeArea.top -
            safeArea.bottom

        let menuWidth = min(
            width,
            max(260, availableWidth - 20)
        )

        let menuHeight = min(
            height,
            max(340, availableHeight - 20)
        )

        let x =
            safeArea.left +
            (availableWidth - menuWidth) / 2

        let y =
            safeArea.top +
            (availableHeight - menuHeight) / 2

        let newMenu = TPIOSMenu(
            frame: CGRect(
                x: x,
                y: y,
                width: menuWidth,
                height: menuHeight
            )
        )

        rootView.addSubview(newMenu)

        menu = newMenu

        TPIOSLog.shared.log("Mở menu chính")

        // Giống AssistiveTouch: khi menu mở, nút nổi biến mất.
        floatingButton?.isHidden = true
        floatingButton?.alpha = 1.0
        idleWorkItem?.cancel()
    }

    @objc private func closeMenu() {

        menu?.removeFromSuperview()
        menu = nil

        floatingButton?.isHidden = false
        floatingButton?.alpha = 1.0

        scheduleButtonFade()
    }

    func stop() {

        TPIOSLog.shared.log("TPIOSStop được gọi")

        idleWorkItem?.cancel()
        idleWorkItem = nil

        NotificationCenter.default.removeObserver(
            self,
            name: .tpiosCloseMenu,
            object: nil
        )

        menu?.removeFromSuperview()

        overlayWindow?.isHidden = true
        overlayWindow = nil

        floatingButton = nil
        menu = nil

        startRetryCount = 0
    }
}
