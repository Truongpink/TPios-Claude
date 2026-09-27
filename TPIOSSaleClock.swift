import UIKit

final class TPIOSSaleClock: UIView, UIGestureRecognizerDelegate {

    private let timeBackground = UIView()
    private let hourLabel = UILabel()
    private let minuteLabel = UILabel()
    private let secondLabel = UILabel()
    private let tenthLabel = UILabel()
    private let firstColon = UILabel()
    private let secondColon = UILabel()
    private let decimalPoint = UILabel()
    private let resizeHandle = UILabel()

    private var clockTimer: Timer?
    private var lastTenth: Int = -1

    private var moveStartFrame = CGRect.zero
    private var moveStartPoint = CGPoint.zero

    private var resizeStartFrame = CGRect.zero
    private var resizeStartPoint = CGPoint.zero

    private let baseWidth: CGFloat = 310
    private let baseHeight: CGFloat = 98
    private let aspectRatio: CGFloat = 310.0 / 98.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        clockTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setup() {

        backgroundColor = UIColor.black.withAlphaComponent(0.82)

        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 7)

        clipsToBounds = false

        timeBackground.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        timeBackground.layer.cornerRadius = 16
        addSubview(timeBackground)

        configureNumberLabel(hourLabel)
        configureNumberLabel(minuteLabel)
        configureNumberLabel(secondLabel)
        configureTenthLabel(tenthLabel)

        configureColon(firstColon)
        configureColon(secondColon)
        configureDecimalPoint(decimalPoint)

        timeBackground.addSubview(hourLabel)
        timeBackground.addSubview(firstColon)
        timeBackground.addSubview(minuteLabel)
        timeBackground.addSubview(secondColon)
        timeBackground.addSubview(secondLabel)
        timeBackground.addSubview(decimalPoint)
        timeBackground.addSubview(tenthLabel)

        resizeHandle.text = "↘"
        resizeHandle.textColor = UIColor.white.withAlphaComponent(0.45)
        resizeHandle.textAlignment = .center
        resizeHandle.font = .systemFont(ofSize: 18, weight: .medium)
        resizeHandle.isUserInteractionEnabled = true
        addSubview(resizeHandle)

        let movePan = UIPanGestureRecognizer(
            target: self,
            action: #selector(moveClock(_:))
        )
        movePan.delegate = self
        movePan.cancelsTouchesInView = false
        addGestureRecognizer(movePan)

        let resizePan = UIPanGestureRecognizer(
            target: self,
            action: #selector(resizeClock(_:))
        )
        resizePan.cancelsTouchesInView = false
        resizeHandle.addGestureRecognizer(resizePan)

