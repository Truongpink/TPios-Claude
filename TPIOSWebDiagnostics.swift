import UIKit
import WebKit
import ObjectiveC.runtime

@_cdecl("TPIOSWebDiagnosticsInstall")
public func TPIOSWebDiagnosticsInstall() {
    DispatchQueue.main.async {
        TPIOSWebDiagnostics.install()
    }
}

private final class TPIOSWebDiagnostics {
    private static var installed = false
    private static var originalIMP: IMP?

    static func install() {
        guard !installed else { return }
        installed = true

        let cls: AnyClass = WKWebView.self
        let sel = #selector(UIView.didMoveToWindow)
        guard let method = class_getInstanceMethod(cls, sel) else {
            TPIOSLog.shared.log("AdDiag: không tìm thấy WKWebView.didMoveToWindow")
            return
        }

        originalIMP = method_getImplementation(method)

        let block: @convention(block) (WKWebView) -> Void = { webView in
            if let originalIMP = TPIOSWebDiagnostics.originalIMP {
                typealias Original = @convention(c) (AnyObject, Selector) -> Void
                unsafeBitCast(originalIMP, to: Original.self)(webView, sel)
            }

            guard webView.window != nil else { return }
            TPIOSWebDiagnostics.inspect(webView)
        }

        method_setImplementation(method, imp_implementationWithBlock(block))
        TPIOSLog.shared.log("AdDiag: WKWebView hook đã cài")
    }

    private static func inspect(_ webView: WKWebView) {
        let url = webView.url?.absoluteString ?? "<nil>"
        let frame = webView.convert(webView.bounds, to: nil)

        TPIOSLog.shared.log(
            "AdDiag: WEBVIEW url=\(url) frame=\(String(describing: frame))"
        )

        dumpNativeTree(webView, depth: 0)

        let script = """
        (function() {
            const resources = performance.getEntriesByType("resource")
                .map(x => x.name)
                .filter(x => /doubleclick|googleads|googlesyndication|adservice|googleadservices|adsbygoogle|gma/i.test(x));

            const nodes = Array.from(document.querySelectorAll(
                "iframe, ins, [data-ad-client], [data-ad-slot], [data-google-query-id], [id*='google_ads'], [id*='googleads'], [class*='google-ad'], [class*='ad-container']"
            )).map(el => ({
                tag: el.tagName,
                id: el.id || "",
                cls: typeof el.className === "string" ? el.className : "",
                src: el.src || "",
                rect: el.getBoundingClientRect ? {
                    x: Math.round(el.getBoundingClientRect().x),
                    y: Math.round(el.getBoundingClientRect().y),
                    w: Math.round(el.getBoundingClientRect().width),
                    h: Math.round(el.getBoundingClientRect().height)
                } : null
            }));

            return JSON.stringify({
                href: location.href,
                title: document.title,
                htmlLength: document.documentElement ? document.documentElement.outerHTML.length : 0,
                nodes: nodes.slice(0, 30),
                resources: resources.slice(-50)
            });
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                TPIOSLog.shared.log("AdDiag: JS ERROR \(error.localizedDescription)")
                return
            }

            guard let value = result as? String else {
                TPIOSLog.shared.log("AdDiag: JS result không phải String")
                return
            }

            TPIOSLog.shared.log("AdDiag: JS \(value)")
        }
    }

    private static func dumpNativeTree(_ view: UIView, depth: Int) {
        guard depth <= 4 else { return }

        let name = NSStringFromClass(type(of: view))
        let frame = view.convert(view.bounds, to: nil)

        if depth == 0 ||
           name.range(of: "WK", options: .caseInsensitive) != nil ||
           name.range(of: "Ad", options: .caseInsensitive) != nil ||
           name.range(of: "Web", options: .caseInsensitive) != nil {
            TPIOSLog.shared.log(
                "AdDiag: NATIVE depth=\(depth) class=\(name) frame=\(String(describing: frame)) hidden=\(view.isHidden) alpha=\(view.alpha)"
            )
        }

        for child in view.subviews {
            dumpNativeTree(child, depth: depth + 1)
        }
    }
}
