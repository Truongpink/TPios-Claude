import UIKit
import WebKit

final class TPIOSReload {

    static let shared = TPIOSReload()

    private init() {}

    func reloadCurrentPage() {

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reloadCurrentPage()
            }
            return
        }

        TPIOSLog.shared.log("Tải lại trang hiện tại")

        let roots = visibleAppRoots()
        guard roots.isEmpty == false else {
            TPIOSLog.shared.log("Reload: không tìm thấy màn hình app")
            return
        }

        // 1. Web content: đây là trường hợp duy nhất đã có API reload
        // chuẩn và có ý nghĩa network rõ ràng.
        let webViews = roots.flatMap { collectWebViews(in: $0) }

        if webViews.isEmpty == false {
            TPIOSLog.shared.log("Reload: tìm thấy \(webViews.count) WKWebView")
            for (index, wv) in webViews.enumerated() {
                let rect = wv.convert(wv.bounds, to: nil)
                TPIOSLog.shared.log(
                    "Reload webView[\(index)]: \(Int(rect.width))x\(Int(rect.height)) url=\(wv.url?.absoluteString ?? "<nil>")"
                )
            }
        }

        if let webView = largestWebView(in: webViews) {
            let url = webView.url?.absoluteString ?? "<nil>"
            TPIOSLog.shared.log("Reload: WKWebView \(url)")
            webView.reloadFromOrigin()
            return
        }

        // 2. Chạy một lượt discovery tổng hợp cho native/RN.
        // Không gọi selector private/không rõ signature ở bước này.
        let scrollViews = roots.flatMap { collectScrollViews(in: $0) }

        TPIOSLog.shared.log(
            "Reload: native discovery, \(scrollViews.count) UIScrollView"
        )

        var discovered: [ReloadCandidate] = []

        for (index, scrollView) in scrollViews.prefix(8).enumerated() {
            let viewClass = NSStringFromClass(type(of: scrollView))
            let delegate = scrollView.delegate as AnyObject?

            TPIOSLog.shared.log(
                "Reload[\(index)]: \(viewClass), delegate=\(delegate.map { NSStringFromClass(type(of: $0)) } ?? "<nil>")"
            )

            discovered.append(
                contentsOf: inspectRefreshControl(
                    in: scrollView,
                    index: index
                )
            )

            discovered.append(
                contentsOf: inspectObject(
                    scrollView,
                    label: "Reload[\(index)] view"
                )
            )

            if let delegate {
                discovered.append(
                    contentsOf: inspectObject(
                        delegate,
                        label: "Reload[\(index)] delegate"
                    )
                )

                if let refreshControl = objectProperty(
                    delegate,
                    selectorName: "refreshControl"
                ) {
                    TPIOSLog.shared.log(
                        "Reload[\(index)] delegate.refreshControl=\(NSStringFromClass(type(of: refreshControl)))"
                    )

                    discovered.append(
                        contentsOf: inspectObject(
                            refreshControl,
                            label: "Reload[\(index)] refreshControl"
                        )
                    )
                }
            }

            discovered.append(
                contentsOf: inspectAncestorControllers(
                    from: scrollView,
                    label: "Reload[\(index)]"
                )
            )
        }

        let unique = deduplicateCandidates(discovered)

        if unique.isEmpty {
            TPIOSLog.shared.log(
                "Reload: chưa tìm thấy refresh candidate có thể xác định"
            )
        } else {
            TPIOSLog.shared.log(
                "Reload: discovery hoàn tất, \(unique.count) candidate"
            )

            for candidate in unique.prefix(40) {
                TPIOSLog.shared.log(
                    "ReloadCandidate: \(candidate)"
                )
            }
        }

        // RNRefreshControl là nhánh đã có runtime evidence rõ nhất.
        // Không gọi selector private ngẫu nhiên; chỉ thử đường callback
        // public/Objective-C mà RN expose trực tiếp.
        if let rnControl = findRNRefreshControl(in: scrollViews) {
            if triggerRNRefreshControl(rnControl) {
                TPIOSLog.shared.log("Reload: đã kích hoạt RNRefreshControl refresh")
                return
            }
        }

        // 3. Trang chủ Shopee (Tangram / SHPHomePageViewController): runtime
        // đã xác nhận có refreshHomepage (v16@0:8 — không tham số), khác
        // hẳn jsReloadData:/jsReloadDataForLayoutIndex:: (nhận tham số
        // không rõ kiểu, rủi ro sai calling convention). Gọi thẳng vì đây
        // là selector an toàn nhất và đúng đích nhất trong danh sách.
        if let homepageController = findAncestorController(
            in: scrollViews,
            classNameContains: "SHPHomePageViewController"
        ) {
            let selector = NSSelectorFromString("refreshHomepage")

            if homepageController.responds(to: selector) {
                TPIOSLog.shared.log(
                    "Reload: gọi SHPHomePageViewController.refreshHomepage"
                )
                homepageController.perform(selector)
                return
            }
        }

        // 4. Màn hình RN không có refresh control (vd: trang thanh toán —
        // Shopee cố tình không gắn refreshControl ở đây). Không có
        // callback nào để gọi trực tiếp, nên mô phỏng thao tác tay thật:
        // back ra rồi vào lại để RN mount lại từ đầu.
        // Chỉ pop() bằng API UIKit công khai (an toàn), và chỉ thực hiện
        // khi rnScreen đang thật sự là top của nav stack — tránh back
        // nhầm màn hình khác. Không tự tạo instance mới qua router nội
        // bộ của Shopee (không có bằng chứng runtime nào về API đó, đây
        // lại là màn thanh toán nên không đoán mò).
        if let rnScreen = findAncestorController(
            in: scrollViews,
            classNameContains: "RNViewController"
        ) as? UIViewController {

            if let nav = rnScreen.navigationController {

                if nav.topViewController === rnScreen {

                    TPIOSLog.shared.log(
                        "Reload: \(NSStringFromClass(type(of: rnScreen))) không có refresh control — back ra rồi vào lại"
                    )

                    nav.popViewController(animated: false)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        nav.pushViewController(rnScreen, animated: false)
                        TPIOSLog.shared.log(
                            "Reload: đã vào lại \(NSStringFromClass(type(of: rnScreen)))"
                        )
                    }

                    return

                } else {
                    TPIOSLog.shared.log(
                        "Reload: \(NSStringFromClass(type(of: rnScreen))) không phải top của nav stack (top hiện tại=\(nav.topViewController.map { NSStringFromClass(type(of: $0)) } ?? "<nil>")) — bỏ qua để tránh back nhầm màn"
                    )
                }

            } else {
                TPIOSLog.shared.log(
                    "Reload: \(NSStringFromClass(type(of: rnScreen))) không có navigationController (có thể present modal/custom container, không phải push chuẩn)"
                )
            }

        } else {
            TPIOSLog.shared.log(
                "Reload: không tìm thấy ancestor RNViewController để back/vào lại"
            )
        }

        // 5. Fallback cho màn hình native khác (không phải RN, không phải
        // trang chủ): UIRefreshControl chuẩn, customRefreshControl
        // (RCTCustomScrollView) hoặc mj_header (MJRefresh).
        let refreshComponents = roots.flatMap { collectRefreshComponents(in: $0) }

        if let component = refreshComponents.first {
            TPIOSLog.shared.log(
                "Reload: kích hoạt refresh control chuẩn \(NSStringFromClass(type(of: component)))"
            )
            triggerRefresh(component)
            return
        }

        TPIOSLog.shared.log(
            "Reload: chưa xác định được callback refresh thật sự"
        )
    }

    private struct ReloadCandidate: Hashable, CustomStringConvertible {
        let owner: String
        let selector: String
        let signature: String

        var description: String {
            "\(owner).\(selector) [\(signature)]"
        }
    }

    private func findAncestorController(
        in scrollViews: [UIScrollView],
        classNameContains needle: String
    ) -> AnyObject? {

        for scrollView in scrollViews {
            var current: UIView? = scrollView
            var controllersChecked = 0
            var safety = 0

            // Giới hạn theo số UIViewController đã kiểm tra (giống
            // inspectAncestorControllers), không giới hạn theo từng bước
            // UIView — cây view RN có thể sâu hơn nhiều so với native.
            // "safety" chỉ để chặn vòng lặp vô hạn thật sự, không phải
            // ngưỡng nghiệp vụ.
            while let currentView = current, safety < 500 {
                safety += 1

                if let controller = currentView.next as? UIViewController {
                    if NSStringFromClass(type(of: controller))
                        .contains(needle) {
                        return controller
                    }

                    controllersChecked += 1
                    if controllersChecked >= 8 {
                        break
                    }

                    current = controller.view.superview
                } else {
                    current = currentView.superview
                }
            }
        }

        return nil
    }

    private func findRNRefreshControl(
        in scrollViews: [UIScrollView]
    ) -> AnyObject? {

        for scrollView in scrollViews {
            guard let delegate = scrollView.delegate as AnyObject? else {
                continue
            }

            if NSStringFromClass(type(of: delegate))
                .lowercased()
                .contains("rnrefreshcontrol") {

                if let refreshControl = objectProperty(
                    delegate,
                    selectorName: "refreshControl"
                ) {
                    TPIOSLog.shared.log(
                        "Reload: RNRefreshControl=\(NSStringFromClass(type(of: refreshControl)))"
                    )
                    return refreshControl
                }
            }
        }

        return nil
    }

    private func triggerRNRefreshControl(
        _ control: AnyObject
    ) -> Bool {

        // onRefresh là property kiểu RCTBubblingEventBlock — chính là
        // callback JS mà RCTRefreshControl gọi trong
        // refreshControlValueChanged khi người dùng kéo tay thật:
        //   if (self.onRefresh) { self.onRefresh(nil); }
        // Runtime đã xác nhận onRefresh/setOnRefresh: tồn tại trên class
        // này (không phải đoán mò), nên gọi thẳng block này là cách đúng
        // để kích hoạt refresh thật, không chỉ đổi UI state.
        let onRefreshSelector = NSSelectorFromString("onRefresh")

        if control.responds(to: onRefreshSelector),
           let blockObject = control.perform(onRefreshSelector)?
            .takeUnretainedValue() {

            typealias RCTBubblingEventBlock = @convention(block) (NSDictionary?) -> Void
            let onRefresh = unsafeBitCast(
                blockObject,
                to: RCTBubblingEventBlock.self
            )

            TPIOSLog.shared.log(
                "Reload: gọi trực tiếp RNRefreshControl.onRefresh(nil)"
            )
            onRefresh(nil)

            // Đồng bộ UI state cho khớp (không bắt buộc để refresh chạy,
            // chỉ để spinner hiển thị đúng trạng thái).
            let beginSelector = NSSelectorFromString("beginRefreshingProgrammatically")
            if control.responds(to: beginSelector) {
                control.perform(beginSelector)
            }

            // Xác nhận khách quan: theo dõi property "refreshing" theo thời
            // gian. Nếu nó chuyển true -> false sau vài giây, nghĩa là JS
            // đã thực sự chạy xong chu kỳ refresh (fetch data thật). Nếu
            // đứng yên ở false ngay từ đầu, khả năng cao onRefresh(nil)
            // không kích hoạt được fetch thật.
            scheduleRefreshingStateCheck(
                on: control,
                label: "Reload voucher"
            )

            return true
        }

        TPIOSLog.shared.log(
            "Reload: RNRefreshControl không có onRefresh block khả dụng"
        )

        // Fallback: các cách cũ, chỉ đổi UI state, có thể không load data thật.
        let beginSelector = NSSelectorFromString("beginRefreshingProgrammatically")

        if control.responds(to: beginSelector) {
            TPIOSLog.shared.log(
                "Reload: gọi RNRefreshControl.beginRefreshingProgrammatically (fallback)"
            )
            control.perform(beginSelector)
            return true
        }

        if let uiControl = control as? UIControl {
            TPIOSLog.shared.log(
                "Reload: gửi UIControlEvent .valueChanged tới RNRefreshControl (fallback)"
            )
            uiControl.sendActions(for: .valueChanged)
            return true
        }

        return false
    }

    private func scheduleRefreshingStateCheck(
        on control: AnyObject,
        label: String
    ) {
        guard let nsControl = control as? NSObject,
              nsControl.responds(to: NSSelectorFromString("refreshing")) else {
            return
        }

        func check(after delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay
            ) { [weak nsControl] in
                guard let nsControl else { return }
                let value = nsControl.value(forKey: "refreshing") as? Bool
                TPIOSLog.shared.log(
                    "\(label): refreshing=\(value.map { String($0) } ?? "?") (+\(delay)s)"
                )
            }
        }

        check(after: 0.5)
        check(after: 2.0)
        check(after: 5.0)
    }

    private func inspectRefreshControl(
        in scrollView: UIScrollView,
        index: Int
    ) -> [ReloadCandidate] {

        var result: [ReloadCandidate] = []

        if let refresh = scrollView.refreshControl {
            TPIOSLog.shared.log(
                "Reload[\(index)] UIScrollView.refreshControl=\(NSStringFromClass(type(of: refresh)))"
            )

            result.append(
                contentsOf: inspectObject(
                    refresh,
                    label: "Reload[\(index)] UIRefreshControl"
                )
            )
        }

        for selectorName in ["customRefreshControl"] {
            if let value = objectProperty(
                scrollView,
                selectorName: selectorName
            ) {
                TPIOSLog.shared.log(
                    "Reload[\(index)] \(selectorName)=\(NSStringFromClass(type(of: value)))"
                )

                result.append(
                    contentsOf: inspectObject(
                        value,
                        label: "Reload[\(index)] \(selectorName)"
                    )
                )
            }
        }

        return result
    }

    private func inspectObject(
        _ object: AnyObject,
        label: String
    ) -> [ReloadCandidate] {

        var result: [ReloadCandidate] = []
        var classObject: AnyClass? = type(of: object)

        while let currentClass = classObject {
            var methodCount: UInt32 = 0

            if let methods = class_copyMethodList(
                currentClass,
                &methodCount
            ) {
                for index in 0..<Int(methodCount) {
                    let method = methods[index]
                    let selector = method_getName(method)
                    let name = NSStringFromSelector(selector)
                    let lower = name.lowercased()

                    guard lower.contains("reload") ||
                            lower.contains("refresh") ||
                            lower.contains("fetch") ||
                            lower.contains("request") ||
                            lower.contains("valuechanged") ||
                            lower.contains("onrefresh") else {
                        continue
                    }

                    let encoding = method_getTypeEncoding(method)
                    let signature = encoding.map {
                        String(cString: $0)
                    } ?? "?"

                    result.append(
                        ReloadCandidate(
                            owner: NSStringFromClass(currentClass),
                            selector: name,
                            signature: signature
                        )
                    )
                }

                free(methods)
            }

            classObject = class_getSuperclass(currentClass)
        }

        return result
    }

    private func inspectAncestorControllers(
        from view: UIView,
        label: String
    ) -> [ReloadCandidate] {

        var result: [ReloadCandidate] = []
        var current: UIView? = view
        var controllers: [UIViewController] = []

        while let currentView = current {
            if let controller = currentView.next as? UIViewController {
                controllers.append(controller)
                current = controller.view.superview
            } else {
                current = currentView.superview
            }

            if controllers.count >= 6 {
                break
            }
        }

        if controllers.isEmpty == false {
            TPIOSLog.shared.log(
                "\(label) controllers=\(controllers.map { NSStringFromClass(type(of: $0)) }.joined(separator: " -> "))"
            )
        }

        for controller in controllers {
            result.append(
                contentsOf: inspectObject(
                    controller,
                    label: "\(label) controller"
                )
            )
        }

        return result
    }

    private func objectProperty(
        _ object: AnyObject,
        selectorName: String
    ) -> AnyObject? {

        let selector = NSSelectorFromString(selectorName)

        guard object.responds(to: selector) else {
            return nil
        }

        return object.perform(selector)?
            .takeUnretainedValue() as AnyObject?
    }

    private func deduplicateCandidates(
        _ candidates: [ReloadCandidate]
    ) -> [ReloadCandidate] {

        var seen = Set<ReloadCandidate>()
        var result: [ReloadCandidate] = []

        for candidate in candidates.sorted(
            by: {
                if $0.owner == $1.owner {
                    return $0.selector < $1.selector
                }
                return $0.owner < $1.owner
            }
        ) {
            if seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }

        return result
    }

    private func logReloadCandidates(object: AnyObject, label: String) {
        let selectors = [
            "reloadData",
            "reload",
            "reloadPage",
            "refresh",
            "refreshData",
            "reloadDataSource"
        ]

        var found: [String] = []

        for name in selectors {
            if object.responds(to: NSSelectorFromString(name)) {
                found.append(name)
            }
        }

        // Liệt kê thêm selector thực tế có tên liên quan tới reload/refresh/fetch.
        // Chỉ đọc metadata runtime, không gọi selector.
        var classObject: AnyClass? = type(of: object)

        // Walk the full superclass chain. Important for RNRefreshControl and
        // custom Shopee classes where the useful selector may be inherited.
        while let currentClass = classObject {
            var methodCount: UInt32 = 0

            if let methods = class_copyMethodList(currentClass, &methodCount) {
                for index in 0..<Int(methodCount) {
                    let selector = method_getName(methods[index])
                    let name = NSStringFromSelector(selector)
                    let lower = name.lowercased()

                    if lower.contains("reload") ||
                        lower.contains("refresh") ||
                        lower.contains("fetch") ||
                        lower.contains("request") ||
                        lower.contains("valuechanged") {
                        if found.contains(name) == false {
                            found.append(name)
                        }
                    }
                }

                free(methods)
            }

            classObject = class_getSuperclass(currentClass)
        }

        if found.isEmpty == false {
            TPIOSLog.shared.log(
                "\(label) candidates=\(found.sorted().joined(separator: ","))"
            )
        }
    }

    private func logAncestorViewControllers(from view: UIView, label: String) {
        var current: UIView? = view
        var controllers: [String] = []
        while let currentView = current {
            if let controller = currentView.next as? UIViewController {
                controllers.append(NSStringFromClass(type(of: controller)))
                current = controller.view.superview
            } else {
                current = currentView.superview
            }
            if controllers.count >= 6 { break }
        }
        if controllers.isEmpty == false {
            TPIOSLog.shared.log("\(label) controllers=\(controllers.joined(separator: " -> "))")
        }
    }
    private func visibleAppRoots() -> [UIView] {

        let windows = UIApplication.shared.windows
            .filter {
                $0.isHidden == false &&
                $0.alpha > 0.01 &&
                MTIsOverlayWindowIfAvailable($0) == false
            }
            .sorted {
                if $0.windowLevel == $1.windowLevel {
                    return $0.bounds.width * $0.bounds.height >
                        $1.bounds.width * $1.bounds.height
                }

                return $0.windowLevel > $1.windowLevel
            }

        return windows.compactMap { topmostView(in: $0) }
    }

    private func topmostView(in window: UIWindow) -> UIView? {

        var controller = window.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }

        return controller?.view ?? window
    }

    private func collectWebViews(in root: UIView) -> [WKWebView] {

        var result: [WKWebView] = []

        func walk(_ view: UIView) {
            guard view.isHidden == false,
                  view.alpha > 0.01 else {
                return
            }

            if let webView = view as? WKWebView {
                let rect = webView.convert(webView.bounds, to: nil)

                // Bỏ qua các WKWebView tí hon/ẩn (tracking pixel, chat SDK,
                // quảng cáo...) — chúng không phải nội dung đang hiển thị
                // và không nên chiếm quyền reload của trang thật.
                if rect.width > 50, rect.height > 50 {
                    result.append(webView)
                } else {
                    TPIOSLog.shared.log(
                        "Reload: bỏ qua WKWebView quá nhỏ \(Int(rect.width))x\(Int(rect.height)) url=\(webView.url?.absoluteString ?? "<nil>")"
                    )
                }
            }

            for subview in view.subviews {
                walk(subview)
            }
        }

        walk(root)
        return result
    }

    private func largestWebView(
        in webViews: [WKWebView]
    ) -> WKWebView? {

        webViews.max { lhs, rhs in
            let left = lhs.convert(lhs.bounds, to: nil)
            let right = rhs.convert(rhs.bounds, to: nil)

            return left.width * left.height <
                right.width * right.height
        }
    }

    private func collectRefreshComponents(
        in root: UIView
    ) -> [AnyObject] {

        var result: [AnyObject] = []

        func walk(_ view: UIView) {

            guard view.isHidden == false,
                  view.alpha > 0.01 else {
                return
            }

            if let scrollView = view as? UIScrollView {

                if let refresh = scrollView.refreshControl {
                    result.append(refresh)
                }

                // React Native's RCTCustomScrollView can keep its refresh
                // control in a separate customRefreshControl property.
                let customSelector = NSSelectorFromString("customRefreshControl")

                if scrollView.responds(to: customSelector),
                   let value = scrollView.perform(customSelector)?
                    .takeUnretainedValue() as AnyObject?,
                   value.responds(
                    to: NSSelectorFromString("beginRefreshing")
                   ) {
                    TPIOSLog.shared.log(
                        "Reload: customRefreshControl=\(NSStringFromClass(type(of: value)))"
                    )

                    if result.contains(where: {
                        $0 === value
                    }) == false {
                        result.append(value)
                    }
                }

                // MJRefresh exposes mj_header as an Objective-C property.
                let selector = NSSelectorFromString("mj_header")

                if scrollView.responds(to: selector),
                   let value = scrollView.perform(selector)?
                    .takeUnretainedValue() as AnyObject?,
                   value.responds(
                    to: NSSelectorFromString("beginRefreshing")
                   ) {
                    if result.contains(where: {
                        $0 === value
                    }) == false {
                        result.append(value)
                    }
                }
            }

            let className = NSStringFromClass(type(of: view))

            if className.range(
                of: "Refresh",
                options: .caseInsensitive
            ) != nil,
               view.responds(
                to: NSSelectorFromString("beginRefreshing")
               ) {
                let object = view as AnyObject

                if result.contains(where: {
                    $0 === object
                }) == false {
                    result.append(object)
                }
            }

            for subview in view.subviews {
                walk(subview)
            }
        }

        walk(root)
        return result
    }

    private func triggerRefresh(_ component: AnyObject) {

        if let control = component as? UIRefreshControl {
            control.beginRefreshing()
            control.sendActions(
                for: .valueChanged
            )
            return
        }

        let selector = NSSelectorFromString("beginRefreshing")

        guard component.responds(to: selector) else {
            return
        }

        component.perform(selector)
    }

    private func collectScrollViews(
        in root: UIView
    ) -> [UIScrollView] {

        var result: [UIScrollView] = []

        func walk(_ view: UIView) {

            guard view.isHidden == false,
                  view.alpha > 0.01 else {
                return
            }

            if let scrollView = view as? UIScrollView {
                let rect = scrollView.convert(
                    scrollView.bounds,
                    to: nil
                )

                if rect.width > 100,
                   rect.height > 150 {
                    result.append(scrollView)
                }
            }

            for subview in view.subviews {
                walk(subview)
            }
        }

        walk(root)
        return result
    }
}

// TPIOS overlay window được tạo trong TPIOSController.
// Không phụ thuộc trực tiếp vào private property của controller.
private func MTIsOverlayWindowIfAvailable(
    _ window: UIWindow
) -> Bool {

    if window is TPIOSPassThroughWindow {
        return true
    }

    return false
}
