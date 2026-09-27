import Foundation

final class TPIOSNetworkLog {

    static let shared = TPIOSNetworkLog()

    private var didInstall = false

    private init() {}

    // Hook NSURLSessionTask.resume để log URL mỗi khi có network request
    // thật sự được gửi đi — cách xác nhận khách quan "reload có bắn
    // request mới hay không" mà không cần cài proxy ngoài (Proxyman/
    // Charles), phù hợp máy iOS cũ không cài được app proxy hiện đại.
    //
    // NSURLSessionTask chỉ là abstract base — instance thật lúc runtime
    // luôn thuộc 1 class private khác (vd __NSCFURLSessionTask), và tên
    // class private này đổi khác nhau giữa các bản iOS. Thay vì đoán tên
    // cố định (dễ sai như log bạn vừa gặp), tự tạo 1 dataTask thăm dò để
    // hỏi thẳng runtime "class thật của mày là gì" — không resume() nên
    // không có network request thật nào được gửi, chỉ dùng để lấy class.
    func install() {

        guard didInstall == false else {
            return
        }
        didInstall = true

        let probeSession = URLSession(configuration: .ephemeral)
        let probeTask = probeSession.dataTask(
            with: URL(string: "https://www.apple.com")!
        )
        let targetClass: AnyClass = type(of: probeTask)
        probeTask.cancel()

        TPIOSLog.shared.log(
            "NetLog: class thật của NSURLSessionTask = \(NSStringFromClass(targetClass))"
        )

        let originalSelector = NSSelectorFromString("resume")
        let swizzledSelector = #selector(URLSessionTask.tpios_resume)

        guard
            let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(URLSessionTask.self, swizzledSelector)
        else {
            TPIOSLog.shared.log(
                "NetLog: không lấy được method resume để swizzle"
            )
            didInstall = false
            return
        }

        let didAddMethod = class_addMethod(
            targetClass,
            swizzledSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod,
           let addedMethod = class_getInstanceMethod(targetClass, swizzledSelector) {
            method_exchangeImplementations(originalMethod, addedMethod)
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        TPIOSLog.shared.log(
            "NetLog: đã hook \(NSStringFromClass(targetClass)).resume — request mới sẽ log ở đây, lọc bằng từ khóa \"NetLog:\" trong ô lọc"
        )
    }
}

extension URLSessionTask {

    @objc fileprivate func tpios_resume() {

        let url = self.originalRequest?.url?.absoluteString
            ?? self.currentRequest?.url?.absoluteString
            ?? "<không rõ URL>"

        TPIOSLog.shared.log("NetLog: \(url)")

        // Sau swizzle, gọi lại chính selector "resume" thực chất là gọi
        // implementation GỐC (đã bị hoán đổi bằng
        // method_exchangeImplementations) — không đệ quy vô hạn.
        self.tpios_resume()
    }
}
