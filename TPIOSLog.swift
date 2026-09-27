import UIKit

final class TPIOSLog {

static let shared = TPIOSLog()

private let queue = DispatchQueue(
    label: "com.tpios.logger",
    qos: .utility
)

private var lines: [String] = []
private let maxLines = 2000

private weak var logView: UITextView?
private weak var logWindow: UIView?
private weak var logController: UIViewController?

private weak var filterField: UITextField?
private weak var hideCandidatesButton: UIButton?

// Mặc định ẩn các dòng "ReloadCandidate:" vì đây là nguồn log dài nhất
// (có thể >100 dòng mỗi lần reload) và hiếm khi cần xem trong lúc chỉ
// muốn biết kết quả reload có chạy hay không.
private var hideCandidateLines = true
private var filterText = ""

private var logStartFrame = CGRect.zero

private init() {}

func log(
    _ message: String
) {

    let text =
        "[\(Self.time())] \(message)"

    queue.async { [weak self] in

        guard let self else {
            return
        }

        self.lines.append(text)

        if self.lines.count > self.maxLines {
            self.lines.removeFirst(
                self.lines.count - self.maxLines
            )
        }

        DispatchQueue.main.async {
            self.refreshView()
        }
    }
}

func error(
    _ message: String
) {
    log("ERROR: \(message)")
}

func clear() {

    queue.async { [weak self] in

        guard let self else {
            return
        }

        self.lines.removeAll()

        DispatchQueue.main.async {
            self.refreshView()
        }
    }
}

func show() {

    DispatchQueue.main.async { [weak self] in

        guard let self else {
            return
        }

        if self.logView != nil {
            self.refreshView()
            return
        }

        guard
            let windowScene =
                UIApplication.shared.connectedScenes
                    .compactMap({
                        $0 as? UIWindowScene
                    })
                    .first(where: {
                        $0.activationState != .unattached
                    })
        else {
            self.log(
                "ERROR: Không tìm thấy UIWindowScene"
            )
            return
        }

        let window =
            UIView(
                frame: windowScene.coordinateSpace.bounds
            )

        window.backgroundColor = UIColor(
            red: 0.045,
            green: 0.05,
            blue: 0.065,
            alpha: 0.98
        )
        window.layer.cornerRadius = 24
        window.layer.borderWidth = 1
        window.layer.borderColor =
            UIColor.white.withAlphaComponent(0.10).cgColor
        window.layer.shadowColor = UIColor.black.cgColor
        window.layer.shadowOpacity = 0.42
        window.layer.shadowRadius = 20
        window.layer.shadowOffset = CGSize(width: 0, height: 8)

        window.clipsToBounds = true

        let title =
            UILabel()

        title.text = "TPIOS LOG"
        title.textColor = .white
        title.font =
            .monospacedSystemFont(
                ofSize: 17,
                weight: .bold
            )
        title.textAlignment = .center

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(moveLog(_:))
        )
        title.isUserInteractionEnabled = true
        title.addGestureRecognizer(pan)

        window.addSubview(title)

        let close =
            UIButton(type: .system)

        close.setTitle("×", for: .normal)
        close.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        close.titleLabel?.font =
            .systemFont(
                ofSize: 30,
                weight: .regular
            )

        close.addAction(
            UIAction { [weak self] _ in
                self?.hide()
            },
            for: .touchUpInside
        )

        window.addSubview(close)

        let clear =
            UIButton(type: .system)

        clear.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        clear.layer.cornerRadius = 10

        clear.setTitle(
            "Xóa log",
            for: .normal
        )

        clear.setTitleColor(UIColor.white.withAlphaComponent(0.70), for: .normal)

        clear.titleLabel?.font =
            .monospacedSystemFont(
                ofSize: 13,
                weight: .medium
            )

        clear.addAction(
            UIAction { [weak self] _ in
                self?.clear()
            },
            for: .touchUpInside
        )

        window.addSubview(clear)

        let capture =
            UIButton(type: .system)

        capture.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        capture.layer.cornerRadius = 10

        capture.setTitle(
            "Bắt mạng",
            for: .normal
        )

        capture.setTitleColor(UIColor.white.withAlphaComponent(0.70), for: .normal)

        capture.titleLabel?.font =
            .monospacedSystemFont(
                ofSize: 12,
                weight: .medium
            )

        capture.addAction(
            UIAction { [weak capture] _ in
                TPIOSNetworkLog.shared.install()
                capture?.setTitle("Đang bắt mạng", for: .normal)
            },
            for: .touchUpInside
        )

        window.addSubview(capture)

        let hideCandidates =
            UIButton(type: .system)

        hideCandidates.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        hideCandidates.layer.cornerRadius = 10

        hideCandidates.setTitleColor(UIColor.white.withAlphaComponent(0.70), for: .normal)

        hideCandidates.titleLabel?.font =
            .monospacedSystemFont(
                ofSize: 12,
                weight: .medium
            )

        hideCandidates.addAction(
            UIAction { [weak self] _ in
                self?.toggleHideCandidates()
            },
            for: .touchUpInside
        )

        window.addSubview(hideCandidates)
        self.hideCandidatesButton = hideCandidates
        updateHideCandidatesTitle()

        let filterField =
            UITextField()

        filterField.placeholder = "Lọc log (vd: Reload, WKWebView...)"
        filterField.text = filterText
        filterField.textColor = .white
        filterField.tintColor = .white
        filterField.attributedPlaceholder = NSAttributedString(
            string: "Lọc log (vd: Reload, WKWebView...)",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.35)]
        )
        filterField.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        filterField.layer.cornerRadius = 8
        filterField.font =
            .monospacedSystemFont(
                ofSize: 12,
                weight: .regular
            )
        filterField.autocorrectionType = .no
        filterField.autocapitalizationType = .none
        filterField.clearButtonMode = .whileEditing

        let leftPad = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        filterField.leftView = leftPad
        filterField.leftViewMode = .always

        filterField.addAction(
            UIAction { [weak self, weak filterField] _ in
                self?.filterText = filterField?.text ?? ""
                self?.refreshView()
            },
            for: .editingChanged
        )

        window.addSubview(filterField)
        self.filterField = filterField

        let textView =
            UITextView()

        textView.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )
        textView.textColor = UIColor.white.withAlphaComponent(0.90)
        textView.layer.cornerRadius = 16
        textView.font =
            .monospacedSystemFont(
                ofSize: 12,
                weight: .regular
            )

        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset =
            UIEdgeInsets(
                top: 8,
                left: 8,
                bottom: 8,
                right: 8
            )

        window.addSubview(textView)

        title.translatesAutoresizingMaskIntoConstraints = false
        close.translatesAutoresizingMaskIntoConstraints = false
        clear.translatesAutoresizingMaskIntoConstraints = false
        capture.translatesAutoresizingMaskIntoConstraints = false
        hideCandidates.translatesAutoresizingMaskIntoConstraints = false
        filterField.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            title.topAnchor.constraint(
                equalTo: window.topAnchor,
                constant: 8
            ),

            title.centerXAnchor.constraint(
                equalTo: window.centerXAnchor
            ),

            title.heightAnchor.constraint(
                equalToConstant: 30
            ),

            close.trailingAnchor.constraint(
                equalTo: window.trailingAnchor,
                constant: -6
            ),

            close.topAnchor.constraint(
                equalTo: window.topAnchor,
                constant: 2
            ),

            close.widthAnchor.constraint(
                equalToConstant: 40
            ),

            close.heightAnchor.constraint(
                equalToConstant: 40
            ),

            clear.leadingAnchor.constraint(
                equalTo: window.leadingAnchor,
                constant: 8
            ),

            clear.topAnchor.constraint(
                equalTo: window.topAnchor,
                constant: 6
            ),

            clear.widthAnchor.constraint(
                equalToConstant: 65
            ),

            clear.heightAnchor.constraint(
                equalToConstant: 32
            ),

            capture.leadingAnchor.constraint(
                equalTo: window.leadingAnchor,
                constant: 8
            ),

            capture.topAnchor.constraint(
                equalTo: clear.bottomAnchor,
                constant: 6
            ),

            capture.heightAnchor.constraint(
                equalToConstant: 28
            ),

            capture.widthAnchor.constraint(
                equalToConstant: 78
            ),

            hideCandidates.leadingAnchor.constraint(
                equalTo: capture.trailingAnchor,
                constant: 6
            ),

            hideCandidates.topAnchor.constraint(
                equalTo: capture.topAnchor
            ),

            hideCandidates.widthAnchor.constraint(
                equalToConstant: 90
            ),

            hideCandidates.heightAnchor.constraint(
                equalToConstant: 28
            ),

            filterField.leadingAnchor.constraint(
                equalTo: window.leadingAnchor,
                constant: 8
            ),

            filterField.topAnchor.constraint(
                equalTo: capture.bottomAnchor,
                constant: 6
            ),

            filterField.trailingAnchor.constraint(
                equalTo: window.trailingAnchor,
                constant: -8
            ),

            filterField.heightAnchor.constraint(
                equalToConstant: 28
            ),

            textView.topAnchor.constraint(
                equalTo: filterField.bottomAnchor,
                constant: 6
            ),

            textView.leadingAnchor.constraint(
                equalTo: window.leadingAnchor
            ),

            textView.trailingAnchor.constraint(
                equalTo: window.trailingAnchor
            ),

            textView.bottomAnchor.constraint(
                equalTo: window.bottomAnchor
            )
        ])

        if let hostWindow = windowScene.windows.first {

            hostWindow.addSubview(window)

            let safe =
                hostWindow.safeAreaInsets

            let width: CGFloat =
                min(260, hostWindow.bounds.width - 20)
            let height: CGFloat =
                min(
                    320,
                    hostWindow.bounds.height
                    - safe.top
                    - safe.bottom
                    - 20
                )

            window.frame =
                CGRect(
                    x:
                        max(
                            10,
                            (hostWindow.bounds.width - width) / 2
                        ),
                    y: safe.top + 10,
                    width: width,
                    height: max(280, height)
                )
        }

        self.logView = textView
        self.logWindow = window

        self.refreshView()
    }
}

