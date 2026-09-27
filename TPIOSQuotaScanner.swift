import UIKit
import ObjectiveC.runtime

final class TPIOSQuotaScanner: UIView,
                                UIGestureRecognizerDelegate {

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    private let headerHeight: CGFloat = 66
    private let handleSize: CGFloat = 30

    private let minWidth: CGFloat = 240
    private let minHeight: CGFloat = 300

    private let headerView = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private let scanButton = UIButton(type: .system)
    private let resultTextView = UITextView()
    private let resizeHandle = UILabel()

    private var resizeStartFrame = CGRect.zero
    private var resizeStartPoint = CGPoint.zero

    private var isScanning = false

    private let keywords = [
        "quota",
        "usage",
        "remaining",
        "limit",
        "reset",
        "allowance",
        "ratelimit",
        "rate_limit",
        "upload",
        "attachment",
        "image",
        "vision",
        "file"
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {

        backgroundColor = UIColor(
            red: 0.045,
            green: 0.05,
            blue: 0.065,
            alpha: 0.98
        )

        layer.cornerRadius = 24
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.42
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.borderWidth = 1
        layer.borderColor =
            UIColor.white.withAlphaComponent(0.12).cgColor

        clipsToBounds = true

        setupHeader()
        setupScanButton()
        setupResult()
        setupResize()
        setupMove()
    }

    // MARK: Header

    private func setupHeader() {

        headerView.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )

        headerView.layer.cornerRadius = 24
        headerView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]

        addSubview(headerView)

        backButton.setTitle(
            "‹",
            for: .normal
        )

        backButton.setTitleColor(
            .white,
            for: .normal
        )

        backButton.titleLabel?.font =
            .systemFont(
                ofSize: 30
            )

        backButton.addTarget(
            self,
            action: #selector(backTapped),
            for: .touchUpInside
        )

        headerView.addSubview(backButton)

        titleLabel.text =
            "QUOTA SCANNER"

        titleLabel.textColor =
            .white

        titleLabel.font =
            .systemFont(
                ofSize: 17,
                weight: .bold
            )

        titleLabel.textAlignment =
            .center

        headerView.addSubview(titleLabel)

        closeButton.setTitle(
            "×",
            for: .normal
        )

        closeButton.setTitleColor(
            .white,
            for: .normal
        )

        closeButton.titleLabel?.font =
            .systemFont(
                ofSize: 28
            )

        closeButton.addTarget(
            self,
            action: #selector(closeTapped),
            for: .touchUpInside
        )

        headerView.addSubview(closeButton)
    }

    // MARK: Scan

    private func setupScanButton() {

        scanButton.setTitle(
            "Quét",
            for: .normal
        )

        scanButton.setTitleColor(
            .white,
            for: .normal
        )

        scanButton.titleLabel?.font =
            .systemFont(
                ofSize: 16,
                weight: .semibold
            )

        scanButton.backgroundColor = UIColor(
            red: 0.12,
            green: 0.13,
            blue: 0.16,
            alpha: 1
        )
        scanButton.layer.cornerRadius = 16
        scanButton.layer.borderWidth = 1
        scanButton.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        scanButton.addTarget(
            self,
            action: #selector(scanTapped),
            for: .touchUpInside
        )

        addSubview(scanButton)
    }

    // MARK: Result

    private func setupResult() {

        resultTextView.backgroundColor =
            UIColor(
                red: 0.075,
                green: 0.085,
                blue: 0.105,
                alpha: 1
            )

        resultTextView.textColor =
            UIColor.white.withAlphaComponent(0.92)

        resultTextView.font =
            .monospacedSystemFont(
                ofSize: 13,
                weight: .regular
            )

        resultTextView.isEditable = false
        resultTextView.isSelectable = true

        resultTextView.text =
            initialText()

        resultTextView.layer.cornerRadius = 16
        resultTextView.layer.borderWidth = 1
        resultTextView.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor

        resultTextView.textContainerInset =
            UIEdgeInsets(
                top: 12,
                left: 12,
                bottom: 12,
                right: 12
            )

        addSubview(resultTextView)
    }

    // MARK: Resize

    private func setupResize() {

        resizeHandle.text = "↘"
        resizeHandle.textColor =
            UIColor.white.withAlphaComponent(0.65)

        resizeHandle.font =
            .systemFont(
                ofSize: 20,
                weight: .medium
            )

        resizeHandle.textAlignment = .center
        resizeHandle.isUserInteractionEnabled = true

        addSubview(resizeHandle)

        let pan =
            UIPanGestureRecognizer(
                target: self,
                action: #selector(resize(_:))
            )

        pan.cancelsTouchesInView = false
        resizeHandle.addGestureRecognizer(pan)
    }

    @objc private func resize(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let parent = superview else {
            return
        }

        switch gesture.state {

        case .began:

            resizeStartFrame = frame

            resizeStartPoint =
                gesture.location(
                    in: parent
                )

        case .changed:

            let point =
                gesture.location(
                    in: parent
                )

            let dx =
                point.x - resizeStartPoint.x

            let dy =
                point.y - resizeStartPoint.y

            let width =
                max(
                    minWidth,
                    min(
                        resizeStartFrame.width + dx,
                        parent.bounds.width -
                        resizeStartFrame.origin.x
                    )
                )

            let height =
                max(
                    minHeight,
                    min(
                        resizeStartFrame.height + dy,
                        parent.bounds.height -
                        resizeStartFrame.origin.y
                    )
                )

            frame =
                CGRect(
                    x: resizeStartFrame.origin.x,
                    y: resizeStartFrame.origin.y,
                    width: width,
                    height: height
                )

        default:
            break
        }
    }

    // MARK: Move

    private func setupMove() {

        let pan =
            UIPanGestureRecognizer(
                target: self,
                action: #selector(moveScanner(_:))
            )

        pan.delegate = self
        pan.cancelsTouchesInView = false

        headerView.addGestureRecognizer(pan)
    }

  @objc private func moveScanner(
    _ gesture: UIPanGestureRecognizer
) {

        guard let parent = superview else {
            return
        }

        guard gesture.state == .began ||
              gesture.state == .changed else {
            return
        }

        let delta =
            gesture.translation(
                in: parent
            )

        var newFrame = frame

        newFrame.origin.x += delta.x
        newFrame.origin.y += delta.y

        let maxX =
            max(
                0,
                parent.bounds.width - newFrame.width
            )

        let maxY =
            max(
                0,
                parent.bounds.height - newFrame.height
            )

        newFrame.origin.x =
            max(
                0,
                min(
                    newFrame.origin.x,
                    maxX
                )
            )

        newFrame.origin.y =
            max(
                0,
                min(
                    newFrame.origin.y,
                    maxY
                )
            )

        frame = newFrame

        gesture.setTranslation(
            .zero,
            in: parent
        )
    }

    // MARK: Layout

    override func layoutSubviews() {

        super.layoutSubviews()

        headerView.frame =
            CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: headerHeight
            )

        backButton.frame =
            CGRect(
                x: 4,
                y: 3,
                width: 40,
                height: 38
            )

        titleLabel.frame =
            CGRect(
                x: 46,
                y: 0,
                width:
                    max(
                        0,
                        bounds.width - 92
                    ),
                height: headerHeight
            )

        closeButton.frame =
            CGRect(
                x:
                    bounds.width - 46,
                y: 4,
                width: 42,
                height: 36
            )

        scanButton.frame =
            CGRect(
                x: 16,
                y: 82,
                width:
                    max(
                        0,
                        bounds.width - 32
                    ),
                height: 44
            )

        resultTextView.frame =
            CGRect(
                x: 16,
                y: 138,
                width:
                    max(
                        0,
                        bounds.width - 32
                    ),
                height:
                    max(
                        0,
                        bounds.height - 154
                    )
            )

        resizeHandle.frame =
            CGRect(
                x:
                    bounds.width - handleSize,
                y:
                    bounds.height - handleSize,
                width: handleSize,
                height: handleSize
            )
    }

    // MARK: Back / Close

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: Scan

    @objc private func scanTapped() {

        guard !isScanning else {
            return
        }

        isScanning = true

        scanButton.isEnabled = false

        scanButton.setTitle(
            "Đang quét...",
            for: .normal
        )

        resultTextView.text = """
        QUOTA SCANNER

        Đang quét runtime...

        Vui lòng chờ.
        """

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in

            guard let self else {
                return
            }

            let result =
                self.performScan()

            DispatchQueue.main.async {

                guard self.superview != nil else {
                    return
                }

                self.isScanning = false
                self.scanButton.isEnabled = true

                self.scanButton.setTitle(
                    "Quét Lại",
                    for: .normal
                )

                self.resultTextView.text =
                    result
            }
        }
    }

    // MARK: Runtime Scan

    private func performScan() -> String {

        var classes = [String]()
        var selectors = [String]()

        var seenClasses = Set<String>()
        var seenSelectors = Set<String>()

        let classList =
            getAllClasses()

        guard !classList.isEmpty else {

            return """
            QUOTA SCANNER

            ❌ Không thể quét.

            Không tìm thấy Objective-C
            runtime class nào trong app.
            """
        }

        for cls in classList {

            let className =
                NSStringFromClass(cls)

            let lower =
                className.lowercased()

            if keywords.contains(
                where: {
                    lower.contains($0)
                }
            ),
            !seenClasses.contains(className) {

                seenClasses.insert(className)
                classes.append(className)
            }

            var methodCount: UInt32 = 0

            guard let methods =
                    class_copyMethodList(
                        cls,
                        &methodCount
                    ) else {
                continue
            }

            for index in
                0..<Int(methodCount) {

                let selector =
                    method_getName(
                        methods[index]
                    )

                let name =
                    NSStringFromSelector(
                        selector
                    )

                let lowerName =
                    name.lowercased()

                if keywords.contains(
                    where: {
                        lowerName.contains($0)
                    }
                ) {

                    let value =
                        "\(className).\(name)"

                    if !seenSelectors.contains(
                        value
                    ) {

                        seenSelectors.insert(value)
                        selectors.append(value)
                    }
                }
            }

            free(methods)
        }

        let classResults =
            classes.sorted().prefix(80)

        let selectorResults =
            selectors.sorted().prefix(120)

        var output =
            """
            QUOTA SCANNER

            Runtime classes: \(classList.count)

            === QUOTA STATUS ===
            Quota ngày : Không xác định
            Đã dùng   : Không xác định
            Còn lại   : Không xác định
            Reset     : Không xác định

            Lưu ý: class/selector tìm thấy chỉ là dấu hiệu nghiên cứu, không phải quota thực tế.

            === MATCHED CLASSES ===
            """

        if classResults.isEmpty {
            output += "\nKhông phát hiện."
        } else {
            for item in classResults {
                output += "\n\(item)"
            }
        }

        output +=
            "\n\n=== MATCHED SELECTORS ==="

        if selectorResults.isEmpty {
            output += "\nKhông phát hiện."
        } else {
            for item in selectorResults {
                output += "\n\(item)"
            }
        }

        return output
    }

    // MARK: Objective-C Runtime

    private func getAllClasses()
        -> [AnyClass] {

        let count =
            Int(
                objc_getClassList(
                    nil,
                    0
                )
            )

        guard count > 0 else {
            return []
        }

        let pointer =
            UnsafeMutablePointer<AnyClass>
                .allocate(
                    capacity: count
                )

        defer {
            pointer.deallocate()
        }

        let autoreleasing =
            AutoreleasingUnsafeMutablePointer<AnyClass>(
                pointer
            )

        let actual =
            Int(
                objc_getClassList(
                    autoreleasing,
                    Int32(count)
                )
            )

        guard actual > 0 else {
            return []
        }

        var result =
            [AnyClass]()

        result.reserveCapacity(actual)

        for index in 0..<actual {
            result.append(pointer[index])
        }

        return result
    }

    // MARK: Initial Text

    private func initialText() -> String {

        """
        QUOTA SCANNER

        Trạng thái:
        Chưa quét.

        Scanner chỉ phân tích
        runtime/UI của app hiện tại.

        Không lấy:
        - Token
        - Cookie
        - Password
        - Credential

        Bấm "Quét" để bắt đầu.
        """
    }

    // MARK: Gesture Delegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {

        let view = touch.view

        if view === backButton ||
           view === closeButton ||
           view === scanButton ||
           view === resizeHandle ||
           view === resultTextView {

            return false
        }

        return true
    }
}