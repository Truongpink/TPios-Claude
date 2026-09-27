import UIKit
import WebKit
import ObjectiveC.runtime

@_silgen_name("TPIOSModelFilterInstall")
private func TPIOSModelFilterInstall(
    _ className: NSString,
    _ predicateName: NSString,
    _ initializer1: NSString,
    _ initializer2: NSString
) -> Bool

@_silgen_name("TPIOSModelFilterIsInstalled")
private func TPIOSModelFilterIsInstalled() -> Bool

final class TPIOSAdBlock: UIView {
    static let shared = TPIOSAdBlock()
    var onClose: (() -> Void)?

    private struct Profile: Codable {
        let bundleID: String
        let signature: String
        let classes: [String]
        let selectors: [String]
        let mechanism: String?
        let blockedHosts: [String]
        let mechanisms: [String]
        let controllers: [String]
        let paths: [String]
        let formats: [String]
        let webFeatures: [String]
        let strategy: String?
        let modelClass: String?
        let modelPredicate: String?
        let modelInitializer: String?
        let modelInitializer2: String?

        enum CodingKeys: String, CodingKey {
            case bundleID, signature, classes, selectors, mechanism, blockedHosts
            case mechanisms, controllers, paths, formats, webFeatures
            case strategy, modelClass, modelPredicate, modelInitializer, modelInitializer2
        }

        init(
            bundleID: String,
            signature: String,
            classes: [String],
            selectors: [String],
            mechanism: String? = nil,
            blockedHosts: [String] = [],
            mechanisms: [String] = [],
            controllers: [String] = [],
            paths: [String] = [],
            formats: [String] = [],
            webFeatures: [String] = [],
            strategy: String? = nil,
            modelClass: String? = nil,
            modelPredicate: String? = nil,
            modelInitializer: String? = nil,
            modelInitializer2: String? = nil
        ) {
            self.bundleID = bundleID
            self.signature = signature
            self.classes = classes
            self.selectors = selectors
            self.mechanism = mechanism
            self.blockedHosts = blockedHosts
            self.mechanisms = mechanisms
            self.controllers = controllers
            self.paths = paths
            self.formats = formats
            self.webFeatures = webFeatures
            self.strategy = strategy
            self.modelClass = modelClass
            self.modelPredicate = modelPredicate
            self.modelInitializer = modelInitializer
            self.modelInitializer2 = modelInitializer2
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            bundleID = try c.decode(String.self, forKey: .bundleID)
            signature = try c.decode(String.self, forKey: .signature)
            classes = try c.decode([String].self, forKey: .classes)
            selectors = try c.decode([String].self, forKey: .selectors)
            mechanism = try c.decodeIfPresent(String.self, forKey: .mechanism)
            blockedHosts = try c.decodeIfPresent([String].self, forKey: .blockedHosts) ?? []
            mechanisms = try c.decodeIfPresent([String].self, forKey: .mechanisms) ?? []
            controllers = try c.decodeIfPresent([String].self, forKey: .controllers) ?? []
            paths = try c.decodeIfPresent([String].self, forKey: .paths) ?? []
            formats = try c.decodeIfPresent([String].self, forKey: .formats) ?? []
            webFeatures = try c.decodeIfPresent([String].self, forKey: .webFeatures) ?? []
            strategy = try c.decodeIfPresent(String.self, forKey: .strategy)
            modelClass = try c.decodeIfPresent(String.self, forKey: .modelClass)
            modelPredicate = try c.decodeIfPresent(String.self, forKey: .modelPredicate)
            modelInitializer = try c.decodeIfPresent(String.self, forKey: .modelInitializer)
            modelInitializer2 = try c.decodeIfPresent(String.self, forKey: .modelInitializer2)
        }
    }

    private struct ModelCandidate {
        let className: String
        let predicate: String
        let initializer: String
        let initializer2: String
        let score: Int
    }

    private let header = UIView()
    private let title = UILabel()
    private let back = UIButton(type: .system)
    private let close = UIButton(type: .system)
    private let action = UIButton(type: .system)
    private let text = UITextView()
    private let handle = UILabel()
    private var profile: Profile?
    private var timer: Timer?
    private var moveFrame = CGRect.zero
    private var resizeFrame = CGRect.zero
    private var resizePoint = CGPoint.zero
    private var observationTimer: Timer?
    private var observedObjects = Set<String>()
    private var observationStarted = false
    private var rescanInProgress = false
    private var discoveredMechanism = "Chưa phát hiện"
    private var discoveredHosts = [String]()
    private var discoveredMechanisms = [String]()
    private var discoveredControllers = [String]()
    private var discoveredPaths = [String]()
    private var discoveredFormats = [String]()
    private var discoveredWebFeatures = [String]()

    private let keys = [
        "GAD", "AdMob", "FBAd", "FBAudienceNetwork",
        "AppLovin", "MAXAd", "UnityAds", "IronSource",
        "RewardedAd", "InterstitialAd", "NativeAd", "BannerAd",
        "AdView", "Advertisement", "AdContainer"
    ]

    private static var presentationBlockerInstalled = false