@objc private func moveLog(
    _ gesture: UIPanGestureRecognizer
) {

    guard
        let window = logWindow,
        let host = window.superview
    else {
        return
    }

    switch gesture.state {

    case .began:
        logStartFrame = window.frame

    case .changed, .ended:

        let translation =
            gesture.translation(in: host)

        var frame = logStartFrame

        frame.origin.x += translation.x
        frame.origin.y += translation.y

        let margin: CGFloat = 10
        let safe = host.safeAreaInsets

        let minX = margin
        let maxX =
            max(
                minX,
                host.bounds.width
                - frame.width
                - margin
            )

        let minY =
            safe.top + margin

        let maxY =
            max(
                minY,
                host.bounds.height
                - safe.bottom
                - frame.height
                - margin
            )

        frame.origin.x =
            min(
                max(frame.origin.x, minX),
                maxX
            )

        frame.origin.y =
            min(
                max(frame.origin.y, minY),
                maxY
            )

        window.frame = frame

    default:
        break
    }
}

func hide() {

    DispatchQueue.main.async { [weak self] in

        guard let self else {
            return
        }

        self.logWindow?.removeFromSuperview()

        self.logWindow = nil
        self.logView = nil
        self.logController = nil
    }
}

private func toggleHideCandidates() {
    hideCandidateLines.toggle()
    updateHideCandidatesTitle()
    refreshView()
}

private func updateHideCandidatesTitle() {
    hideCandidatesButton?.setTitle(
        hideCandidateLines ? "Hiện candidate" : "Ẩn candidate",
        for: .normal
    )
}

private func refreshView() {

    guard
        let textView = logView
    else {
        return
    }

    queue.async { [weak self] in

        guard let self else {
            return
        }

        let snapshot = self.lines

        DispatchQueue.main.async {

            let filter = self.filterText
            let hideCandidates = self.hideCandidateLines

            let filtered =
                snapshot.filter { line in
                    if hideCandidates,
                       line.contains("ReloadCandidate:") {
                        return false
                    }
                    if filter.isEmpty {
                        return true
                    }
                    return line.localizedCaseInsensitiveContains(filter)
                }

            let text =
                filtered.joined(separator: "\n")

            textView.text = text

            if !text.isEmpty {

                let range =
                    NSRange(
                        location:
                            max(
                                0,
                                textView.text.count - 1
                            ),
                        length: 1
                    )

                textView.scrollRangeToVisible(
                    range
                )
            }
        }
    }
}

private static func time() -> String {

    let formatter =
        DateFormatter()

    formatter.dateFormat =
        "HH:mm:ss.SSS"

    return formatter.string(
        from: Date()
    )
}
}