        updateTime(force: true)
    }

    private func configureNumberLabel(_ label: UILabel) {

        label.textColor = .white
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(
            ofSize: 45,
            weight: .bold
        )
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.55
    }

    private func configureTenthLabel(_ label: UILabel) {

        label.textColor = UIColor.red.withAlphaComponent(0.95)
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(
            ofSize: 28,
            weight: .bold
        )
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.55
    }

    private func configureDecimalPoint(_ label: UILabel) {

        label.text = "."
        label.textColor = UIColor.red.withAlphaComponent(0.95)
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(
            ofSize: 28,
            weight: .bold
        )
    }

    private func configureColon(_ label: UILabel) {

        label.text = ":"
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(
            ofSize: 42,
            weight: .bold
        )
    }

    override func layoutSubviews() {

        super.layoutSubviews()

        let scale = min(
            bounds.width / baseWidth,
            bounds.height / baseHeight
        )

        let horizontalInset = max(8, 16 * scale)
        let topInset = max(8, 8 * scale)
        timeBackground.frame = CGRect(
            x: horizontalInset,
            y: topInset,
            width: max(0, bounds.width - horizontalInset * 2),
            height: max(0, bounds.height - topInset - max(8, 10 * scale))
        )

        resizeHandle.frame = CGRect(
            x: bounds.width - max(28, 30 * scale),
            y: bounds.height - max(28, 30 * scale),
            width: max(28, 30 * scale),
            height: max(28, 30 * scale)
        )

        let box = timeBackground.bounds
        let digitWidth = box.width * 0.225
        let colonWidth = box.width * 0.075
        let tenthWidth = box.width * 0.095
        let decimalWidth = box.width * 0.045
        let digitHeight = box.height * 0.78
        let y = (box.height - digitHeight) / 2

        hourLabel.frame = CGRect(
            x: box.width * 0.025,
            y: y,
            width: digitWidth,
            height: digitHeight
        )

        firstColon.frame = CGRect(
            x: hourLabel.frame.maxX,
            y: y,
            width: colonWidth,
            height: digitHeight
        )

        minuteLabel.frame = CGRect(
            x: firstColon.frame.maxX,
            y: y,
            width: digitWidth,
            height: digitHeight
        )

        secondColon.frame = CGRect(
            x: minuteLabel.frame.maxX,
            y: y,
            width: colonWidth,
            height: digitHeight
        )

        secondLabel.frame = CGRect(
            x: secondColon.frame.maxX,
            y: y,
            width: digitWidth,
            height: digitHeight
        )

        decimalPoint.frame = CGRect(
            x: secondLabel.frame.maxX - 1,
            y: y + digitHeight * 0.02,
            width: decimalWidth,
            height: digitHeight
        )

        tenthLabel.frame = CGRect(
            x: decimalPoint.frame.maxX - 2,
            y: y + digitHeight * 0.12,
            width: tenthWidth,
            height: digitHeight * 0.88
        )

        let fontSize = max(
            16,
            45 * scale
        )

        hourLabel.font = .monospacedDigitSystemFont(
            ofSize: fontSize,
            weight: .bold
        )

        minuteLabel.font = .monospacedDigitSystemFont(
            ofSize: fontSize,
            weight: .bold
        )

        secondLabel.font = .monospacedDigitSystemFont(
            ofSize: fontSize,
            weight: .bold
        )

        let tenthSize = max(
            11,
            28 * scale
        )

        tenthLabel.font = .monospacedDigitSystemFont(
            ofSize: tenthSize,
            weight: .bold
        )

        decimalPoint.font = .monospacedDigitSystemFont(
            ofSize: tenthSize,
            weight: .bold
        )

        let colonSize = max(
            15,
            42 * scale
        )

        firstColon.font = .monospacedDigitSystemFont(
            ofSize: colonSize,
            weight: .bold
        )

        secondColon.font = .monospacedDigitSystemFont(
            ofSize: colonSize,
            weight: .bold
        )
    }

    func start() {

        clockTimer?.invalidate()

        updateTime(force: true)

        let timer = Timer(
            timeInterval: 0.05,
            repeats: true
        ) { [weak self] _ in
            self?.updateTime(force: false)
        }

        clockTimer = timer

        RunLoop.main.add(
            timer,
            forMode: .common
        )
    }

    func stop() {

        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func updateTime(force: Bool) {

        let now = Date()
        let calendar = Calendar.current
        let second = calendar.component(.second, from: now)
        let millisecond = calendar.component(.nanosecond, from: now) / 1_000_000
        let tenth = millisecond / 100

        guard force || tenth != lastTenth else {
            return
        }

        lastTenth = tenth

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        hourLabel.text = String(format: "%02d", hour)
        minuteLabel.text = String(format: "%02d", minute)
        secondLabel.text = String(format: "%02d", second)
        tenthLabel.text = String(tenth)
    }

    @objc private func moveClock(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let parent = superview else {
            return
        }

        switch gesture.state {

        case .began:

            moveStartFrame = frame
            moveStartPoint = gesture.location(in: parent)

        case .changed:

            let point = gesture.location(in: parent)

            var newFrame = moveStartFrame

            newFrame.origin.x += point.x - moveStartPoint.x
            newFrame.origin.y += point.y - moveStartPoint.y

            clamp(
                &newFrame,
                in: parent
            )

            frame = newFrame

        default:
            break
        }
    }

    @objc private func resizeClock(
        _ gesture: UIPanGestureRecognizer
    ) {

        guard let parent = superview else {
            return
        }

        switch gesture.state {

        case .began:

            resizeStartFrame = frame
            resizeStartPoint = gesture.location(in: parent)

        case .changed:

            let point = gesture.location(in: parent)

            let dx = point.x - resizeStartPoint.x
            let dy = point.y - resizeStartPoint.y

            let horizontalScale = dx / max(1, resizeStartFrame.width)
            let verticalScale = dy / max(1, resizeStartFrame.height)

            let scaleDelta = abs(horizontalScale) >= abs(verticalScale)
                ? horizontalScale
                : verticalScale

            let minimumWidth: CGFloat = 145
            let maximumWidth = max(
                minimumWidth,
                parent.bounds.width - resizeStartFrame.origin.x
            )

            let requestedWidth =
                resizeStartFrame.width *
                (1 + scaleDelta)

            let width = max(
                minimumWidth,
                min(requestedWidth, maximumWidth)
            )

            let height = width / aspectRatio

            var newFrame = CGRect(
                x: resizeStartFrame.origin.x,
                y: resizeStartFrame.origin.y,
                width: width,
                height: height
            )

            if newFrame.maxY > parent.bounds.height {
                let availableHeight =
                    parent.bounds.height -
                    resizeStartFrame.origin.y

                let limitedHeight = max(
                    60,
                    availableHeight
                )

                let limitedWidth =
                    limitedHeight * aspectRatio

                newFrame.size = CGSize(
                    width: min(width, limitedWidth),
                    height: min(
                        limitedHeight,
                        width / aspectRatio
                    )
                )
            }

            clamp(
                &newFrame,
                in: parent
            )

            frame = newFrame

        default:
            break
        }
    }

    private func clamp(
        _ rect: inout CGRect,
        in parent: UIView
    ) {

        let maxX = max(
            0,
            parent.bounds.width - rect.width
        )

        let maxY = max(
            0,
            parent.bounds.height - rect.height
        )

        rect.origin.x = max(
            0,
            min(rect.origin.x, maxX)
        )

        rect.origin.y = max(
            0,
            min(rect.origin.y, maxY)
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {

        guard gestureRecognizer.view === self else {
            return true
        }

        let point = touch.location(in: self)

        return resizeHandle.frame.contains(point) == false
    }
}
