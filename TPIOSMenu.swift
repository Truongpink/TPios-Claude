import UIKit

extension Notification.Name {
    static let tpiosCloseMenu =
        Notification.Name("tpiosCloseMenu")
}

final class TPIOSMenu: UIView,
                       UIGestureRecognizerDelegate {

    private let headerHeight: CGFloat = 66
    private let handleSize: CGFloat = 30

    private let minWidth: CGFloat = 260
    private let minHeight: CGFloat = 300

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusDot = UIView()
    private let closeButton = UIButton(type: .system)

    private let bypassButton = UIButton(type: .system)
    private let quotaButton = UIButton(type: .system)
    private let logButton = UIButton(type: .system)
    private let adBlockButton = UIButton(type: .system)
    private let clockButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private var saleClock: TPIOSSaleClock?

    private let footerLabel = UILabel()
    private let resizeHandle = UILabel()

    private var resizeStartFrame = CGRect.zero
    private var resizeStartPoint = CGPoint.zero

    private var locationView: TPIOSLocation?
    private var quotaScanner: TPIOSQuotaScanner?
    private var adBlocker: TPIOSAdBlock?

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
        layer.borderWidth = 1
        layer.borderColor =
            UIColor.white.withAlphaComponent(0.10).cgColor

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.42
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)

        clipsToBounds = false

        setupHeader()
        setupButtons()
        setupFooter()
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

        statusDot.backgroundColor = UIColor(
            red: 0.30,
            green: 0.95,
            blue: 0.55,
            alpha: 1
        )
        statusDot.layer.cornerRadius = 5

        headerView.addSubview(statusDot)

        titleLabel.text = "TPIOS"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(
            ofSize: 19,
            weight: .bold
        )

        headerView.addSubview(titleLabel)

        subtitleLabel.text = "CONTROL CENTER"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        subtitleLabel.font = .systemFont(
            ofSize: 10,
            weight: .semibold
        )

        headerView.addSubview(subtitleLabel)

        closeButton.setImage(
            UIImage(systemName: "xmark"),
            for: .normal
        )
        closeButton.tintColor =
            UIColor.white.withAlphaComponent(0.75)

        closeButton.backgroundColor =
            UIColor.white.withAlphaComponent(0.07)

        closeButton.layer.cornerRadius = 17

        closeButton.addTarget(
            self,
            action: #selector(closeTapped),
            for: .touchUpInside
        )

        headerView.addSubview(closeButton)
    }

    // MARK: Buttons

    private func setupButtons() {

        configureButton(
            bypassButton,
            title: "Vị trí",
            icon: "location.fill",
            action: #selector(locationTapped)
        )

        configureButton(
            quotaButton,
            title: "Quét",
            icon: "magnifyingglass",
            action: #selector(quotaTapped)
        )

        configureButton(
            logButton,
            title: "Xem log",
            icon: "doc.text.magnifyingglass",
            action: #selector(logTapped)
        )

        configureButton(
            adBlockButton,
            title: "Tắt QC",
            icon: "shield.fill",
            action: #selector(adBlockTapped)
        )

        configureButton(
            clockButton,
            title: "Đồng hồ",
            icon: "clock.fill",
            action: #selector(clockTapped)
        )

        configureButton(
            reloadButton,
            title: "Tải lại trang",
            icon: "arrow.clockwise",
            action: #selector(reloadTapped)
        )

        adBlockButton.backgroundColor = UIColor(
            red: 0.85,
            green: 0.12,
            blue: 0.07,
            alpha: 0.92
        )

        addSubview(bypassButton)
        addSubview(quotaButton)
        addSubview(logButton)
        addSubview(adBlockButton)
        addSubview(clockButton)
        addSubview(reloadButton)
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        icon: String,
        action: Selector
    ) {

        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)

        button.setImage(
            UIImage(systemName: icon),
            for: .normal
        )

        button.tintColor = UIColor.white.withAlphaComponent(0.92)

        button.titleLabel?.font =
            .systemFont(
                ofSize: 15,
                weight: .semibold
            )

        button.backgroundColor = UIColor(
            red: 0.105,
            green: 0.115,
            blue: 0.14,
            alpha: 1
        )

        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor =
            UIColor.white.withAlphaComponent(0.07).cgColor

        button.contentHorizontalAlignment = .left

        button.imageEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 16,
            bottom: 0,
            right: 10
        )

        button.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 10,
            bottom: 0,
            right: 0
        )

        button.contentEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )

        button.addTarget(
            self,
            action: action,
            for: .touchUpInside
        )
    }

    // MARK: Footer

    private func setupFooter() {

        footerLabel.text = "Kéo tiêu đề để di chuyển  •  ↘ để thay đổi kích thước"
        footerLabel.textColor =
            UIColor.white.withAlphaComponent(0.34)

        footerLabel.font = .systemFont(
            ofSize: 9,
            weight: .medium
        )

        footerLabel.textAlignment = .center
        footerLabel.adjustsFontSizeToFitWidth = true
        footerLabel.minimumScaleFactor = 0.75

        addSubview(footerLabel)
    }

    // MARK: Move

    private func setupMove() {

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(moveMenu(_:))
        )

        pan.delegate = self
        pan.cancelsTouchesInView = false

        headerView.addGestureRecognizer(pan)
    }

    @objc private func moveMenu(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let parent = superview else {
            return
        }

        guard gesture.state == .began ||
              gesture.state == .changed else {
            return
        }

        let delta = gesture.translation(in: parent)

        var newFrame = frame

        newFrame.origin.x += delta.x
        newFrame.origin.y += delta.y

        clamp(
            &newFrame,
            in: parent
        )

        frame = newFrame

        gesture.setTranslation(
            .zero,
            in: parent
        )
    }

    // MARK: Resize

    private func setupResize() {

        resizeHandle.text = "↘"
        resizeHandle.textColor =
            UIColor.white.withAlphaComponent(0.42)

        resizeHandle.font = .systemFont(
            ofSize: 19,
            weight: .medium
        )

        resizeHandle.textAlignment = .center
        resizeHandle.isUserInteractionEnabled = true

        addSubview(resizeHandle)

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(resizeMenu(_:))
        )

        pan.cancelsTouchesInView = false

        resizeHandle.addGestureRecognizer(pan)
    }

    @objc private func resizeMenu(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let parent = superview else {
            return
        }

        switch gesture.state {

        case .began:

            resizeStartFrame = frame

            resizeStartPoint =
                gesture.location(in: parent)

        case .changed:

            let point =
                gesture.location(in: parent)

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

            frame = CGRect(
                x: resizeStartFrame.origin.x,
                y: resizeStartFrame.origin.y,
                width: width,
                height: height
            )

        default:
            break
        }
    }

    // MARK: Layout

    override func layoutSubviews() {

        super.layoutSubviews()

        headerView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: headerHeight
        )

        statusDot.frame = CGRect(
            x: 18,
            y: 27,
            width: 10,
            height: 10
        )

        titleLabel.frame = CGRect(
            x: 36,
            y: 12,
            width: max(0, bounds.width - 96),
            height: 25
        )

        subtitleLabel.frame = CGRect(
            x: 36,
            y: 38,
            width: max(0, bounds.width - 96),
            height: 13
        )

        closeButton.frame = CGRect(
            x: bounds.width - 50,
            y: 16,
            width: 34,
            height: 34
        )

        let side: CGFloat = 14
        let gap: CGFloat = 10
        let contentTop = headerHeight + 14

        let buttonWidth =
            max(
                100,
                (bounds.width - side * 2 - gap) / 2
            )

        let buttonHeight: CGFloat = 58

        bypassButton.frame = CGRect(
            x: side,
            y: contentTop,
            width: buttonWidth,
            height: buttonHeight
        )

        quotaButton.frame = CGRect(
            x: side + buttonWidth + gap,
            y: contentTop,
            width: buttonWidth,
            height: buttonHeight
        )

        logButton.frame = CGRect(
            x: side,
            y: contentTop + buttonHeight + gap,
            width: buttonWidth,
            height: buttonHeight
        )

        adBlockButton.frame = CGRect(
            x: side + buttonWidth + gap,
            y: contentTop + buttonHeight + gap,
            width: buttonWidth,
            height: buttonHeight
        )

        clockButton.frame = CGRect(
            x: side,
            y: contentTop + (buttonHeight + gap) * 2,
            width: buttonWidth,
            height: buttonHeight
        )

        reloadButton.frame = CGRect(
            x: side + buttonWidth + gap,
            y: contentTop + (buttonHeight + gap) * 2,
            width: buttonWidth,
            height: buttonHeight
        )

        footerLabel.frame = CGRect(
            x: side,
            y: bounds.height - 42,
            width: max(0, bounds.width - side * 2),
            height: 18
        )

        resizeHandle.frame = CGRect(
            x: bounds.width - handleSize,
            y: bounds.height - handleSize,
            width: handleSize,
            height: handleSize
        )
    }

    // MARK: Close

    @objc private func closeTapped() {

        closeLocation()
        closeScanner()
        closeAdBlock()

        NotificationCenter.default.post(
            name: .tpiosCloseMenu,
            object: nil
        )
    }

    // MARK: Log

    @objc private func logTapped() {
        TPIOSLog.shared.log("Mở cửa sổ log")
        TPIOSLog.shared.show()
    }

    // MARK: Đồng hồ

    @objc private func clockTapped() {

        guard let parent = superview else {
            return
        }

        // Menu có thể bị đóng/mở nhiều lần. Tìm lại đồng hồ đang tồn tại
        // trên overlay trước khi tạo mới, để nút luôn là bật/tắt.
        if saleClock == nil {
            saleClock = parent.subviews
                .compactMap { $0 as? TPIOSSaleClock }
                .last
        }

        if saleClock != nil {
            closeSaleClock()
            return
        }

        let width = min(
            310,
            max(190, parent.bounds.width - 24)
        )

        let height = width / 3.15

        let x = max(
            12,
            (parent.bounds.width - width) / 2
        )

        let y = max(
            20,
            min(
                frame.maxY + 20,
                parent.bounds.height - height - 20
            )
        )

        let clock = TPIOSSaleClock(
            frame: CGRect(
                x: x,
                y: y,
                width: width,
                height: height
            )
        )

        parent.addSubview(clock)

        saleClock = clock

        // Đồng hồ mở song song với menu chính.
        // Không ẩn menu để người dùng có thể bật/tắt trực tiếp.
        clock.start()
    }

    private func closeSaleClock() {

        saleClock?.stop()
        saleClock?.removeFromSuperview()
        saleClock = nil
    }

    // MARK: Tải lại trang

    @objc private func reloadTapped() {
        TPIOSReload.shared.reloadCurrentPage()
    }

    // MARK: Tắt QC

    @objc private func adBlockTapped() {

        guard locationView == nil,
              quotaScanner == nil,
              let parent = superview else {
            return
        }

        let blocker = TPIOSAdBlock.shared

        blocker.onClose = { [weak self] in
            self?.closeAdBlock()
        }

        blocker.prepareForDisplay(frame: frame)
        parent.addSubview(blocker)

        adBlocker = blocker
        isHidden = true

        blocker.beginOrShow()
    }

    private func closeAdBlock() {

        adBlocker?.removeFromSuperview()
        adBlocker = nil
        isHidden = false
    }

    // MARK: Vị trí

    @objc private func locationTapped() {

        guard locationView == nil,
              quotaScanner == nil,
              let parent = superview else {
            return
        }

        let width =
            min(
                frame.width,
                parent.bounds.width
            )

        let height =
            min(
                420,
                parent.bounds.height
            )

        let childFrame = CGRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: width,
            height: height
        )

        let location = TPIOSLocation(
            frame: childFrame
        )

        location.onBack = { [weak self] in
            self?.closeLocation()
        }

        location.onClose = { [weak self] in

            self?.closeLocation()

            NotificationCenter.default.post(
                name: .tpiosCloseMenu,
                object: nil
            )
        }

        parent.addSubview(location)

        locationView = location

        isHidden = true
    }

    private func closeLocation() {

        locationView?.removeFromSuperview()
        locationView = nil

        isHidden = false
    }

    // MARK: Quota Scanner

    @objc private func quotaTapped() {

        guard locationView == nil,
              quotaScanner == nil,
              let parent = superview else {
            return
        }

        let scanner = TPIOSQuotaScanner(
            frame: frame
        )

        scanner.onBack = { [weak self] in
            self?.closeScanner()
        }

        scanner.onClose = { [weak self] in

            self?.closeScanner()

            NotificationCenter.default.post(
                name: .tpiosCloseMenu,
                object: nil
            )
        }

        parent.addSubview(scanner)

        quotaScanner = scanner

        isHidden = true
    }

    private func closeScanner() {

        quotaScanner?.removeFromSuperview()
        quotaScanner = nil

        isHidden = false
    }

    // MARK: Clamp

    private func clamp(
        _ rect: inout CGRect,
        in parent: UIView
    ) {

        let maxX =
            max(
                0,
                parent.bounds.width - rect.width
            )

        let maxY =
            max(
                0,
                parent.bounds.height - rect.height
            )

        rect.origin.x =
            max(
                0,
                min(rect.origin.x, maxX)
            )

        rect.origin.y =
            max(
                0,
                min(rect.origin.y, maxY)
            )
    }

    // MARK: Gesture Delegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        true
    }
}