    private init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(
            red: 0.045,
            green: 0.05,
            blue: 0.065,
            alpha: 0.98
        )
        layer.cornerRadius = 24
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.42
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        clipsToBounds = true
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
        observationTimer?.invalidate()
    }

    private func setup() {
        header.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )
        addSubview(header)

        title.text = "Tắt QC"
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 17)
        title.textAlignment = .center
        header.addSubview(title)
        title.text = "TẮT QC"
        title.font = .systemFont(ofSize: 19, weight: .bold)

        back.setTitle("‹", for: .normal)
        back.setTitleColor(.white, for: .normal)
        back.addTarget(self, action: #selector(backTap), for: .touchUpInside)
        header.addSubview(back)

        close.setTitle("×", for: .normal)
        close.setTitleColor(.white, for: .normal)
        close.addTarget(self, action: #selector(closeTap), for: .touchUpInside)
        header.addSubview(close)

        action.setTitle("Quét & Tắt QC", for: .normal)
        action.setTitleColor(.white, for: .normal)
        action.backgroundColor = UIColor(
            red: 0.85,
            green: 0.12,
            blue: 0.07,
            alpha: 0.92
        )
        action.layer.cornerRadius = 16
        action.layer.borderWidth = 1
        action.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        action.addTarget(self, action: #selector(actionTap), for: .touchUpInside)
        addSubview(action)

        text.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )
        text.textColor = UIColor.white.withAlphaComponent(0.90)
        text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        text.layer.cornerRadius = 16
        text.layer.borderWidth = 1
        text.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor
        text.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        text.isEditable = false
        text.text = "TẮT QC\n\nChưa có profile.\n\nCơ chế: Chưa phát hiện\n\nTrạng thái: Chưa bật chặn"
        addSubview(text)

        handle.text = "↘"
        handle.textColor = .white
        handle.textAlignment = .center
        handle.isUserInteractionEnabled = true
        addSubview(handle)

        let move = UIPanGestureRecognizer(target: self, action: #selector(moveAdBlock(_:)))
        move.cancelsTouchesInView = false
        header.addGestureRecognizer(move)

        let resize = UIPanGestureRecognizer(target: self, action: #selector(resize(_:)))
        resize.cancelsTouchesInView = false
        handle.addGestureRecognizer(resize)
    }

    static func activateSavedProfileIfPossible() {
        installPresentationBlocker()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            shared.loadProfile()
            guard let saved = shared.profile else { return }

            // Chỉ áp dụng profile đã học. Tuyệt đối không scan/relearn lúc app khởi động.
            // Nếu cơ chế thay đổi, người dùng chủ động bấm "Quét & Tắt QC".
            if shared.installModelFilter(saved) {
                TPIOSLog.shared.log("AdBlock: áp dụng model-filter profile đã lưu, không quét")
                return
            }

            if saved.strategy == "view-web-fallback" {
                shared.activate(saved)
                TPIOSLog.shared.log("AdBlock: áp dụng fallback profile đã lưu, không quét")
            }
        }
    }

    func prepareForDisplay(frame f: CGRect) {
        stop()
        stopObservation()
        removeFromSuperview()
        frame = f
        isHidden = false
        loadProfile()
    }

    func beginOrShow() {
        loadProfile()

        guard let saved = profile else {
            action.setTitle("Quét & Tắt QC", for: .normal)
            text.text = "TẮT QC\n\nChưa có profile.\n\nHãy bấm Quét & Tắt QC để học cơ chế quảng cáo."
            return
        }

        // Mở giao diện chỉ hiển thị profile đã lưu.
        // Không scan khi mở menu để tránh lag.
        if installModelFilter(saved) {
            action.setTitle("Quét lại cơ chế", for: .normal)
            text.text = reportModel(saved, status: "PROFILE MODEL ĐÃ LƯU - ĐANG TẮT QC")
            return
        }

        if saved.strategy == "view-web-fallback" {
            action.setTitle("Quét lại cơ chế", for: .normal)
            activate(saved)
            text.text = report("PROFILE ĐÃ LƯU - ĐANG ÁP DỤNG FALLBACK", (
                classes: saved.classes,
                selectors: saved.selectors
            ))
            refreshDisplay()
            return
        }

        action.setTitle("Quét & Tắt QC", for: .normal)
        text.text = "TẮT QC\n\nCó profile cũ nhưng chưa có strategy tương thích.\n\nBấm Quét lại cơ chế khi quảng cáo xuất hiện."
    }

    @objc private func actionTap() {
        guard !rescanInProgress else { return }

        loadProfile()
        rescanInProgress = true
        stop()
        stopObservation()

        // Tạm dừng profile cũ để quảng cáo có thể xuất hiện và observer bắt cơ chế mới.
        profile = nil
        discoveredMechanism = "Đang quét…"
        discoveredHosts.removeAll()
        discoveredMechanisms.removeAll()
        discoveredControllers.removeAll()
        discoveredPaths.removeAll()
        discoveredFormats.removeAll()
        discoveredWebFeatures.removeAll()

        action.isEnabled = true
        action.setTitle("Đang quét…", for: .normal)
        text.text = "TẮT QC\n\nĐANG QUÉT LẠI CƠ CHẾ…\n\nĐã tạm dừng profile cũ.\nĐang quan sát controller / UIView / WKWebView.\n\nHãy để quảng cáo xuất hiện trong app.\nHệ thống sẽ tự kết thúc quét sau 8 giây."

        TPIOSLog.shared.log("AdBlock: bắt đầu QUÉT LẠI thủ công, profile cũ tạm dừng")
        startObservation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.finishManualRescan()
        }
    }

    private func finishManualRescan() {
        guard rescanInProgress else { return }

        let candidate = discoverModelCandidate()
        let found = scan()
        TPIOSLog.shared.log("AdBlock: kết thúc quét lại classes=\(found.classes.count) selectors=\(found.selectors.count) controllers=\(discoveredControllers.count) hosts=\(discoveredHosts.count)")

        stopObservation()
        rescanInProgress = false

        if let candidate {
            let p = makeModelProfile(candidate)
            if installModelFilter(p) {
                profile = p
                save(p)
                action.setTitle("Quét lại cơ chế", for: .normal)
                text.text = reportModel(p, status: "ĐÃ HỌC LẠI - MODEL FILTER ĐANG HOẠT ĐỘNG")
                return
            }
        }

        let hasLearnedMechanism = discoveredMechanism != "Đang quét…" &&
            (!discoveredHosts.isEmpty || !discoveredControllers.isEmpty || !discoveredMechanisms.isEmpty)

        guard !found.classes.isEmpty || hasLearnedMechanism else {
            profile = nil
            action.setTitle("Quét lại cơ chế", for: .normal)
            text.text = "TẮT QC\n\nCHƯA PHÁT HIỆN CƠ CHẾ QUẢNG CÁO.\n\nTrong 8 giây quét chưa bắt được ad controller, WKWebView hoặc host quảng cáo.\n\nBấm Quét lại cơ chế khi quảng cáo đang/chuẩn bị xuất hiện."
            TPIOSLog.shared.log("AdBlock: quét lại không thu được cơ chế")
            return
        }

        let p = Profile(
            bundleID: bundleID(),
            signature: signature(found),
            classes: found.classes,
            selectors: found.selectors,
            mechanism: discoveredMechanism == "Đang quét…" ? nil : discoveredMechanism,
            blockedHosts: discoveredHosts,
            mechanisms: discoveredMechanisms,
            controllers: discoveredControllers,
            paths: discoveredPaths,
            formats: discoveredFormats,
            webFeatures: discoveredWebFeatures,
            strategy: "view-web-fallback"
        )

        profile = p
        save(p)
        activate(p)
        action.setTitle("Quét lại cơ chế", for: .normal)
        text.text = report("ĐÃ HỌC LẠI CƠ CHẾ - ĐÃ KÍCH HOẠT CHẶN", found)
        refreshDisplay()
        TPIOSLog.shared.log("AdBlock: quét lại thành công, đã lưu profile mới")
    }
    private func activate(_ p: Profile) {
        profile = p
        action.isEnabled = true
        TPIOSAdBlock.installPresentationBlocker()

        if p.strategy == "model-filter", installModelFilter(p) {
            // Model-level filter không cần timer/UIView scan.
            stop()
            stopObservation()
            return
        }

        // Profile đã lưu chỉ được áp dụng một lần khi mở app.
        // Không chạy timer/observation liên tục để tránh làm app chủ chậm.
        stop()
        stopObservation()
        blockAds()
    }

    private func installModelFilter(_ p: Profile) -> Bool {
        guard p.strategy == "model-filter",
              let modelClass = p.modelClass,
              let predicate = p.modelPredicate else {
            return false
        }

        let initializer1 = p.modelInitializer ?? ""
        let initializer2 = p.modelInitializer2 ?? ""

        let ok = TPIOSModelFilterInstall(
            NSString(string: modelClass),
            NSString(string: predicate),
            NSString(string: initializer1),
            NSString(string: initializer2)
        )

        if ok {
            discoveredMechanism = "Model Filter: \(modelClass) / \(predicate)"
        }

        return ok
    }

    private func makeModelProfile(_ candidate: ModelCandidate) -> Profile {
        let signatureInput = [
            bundleID(),
            candidate.className,
            candidate.predicate,
            candidate.initializer,
            candidate.initializer2
        ].joined(separator: "|")

        let signature = hashString(signatureInput)

        return Profile(
            bundleID: bundleID(),
            signature: signature,
            classes: [candidate.className],
            selectors: [
                candidate.className + "." + candidate.predicate,
                candidate.className + "." + candidate.initializer
            ],
            mechanism: "Model Filter",
            blockedHosts: [],
            mechanisms: ["Model Filter"],
            controllers: [],
            paths: [],
            formats: [],
            webFeatures: [],
            strategy: "model-filter",
            modelClass: candidate.className,
            modelPredicate: candidate.predicate,
            modelInitializer: candidate.initializer,
            modelInitializer2: candidate.initializer2
        )
    }

    private func reportModel(_ p: Profile, status: String) -> String {
        """
        TẮT QC

        === CƠ CHẾ QC ===
        Model Filter

        === MODEL ===
        \(p.modelClass ?? "Chưa phát hiện")

        === PREDICATE ===
        \(p.modelPredicate ?? "Chưa phát hiện")

        === INITIALIZER ===
        \(p.modelInitializer ?? "Chưa phát hiện")
        \(p.modelInitializer2.map { "\n\($0)" } ?? "")

        === CHẶN QC ===
        \(status)
        """
    }

    private func hashString(_ input: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }

    private func discoverModelCandidate() -> ModelCandidate? {
        let predicates = [
            "isAds", "isAd", "isAdvertisement",
            "isSponsored", "isPromoted", "isPaid"
        ]

        let initializerNames = [
            "initWithDictionary:error:",
            "initWithDictionary:",
            "initWithData:",
            "initWithJSON:"
        ]

        let modelWords = [
            "model", "item", "feed", "content", "aweme",
            "story", "post", "video", "media"
        ]

        let n = Int(objc_getClassList(nil, 0))
        guard n > 0 else { return nil }

        let p = UnsafeMutablePointer<AnyClass>.allocate(capacity: n)
        defer { p.deallocate() }

        let a = AutoreleasingUnsafeMutablePointer<AnyClass>(p)
        let count = Int(objc_getClassList(a, Int32(n)))

        var best: ModelCandidate?

        for i in 0..<count {
            let cls = p[i]
            let name = NSStringFromClass(cls)

            guard !name.hasPrefix("NS"),
                  !name.hasPrefix("UI"),
                  !name.hasPrefix("WK"),
                  !name.hasPrefix("CA"),
                  !name.hasPrefix("_") else {
                continue
            }

            if let image = class_getImageName(cls) {
                let imageName = String(cString: image)
                if imageName.hasPrefix("/System/Library/") ||
                   imageName.hasPrefix("/usr/lib/") {
                    continue
                }
            }

            var directSelectors = Set<String>()
            var methodCount: UInt32 = 0
            if let methods = class_copyMethodList(cls, &methodCount) {
                for j in 0..<Int(methodCount) {
                    directSelectors.insert(NSStringFromSelector(method_getName(methods[j])))
                }
                free(methods)
            }

            for predicate in predicates where directSelectors.contains(predicate) {
                for initializer in initializerNames where directSelectors.contains(initializer) {
                    let initializer2 = initializer == "initWithDictionary:error:" && directSelectors.contains("init")
                        ? "init"
                        : ""

                    let score =
                        (predicate == "isAds" ? 1000 : 0) +
                        (initializer == "initWithDictionary:error:" ? 250 : 0) +
                        (initializer == "initWithDictionary:" ? 180 : 0) +
                        (initializer == "initWithData:" ? 120 : 0) +
                        (modelWords.contains { name.lowercased().contains($0) } ? 150 : 0)

                    let candidate = ModelCandidate(
                        className: name,
                        predicate: predicate,
                        initializer: initializer,
                        initializer2: initializer2,
                        score: score
                    )

                    if best == nil || candidate.score > best!.score {
                        best = candidate
                    }
                }
            }
        }

        if let best {
            TPIOSLog.shared.log("AdBlock: model candidate \(best.className) / \(best.predicate) / \(best.initializer)")
        }

        return best
    }

    private func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.blockAds()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func startObservation() {
        guard !observationStarted else { return }
        observationStarted = true
        TPIOSLog.shared.log("AdBlock: bắt đầu quan sát view/controller/WebView")

        observationTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.observeRuntime()
        }
        observeRuntime()
    }

    private func stopObservation() {
        observationTimer?.invalidate()
        observationTimer = nil
        observationStarted = false
        observedObjects.removeAll()
    }

    private func observeRuntime() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.observeRuntime() }
            return
        }

        guard let window = overlayRootWindow() else { return }
        guard let root = window.rootViewController else { return }

        observeControllerTree(root, path: "root")

        var presented = root.presentedViewController
        var index = 0
        while let controller = presented {
            index += 1
            observeControllerTree(controller, path: "presented[\(index)]")
            presented = controller.presentedViewController
        }
    }

    private func observeControllerTree(_ controller: UIViewController, path: String) {
        observeController(controller, path: path)
        observeView(controller.view, path: path + ".view", controller: controller)

        for (index, child) in controller.children.enumerated() {
            observeControllerTree(child, path: path + ".child[\(index)]")
        }
    }

    private func observeController(_ controller: UIViewController, path: String) {
        let name = NSStringFromClass(type(of: controller))
        let key = "VC|" + name
        if observedObjects.insert(key).inserted {
            TPIOSLog.shared.log("AdObserve: VC \(path) = \(name)")
        }
    }

    private func observeView(_ view: UIView?, path: String, controller: UIViewController) {
        guard let view else { return }
        let className = NSStringFromClass(type(of: view))
        let shortName = className.components(separatedBy: ".").last ?? className

        if let webView = view as? WKWebView {
            let url = webView.url?.absoluteString ?? "<nil>"
            let key = "WEB|" + className + "|" + url
            if observedObjects.insert(key).inserted {
                TPIOSLog.shared.log("AdObserve: WKWebView \(path) URL=\(url)")
                recordMechanism(url: url)
            }
        }

        if isInterestingName(shortName) {
            let key = "VIEW|" + className
            if observedObjects.insert(key).inserted {
                let frame = view.convert(view.bounds, to: nil)
                TPIOSLog.shared.log("AdObserve: VIEW \(className) frame=\(String(describing: frame)) controller=\(NSStringFromClass(type(of: controller)))")
            }
        }

        if shortName.range(of: "WKContentView", options: .caseInsensitive) != nil {
            let key = "WKCONTENT|" + className
            if observedObjects.insert(key).inserted {
                let frame = view.convert(view.bounds, to: nil)
                TPIOSLog.shared.log("AdObserve: WK CONTENT \(className) frame=\(String(describing: frame)) controller=\(NSStringFromClass(type(of: controller)))")
            }
        }

        if let label = view as? UILabel, let value = label.text, isInterestingText(value) {
            let key = "TEXT|" + className + "|" + value
            if observedObjects.insert(key).inserted {
                TPIOSLog.shared.log("AdObserve: LABEL \(className) text=\(value.prefix(120)) controller=\(NSStringFromClass(type(of: controller)))")
            }
        }

        if let button = view as? UIButton, let value = button.currentTitle, isInterestingText(value) {
            let key = "BUTTON|" + className + "|" + value
            if observedObjects.insert(key).inserted {
                TPIOSLog.shared.log("AdObserve: BUTTON \(className) title=\(value.prefix(120)) controller=\(NSStringFromClass(type(of: controller)))")
            }
        }

        for child in view.subviews {
            observeView(child, path: path + "/" + shortName, controller: controller)
        }
    }

    private func isInterestingName(_ name: String) -> Bool {
        keys.contains { name.range(of: $0, options: .caseInsensitive) != nil } ||
        name.range(of: "WebView", options: .caseInsensitive) != nil ||
        name.range(of: "WK", options: .caseInsensitive) != nil
    }

    private func isInterestingText(_ text: String) -> Bool {
        let value = text.lowercased()
        let terms = ["quảng cáo", "quang cao", "advert", "sponsored", "install", "cài đặt", "app store", "google play", "mở ứng dụng", "arrows go"]
        return terms.contains { value.contains($0) }
    }

    private func blockAds() {
        guard profile != nil,
              let root = overlayRootWindow()?.rootViewController?.view else {
            return
        }

        inspect(root)
        blockWebViews(in: root)
    }

    private func blockWebViews(in view: UIView) {
        if let webView = view as? WKWebView {
            installWebViewBlocker(on: webView)
        }

        for child in view.subviews {
            blockWebViews(in: child)
        }
    }

    private func installWebViewBlocker(on webView: WKWebView) {
        let hosts = discoveredHosts.isEmpty
            ? (profile?.blockedHosts ?? [])
            : discoveredHosts

        let hostJSON = hosts
            .map {
                let escaped = $0
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"" + escaped + "\""
            }
            .joined(separator: ",")

        let script = """
        (function() {
            const hosts = [\(hostJSON), "googleads.g.doubleclick.net", "doubleclick.net"];
            const bad = (value) => {
                const s = String(value || "").toLowerCase();
                return hosts.some(h => s.indexOf(String(h).toLowerCase()) >= 0) ||
                       s.indexOf("googlesyndication.com") >= 0 ||
                       s.indexOf("adservice.google.com") >= 0 ||
                       s.indexOf("googleadservices.com") >= 0 ||
                       s.indexOf("adsbygoogle") >= 0 ||
                       s.indexOf("google_mobile_ads") >= 0 ||
                       s.indexOf("gma") >= 0 && s.indexOf("ad") >= 0;
            };

            const hide = (el) => {
                if (!el || !el.style) return;
                el.style.setProperty("display", "none", "important");
                el.style.setProperty("visibility", "hidden", "important");
                el.style.setProperty("opacity", "0", "important");
                el.style.setProperty("pointer-events", "none", "important");
                el.style.setProperty("height", "0", "important");
                el.style.setProperty("width", "0", "important");
            };

            const inspect = (root) => {
                if (!root) return;

                if (root.nodeType === 1) {
                    const el = root;
                    const attrs = [
                        el.src,
                        el.href,
                        el.id,
                        el.className,
                        el.getAttribute && el.getAttribute("name"),
                        el.getAttribute && el.getAttribute("data-ad-client"),
                        el.getAttribute && el.getAttribute("data-ad-slot"),
                        el.getAttribute && el.getAttribute("data-google-query-id")
                    ];

                    if (attrs.some(bad)) hide(el);

                    if (el.matches && el.matches(
                        "iframe[src*='doubleclick'], iframe[src*='googleads'], iframe[src*='googlesyndication'], iframe[src*='adservice'], ins.adsbygoogle, [data-ad-client], [data-google-query-id]"
                    )) {
                        hide(el);
                    }
                }

                if (root.querySelectorAll) {
                    root.querySelectorAll(
                        "iframe, ins, [data-ad-client], [data-ad-slot], [data-google-query-id], [id*='google_ads'], [id*='googleads'], [class*='google-ad'], [class*='ad-container']"
                    ).forEach(inspect);
                }
            };

            const run = () => inspect(document.documentElement);

            run();

            if (!window.__TPIOS_AD_OBSERVER__) {
                window.__TPIOS_AD_OBSERVER__ = new MutationObserver((mutations) => {
                    mutations.forEach(m => {
                        m.addedNodes && m.addedNodes.forEach(node => inspect(node));
                        if (m.type === "attributes") inspect(m.target);
                    });
                });

                window.__TPIOS_AD_OBSERVER__.observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ["src", "href", "id", "class", "style", "data-ad-client", "data-ad-slot", "data-google-query-id"]
                });
            }
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func relearnProfile(from found: (classes: [String], selectors: [String])) {
        if let candidate = discoverModelCandidate() {
            let p = makeModelProfile(candidate)
            if installModelFilter(p) {
                profile = p
                save(p)
                action.setTitle("Đang tắt QC", for: .normal)
                return
            }
        }

        guard !found.classes.isEmpty else {
            stop()
            stopObservation()
            action.setTitle("Quét & Tắt QC", for: .normal)
            return
        }

        let p = Profile(
            bundleID: bundleID(),
            signature: signature(found),
            classes: found.classes,
            selectors: found.selectors,
            mechanism: discoveredMechanism == "Chưa phát hiện" ? nil : discoveredMechanism,
            blockedHosts: discoveredHosts,
            mechanisms: discoveredMechanisms,
            controllers: discoveredControllers,
            paths: discoveredPaths,
            formats: discoveredFormats,
            webFeatures: discoveredWebFeatures,
            strategy: "view-web-fallback"
        )

        profile = p
        save(p)
        activate(p)
        action.setTitle("Đang tắt QC", for: .normal)
    }

    private func sharedStopForRelearn() {
        stop()
        stopObservation()
        action.setTitle("Quét & Tắt QC", for: .normal)
    }

    private func overlayRootWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first(where: { $0 !== self.superview?.window })
            ?? UIApplication.shared.windows.first
    }

    private func inspect(_ v: UIView) {
        if v === self || v.isHidden || v.alpha <= 0.01 {
            return
        }

        let className = NSStringFromClass(type(of: v))
        let shortName = className.components(separatedBy: ".").last ?? className

        if let p = profile, p.classes.contains(className) {
            v.isHidden = true
            TPIOSLog.shared.log("AdBlock: ẩn learned view " + shortName)
            return
        }

        if isAdViewName(shortName) {
            v.isHidden = true
            TPIOSLog.shared.log("AdBlock: ẩn ad view " + shortName)
            return
        }

        for child in v.subviews {
            inspect(child)
        }
    }

    private func isAdViewName(_ name: String) -> Bool {
        keys.contains {
            name.range(of: $0, options: .caseInsensitive) != nil
        }
    }

    private static func installPresentationBlocker() {
        guard !presentationBlockerInstalled else { return }

        let original = #selector(UIViewController.present(_:animated:completion:))
        let replacement = #selector(UIViewController.tpios_present(_:animated:completion:))

        guard class_getInstanceMethod(UIViewController.self, original) != nil,
              class_getInstanceMethod(UIViewController.self, replacement) != nil else {
            TPIOSLog.shared.log("AdBlock: không cài được presentation hook")
            return
        }

        method_exchangeImplementations(
            class_getInstanceMethod(UIViewController.self, original)!,
            class_getInstanceMethod(UIViewController.self, replacement)!
        )

        presentationBlockerInstalled = true
        TPIOSLog.shared.log("AdBlock: presentation hook đã cài")
    }

    fileprivate static func shouldBlockPresentation(_ viewController: UIViewController) -> Bool {
        let name = NSStringFromClass(type(of: viewController)).lowercased()

        let blocked =
            name.contains("skstoreproductviewcontroller") ||
            name.contains("storeproductviewcontroller")

        TPIOSLog.shared.log("AdObserve: PRESENT " + name)
        shared.recordPresentationMechanism(name)

        if blocked {
            TPIOSLog.shared.log("AdBlock: chặn StoreKit controller " + name)
        }

        return blocked
    }

    private func scan() -> (classes: [String], selectors: [String]) {
        var c = Set<String>()
        var s = Set<String>()

        let n = Int(objc_getClassList(nil, 0))
        guard n > 0 else { return ([], []) }

        let p = UnsafeMutablePointer<AnyClass>.allocate(capacity: n)
        defer { p.deallocate() }

        let a = AutoreleasingUnsafeMutablePointer<AnyClass>(p)
        let count = Int(objc_getClassList(a, Int32(n)))

        for i in 0..<count {
            let cls = p[i]
            let name = NSStringFromClass(cls)

            if keys.contains(where: {
                name.range(of: $0, options: .caseInsensitive) != nil
            }) {
                c.insert(name)
            }

            var mc: UInt32 = 0
            if let methods = class_copyMethodList(cls, &mc) {
                for j in 0..<Int(mc) {
                    let sel = NSStringFromSelector(method_getName(methods[j]))

                    if keys.contains(where: {
                        sel.range(of: $0, options: .caseInsensitive) != nil
                    }) {
                        s.insert(name + "." + sel)
                    }
                }
                free(methods)
            }
        }

        return (c.sorted(), s.sorted())
    }

    private func signature(_ found: (classes: [String], selectors: [String])) -> String {
        hashString((found.classes + found.selectors).joined(separator: "|"))
    }

    private func key() -> String {
        "TPIOS.AdBlock." + bundleID()
    }

    private func bundleID() -> String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle"
    }

    private func save(_ p: Profile) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(p), forKey: key())
        } catch {
            TPIOSLog.shared.error("AdBlock: lưu profile lỗi")
        }
    }

    private func loadProfile() {
        guard profile == nil,
              let data = UserDefaults.standard.data(forKey: key()) else {
            return
        }

        do {
            let loaded = try JSONDecoder().decode(Profile.self, from: data)
            profile = loaded
            discoveredMechanism = loaded.mechanism ?? "Chưa phát hiện"
            discoveredHosts = loaded.blockedHosts
            discoveredMechanisms = loaded.mechanisms
            discoveredControllers = loaded.controllers
            discoveredPaths = loaded.paths
            discoveredFormats = loaded.formats
            discoveredWebFeatures = loaded.webFeatures
        } catch {
            UserDefaults.standard.removeObject(forKey: key())
        }
    }

    private func addUnique(_ value: String, to array: inout [String], limit: Int = 50) {
        guard !value.isEmpty, !array.contains(value) else { return }
        array.append(value)
        if array.count > limit {
            array.removeFirst(array.count - limit)
        }
    }

    private func persistDiscoveredMetadata() {
        guard let p = profile else { return }

        let updated = Profile(
            bundleID: p.bundleID,
            signature: p.signature,
            classes: p.classes,
            selectors: p.selectors,
            mechanism: discoveredMechanism == "Chưa phát hiện" ? p.mechanism : discoveredMechanism,
            blockedHosts: discoveredHosts,
            mechanisms: discoveredMechanisms,
            controllers: discoveredControllers,
            paths: discoveredPaths,
            formats: discoveredFormats,
            webFeatures: discoveredWebFeatures,
            strategy: p.strategy,
            modelClass: p.modelClass,
            modelPredicate: p.modelPredicate,
            modelInitializer: p.modelInitializer,
            modelInitializer2: p.modelInitializer2
        )

        profile = updated
        save(updated)
    }

    private func recordPresentationMechanism(_ controllerName: String) {
        let name = controllerName
        addUnique(name, to: &discoveredControllers)

        let lower = name.lowercased()
        if lower.contains("gad") || lower.contains("admob") {
            addUnique("Google Mobile Ads / AdMob", to: &discoveredMechanisms)
            discoveredMechanism = "Google Mobile Ads / AdMob"
        } else if lower.contains("applovin") {
            addUnique("AppLovin / MAX", to: &discoveredMechanisms)
            discoveredMechanism = "AppLovin / MAX"
        } else if lower.contains("unityads") {
            addUnique("Unity Ads", to: &discoveredMechanisms)
            discoveredMechanism = "Unity Ads"
        } else if lower.contains("ironsource") {
            addUnique("ironSource", to: &discoveredMechanisms)
            discoveredMechanism = "ironSource"
        } else if lower.contains("fbad") || lower.contains("fbaudience") {
            addUnique("Meta Audience Network", to: &discoveredMechanisms)
            discoveredMechanism = "Meta Audience Network"
        }

        persistDiscoveredMetadata()
    }

    private func recordMechanism(url: String) {
        guard let components = URLComponents(string: url),
              let host = components.host,
              !host.isEmpty else { return }

        addUnique(host, to: &discoveredHosts)

        let lower = host.lowercased()
        if lower.contains("doubleclick.net") || lower.contains("googleads") {
            addUnique("Google Ads / DoubleClick (WKWebView)", to: &discoveredMechanisms)
            discoveredMechanism = "Google Ads / DoubleClick (WKWebView)"
        } else {
            addUnique("WKWebView / " + host, to: &discoveredMechanisms)
            discoveredMechanism = "WKWebView / " + host
        }

        addUnique(components.path, to: &discoveredPaths)

        if let format = components.queryItems?.first(where: {
            $0.name.lowercased() == "format"
        })?.value {
            addUnique(format, to: &discoveredFormats)
        }

        if lower.contains("omsdk") || lower.contains("omid") {
            addUnique("OMID / Open Measurement SDK", to: &discoveredWebFeatures)
        }

        persistDiscoveredMetadata()
        refreshDisplay()
    }

    private func refreshDisplay() {
        guard let currentText = text.text,
              currentText.hasPrefix("TẮT QC") else {
            return
        }

        let detail = currentText.components(
            separatedBy: "\n\n=== CHI TIẾT PROFILE ==="
        ).last ?? currentText

        let base = detail.components(
            separatedBy: "\n\n=== CƠ CHẾ QC ==="
        ).last ?? detail

        let profileDetail: String
        if let markerRange = detail.range(of: "\n\n=== CƠ CHẾ QC ===") {
            profileDetail = String(detail[..<markerRange.lowerBound])
        } else {
            profileDetail = detail
        }

        var output =
            "TẮT QC\n\n" +
            "=== CƠ CHẾ QC ===\n" +
            discoveredMechanism

        if !discoveredHosts.isEmpty {
            output +=
                "\n\n=== HOST QC ===\n" +
                discoveredHosts.joined(separator: "\n")
        }

        if !discoveredControllers.isEmpty {
            output +=
                "\n\n=== CONTROLLER QC ===\n" +
                discoveredControllers.joined(separator: "\n")
        }

        if !discoveredPaths.isEmpty {
            output +=
                "\n\n=== PATH QC ===\n" +
                discoveredPaths.joined(separator: "\n")
        }

        if !discoveredFormats.isEmpty {
            output +=
                "\n\n=== FORMAT QC ===\n" +
                discoveredFormats.joined(separator: "\n")
        }

        if !discoveredWebFeatures.isEmpty {
            output +=
                "\n\n=== THÀNH PHẦN WEB ===\n" +
                discoveredWebFeatures.joined(separator: "\n")
        }

        if !discoveredMechanisms.isEmpty {
            output +=
                "\n\n=== CƠ CHẾ ĐÃ LƯU ===\n" +
                discoveredMechanisms.joined(separator: "\n")
        }

        output +=
            "\n\n=== CHẶN QC ===\n" +
            (timer != nil ? "ĐANG BẬT" : "ĐANG TẮT")

        if !profileDetail.isEmpty &&
           !profileDetail.hasPrefix("TẮT QC") {
            output += "\n\n=== CHI TIẾT PROFILE ===\n" + profileDetail
        }

        text.text = output
    }

    private func report(
        _ h: String,
        _ f: (classes: [String], selectors: [String])
    ) -> String {
        var output =
            "TẮT QC\n\n" +
            "=== CƠ CHẾ QC ===\n" +
            discoveredMechanism

        if !discoveredHosts.isEmpty {
            output +=
                "\n\n=== HOST QC ===\n" +
                discoveredHosts.joined(separator: "\n")
        }

        if !discoveredControllers.isEmpty {
            output +=
                "\n\n=== CONTROLLER QC ===\n" +
                discoveredControllers.joined(separator: "\n")
        }

        if !discoveredPaths.isEmpty {
            output +=
                "\n\n=== PATH QC ===\n" +
                discoveredPaths.joined(separator: "\n")
        }

        if !discoveredFormats.isEmpty {
            output +=
                "\n\n=== FORMAT QC ===\n" +
                discoveredFormats.joined(separator: "\n")
        }

        if !discoveredWebFeatures.isEmpty {
            output +=
                "\n\n=== THÀNH PHẦN WEB ===\n" +
                discoveredWebFeatures.joined(separator: "\n")
        }

        if !discoveredMechanisms.isEmpty {
            output +=
                "\n\n=== CƠ CHẾ ĐÃ LƯU ===\n" +
                discoveredMechanisms.joined(separator: "\n")
        }

        output +=
            "\n\n=== CHẶN QC ===\n" +
            (timer != nil ? "ĐANG BẬT" : "ĐANG TẮT")

        output +=
            "\n\n=== CHI TIẾT PROFILE ===\n" +
            h +
            "\n\nBundle: " +
            bundleID() +
            "\n\n=== CLASSES ===\n" +
            f.classes.prefix(50).joined(separator: "\n") +
            "\n\n=== SELECTORS ===\n" +
            f.selectors.prefix(80).joined(separator: "\n")

        return output
    }

    @objc private func backTap() {
        onClose?()
    }

    @objc private func closeTap() {
        onClose?()
    }

    @objc private func moveAdBlock(_ g: UIPanGestureRecognizer) {
        guard let p = superview else { return }

        switch g.state {
        case .began:
            moveFrame = frame

        case .changed, .ended:
            let d = g.translation(in: p)
            var f = moveFrame
            f.origin.x = max(
                0,
                min(moveFrame.origin.x + d.x, max(0, p.bounds.width - f.width))
            )
            f.origin.y = max(
                0,
                min(moveFrame.origin.y + d.y, max(0, p.bounds.height - f.height))
            )
            frame = f

        default:
            break
        }
    }

    @objc private func resize(_ g: UIPanGestureRecognizer) {
        guard let p = superview else { return }

        switch g.state {
        case .began:
            resizeFrame = frame
            resizePoint = g.location(in: p)

        case .changed:
            let q = g.location(in: p)
            let w = max(
                260,
                min(
                    resizeFrame.width + q.x - resizePoint.x,
                    p.bounds.width - resizeFrame.origin.x
                )
            )
            let h = max(
                320,
                min(
                    resizeFrame.height + q.y - resizePoint.y,
                    p.bounds.height - resizeFrame.origin.y
                )
            )

            frame = CGRect(
                x: resizeFrame.origin.x,
                y: resizeFrame.origin.y,
                width: w,
                height: h
            )

        default:
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        header.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 66)
        back.frame = CGRect(x: 4, y: 14, width: 40, height: 38)
        title.frame = CGRect(x: 46, y: 11, width: bounds.width - 92, height: 44)
        close.frame = CGRect(x: bounds.width - 46, y: 16, width: 42, height: 36)
        action.frame = CGRect(x: 16, y: 82, width: bounds.width - 32, height: 48)
        text.frame = CGRect(
            x: 16,
            y: 144,
            width: bounds.width - 32,
            height: max(0, bounds.height - 160)
        )
        handle.frame = CGRect(
            x: bounds.width - 30,
            y: bounds.height - 30,
            width: 30,
            height: 30
        )
    }

    private func matches(
        _ p: Profile,
        _ found: (classes: [String], selectors: [String])
    ) -> Bool {
        let classes = Set(found.classes)
        let selectors = Set(found.selectors)

        let classMatch =
            !p.classes.isEmpty &&
            p.classes.allSatisfy { classes.contains($0) }

        let selectorMatch =
            p.selectors.isEmpty ||
            p.selectors.allSatisfy { selectors.contains($0) }

        return classMatch && selectorMatch
    }
}

private extension UIViewController {
    @objc func tpios_present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        if TPIOSAdBlock.shouldBlockPresentation(viewControllerToPresent) {
            completion?()
            return
        }

        tpios_present(viewControllerToPresent, animated: flag, completion: completion)
    }
}
