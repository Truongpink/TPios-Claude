import UIKit

final class TPIOSBypass: UIView {

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var onMoveBegan: (() -> Void)?
    var onMove: ((CGFloat, CGFloat) -> Void)?
    var onResizeBegan: (() -> Void)?
    var onResize: ((CGFloat, CGFloat) -> Void)?

    private struct SavedAPI: Codable {
        let id: String
        let url: String
    }

    private var savedAPIs: [SavedAPI] = []
    private let apiStorageKey = "TPIOSBypass.SavedAPIs.v2"
    private let activeAPIKey = "TPIOSBypass.ActiveAPI.v1"
    private let keychainService = "TPIOSBypass.Token.v1"

    private var headerView = UIView()
    private var titleLabel = UILabel()
    private var backButton = UIButton(type: .system)
    private var closeButton = UIButton(type: .system)

    private var urlField = UITextField()
    private var tokenField = UITextField()
    private var checkButton = UIButton(type: .system)
    private var saveButton = UIButton(type: .system)
    private var statusLabel = UILabel()

    private var listTitleLabel = UILabel()
    private var scrollView = UIScrollView()
    private var emptyLabel = UILabel()
    private var resizeHandle = UILabel()

    private var resizeStartFrame = CGRect.zero
    private var resizeStartPoint = CGPoint.zero

    private var moveStartFrame = CGRect.zero
    private var moveStartPoint = CGPoint.zero

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

        setupHeader()
        setupFields()
        setupSavedList()
        setupResize()
        setupMove()

        loadSavedAPIs()
    }

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

        titleLabel.text = "Vượt Rào"
        titleLabel.textColor = .white
        titleLabel.font =
            .systemFont(ofSize: 19, weight: .bold)

        headerView.addSubview(titleLabel)

        backButton.setTitle("‹", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font =
            .systemFont(ofSize: 30, weight: .regular)

        backButton.addTarget(
            self,
            action: #selector(backTapped),
            for: .touchUpInside
        )

        headerView.addSubview(backButton)

        closeButton.setTitle("×", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font =
            .systemFont(ofSize: 28, weight: .regular)

        closeButton.addTarget(
            self,
            action: #selector(closeTapped),
            for: .touchUpInside
        )

        headerView.addSubview(closeButton)
    }

    private func setupFields() {
        configureField(
            urlField,
            placeholder: "API URL",
            secure: false
        )

        configureField(
            tokenField,
            placeholder: "Token / API Key",
            secure: true
        )

        addSubview(urlField)
        addSubview(tokenField)

        checkButton.setTitle("Kiểm tra", for: .normal)
        checkButton.setTitleColor(.white, for: .normal)
        checkButton.backgroundColor = UIColor(
            red: 0.12,
            green: 0.13,
            blue: 0.16,
            alpha: 1
        )
        checkButton.layer.cornerRadius = 14
        checkButton.layer.borderWidth = 1
        checkButton.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        checkButton.addTarget(
            self,
            action: #selector(checkURLTapped),
            for: .touchUpInside
        )

        addSubview(checkButton)

        saveButton.setTitle("Lưu", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor =
            UIColor.white.withAlphaComponent(0.12)

        saveButton.layer.cornerRadius = 14
        saveButton.layer.borderWidth = 1
        saveButton.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor

        saveButton.addTarget(
            self,
            action: #selector(saveAPITapped),
            for: .touchUpInside
        )

        addSubview(saveButton)

        statusLabel.textColor =
            UIColor.white.withAlphaComponent(0.82)

        statusLabel.font =
            .systemFont(ofSize: 12)

        statusLabel.numberOfLines = 2

        addSubview(statusLabel)
    }

    private func configureField(
        _ field: UITextField,
        placeholder: String,
        secure: Bool
    ) {
        field.placeholder = placeholder
        field.textColor = .white
        field.tintColor = .white
        field.backgroundColor =
            UIColor(
                red: 0.075,
                green: 0.085,
                blue: 0.105,
                alpha: 1
            )

        field.layer.cornerRadius = 14
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor

        field.leftView =
            UIView(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 10,
                    height: 1
                )
            )

        field.leftViewMode = .always
        field.isSecureTextEntry = secure
        field.autocorrectionType = .no
        field.autocapitalizationType = .none

        if #available(iOS 12.0, *) {
            field.textContentType =
                secure ? .password : .URL
        }
    }

    private func setupSavedList() {
        listTitleLabel.text = "API đã lưu"
        listTitleLabel.textColor = .white
        listTitleLabel.font =
            .systemFont(ofSize: 14, weight: .semibold)

        addSubview(listTitleLabel)

        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true

        addSubview(scrollView)

        emptyLabel.text = "Chưa có API"
        emptyLabel.textColor =
            UIColor.white.withAlphaComponent(0.55)

        emptyLabel.font =
            .systemFont(ofSize: 13)

        emptyLabel.textAlignment = .center

        scrollView.addSubview(emptyLabel)
    }

    private func setupMove() {
        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(moveView(_:))
        )

        pan.cancelsTouchesInView = false
        headerView.addGestureRecognizer(pan)
    }

    private func setupResize() {
        resizeHandle.text = "↘"
        resizeHandle.textColor =
            UIColor.white.withAlphaComponent(0.65)

        resizeHandle.font =
            .systemFont(ofSize: 20, weight: .medium)

        resizeHandle.textAlignment = .center
        resizeHandle.isUserInteractionEnabled = true

        addSubview(resizeHandle)

        let pan =
            UIPanGestureRecognizer(
                target: self,
                action: #selector(resizeView(_:))
            )

        pan.cancelsTouchesInView = false
        resizeHandle.addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        headerView.frame =
            CGRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: 66
            )

        backButton.frame =
            CGRect(
                x: 4,
                y: 14,
                width: 42,
                height: 38
            )

        closeButton.frame =
            CGRect(
                x: bounds.width - 46,
                y: 4,
                width: 42,
                height: 36
            )

        titleLabel.frame =
            CGRect(
                x: 48,
                y: 11,
                width: max(0, bounds.width - 96),
                height: 44
            )

        urlField.frame =
            CGRect(
                x: 10,
                y: 82,
                width: max(0, bounds.width - 20),
                height: 38
            )

        tokenField.frame =
            CGRect(
                x: 10,
                y: 128,
                width: max(0, bounds.width - 20),
                height: 38
            )

        let buttonWidth =
            max(0, (bounds.width - 30) / 2)

        checkButton.frame =
            CGRect(
                x: 10,
                y: 174,
                width: buttonWidth,
                height: 38
            )

        saveButton.frame =
            CGRect(
                x: 20 + buttonWidth,
                y: 148,
                width: buttonWidth,
                height: 38
            )

        statusLabel.frame =
            CGRect(
                x: 10,
                y: 218,
                width: max(0, bounds.width - 20),
                height: 34
            )

        listTitleLabel.frame =
            CGRect(
                x: 10,
                y: 282,
                width: max(0, bounds.width - 20),
                height: 24
            )

        scrollView.frame =
            CGRect(
                x: 10,
                y: 254,
                width: max(0, bounds.width - 20),
                height: max(0, bounds.height - 266)
            )

        resizeHandle.frame =
            CGRect(
                x: bounds.width - 30,
                y: bounds.height - 30,
                width: 30,
                height: 30
            )

        if savedAPIs.isEmpty {
            emptyLabel.frame = scrollView.bounds
        } else {
            reloadSavedList()
        }
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func moveView(
        _ gesture: UIPanGestureRecognizer
    ) {
        guard let parent = superview else {
            return
        }

        switch gesture.state {

        case .began:

            moveStartFrame = frame
            moveStartPoint =
                gesture.location(in: parent)

            onMoveBegan?()

        case .changed:

            let point =
                gesture.location(in: parent)

            let dx =
                point.x - moveStartPoint.x

            let dy =
                point.y - moveStartPoint.y

            var newFrame =
                moveStartFrame

            newFrame.origin.x += dx
            newFrame.origin.y += dy

            let maxX =
                max(
                    0,
                    parent.bounds.width -
                    newFrame.width
                )

            let maxY =
                max(
                    0,
                    parent.bounds.height -
                    newFrame.height
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

            onMove?(
                newFrame.origin.x -
                    moveStartFrame.origin.x,
                newFrame.origin.y -
                    moveStartFrame.origin.y
            )

        default:
            break
        }
    }

    @objc private func resizeView(
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

            onResizeBegan?()

        case .changed:

            let point =
                gesture.location(in: parent)

            let dx =
                point.x - resizeStartPoint.x

            let dy =
                point.y - resizeStartPoint.y

            let minimumWidth: CGFloat = 240
            let minimumHeight: CGFloat = 300

            let maximumWidth =
                parent.bounds.width -
                resizeStartFrame.origin.x

            let maximumHeight =
                parent.bounds.height -
                resizeStartFrame.origin.y

            let width =
                max(
                    minimumWidth,
                    min(
                        resizeStartFrame.width + dx,
                        maximumWidth
                    )
                )

            let height =
                max(
                    minimumHeight,
                    min(
                        resizeStartFrame.height + dy,
                        maximumHeight
                    )
                )

            frame =
                CGRect(
                    x: resizeStartFrame.origin.x,
                    y: resizeStartFrame.origin.y,
                    width: width,
                    height: height
                )

            onResize?(
                width -
                    resizeStartFrame.width,
                height -
                    resizeStartFrame.height
            )

        default:
            break
        }
    }

    @objc private func checkURLTapped() {

        guard let normalized =
            normalizeURL(urlField.text ?? "") else {

            statusLabel.text =
                "URL không hợp lệ"

            return
        }

        statusLabel.text =
            "Đang kiểm tra..."

        var request =
            URLRequest(url: normalized)

        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.cachePolicy =
            .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(
            with: request
        ) { [weak self] _, response, error in

            DispatchQueue.main.async {

                if let error {

                    self?.statusLabel.text =
                        "Lỗi: \(error.localizedDescription)"

                    return
                }

                if let http =
                    response as? HTTPURLResponse {

                    self?.statusLabel.text =
                        "HTTP \(http.statusCode)"

                } else {

                    self?.statusLabel.text =
                        "Kết nối thành công"
                }
            }

        }.resume()
    }

    private func normalizeURL(
        _ raw: String
    ) -> URL? {

        var value =
            raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard value.isEmpty == false else {
            return nil
        }

        if value.contains("://") == false {
            value = "https://" + value
        }

        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }

        return url
    }

    @objc private func saveAPITapped() {

        guard let url =
            normalizeURL(urlField.text ?? "") else {

            statusLabel.text =
                "URL không hợp lệ"

            return
        }

        let urlString =
            url.absoluteString

        if savedAPIs.contains(
            where: { $0.url == urlString }
        ) {

            statusLabel.text =
                "API đã tồn tại"

            saveToken()
            saveActiveAPI(urlString)

            return
        }

        let item =
            SavedAPI(
                id: UUID().uuidString,
                url: urlString
            )

        savedAPIs.append(item)

        persistSavedAPIs()
        saveToken()
        saveActiveAPI(urlString)

        statusLabel.text =
            "Đã lưu API"

        reloadSavedList()
    }

    private func saveToken() {

        let token =
            tokenField.text ?? ""

        let data =
            token.data(
                using: .utf8
            )

        guard let data else {
            return
        }

        let query:
            [String: Any] = [

                kSecClass as String:
                    kSecClassGenericPassword,

                kSecAttrService as String:
                    keychainService,

                kSecAttrAccount as String:
                    "default",

                kSecValueData as String:
                    data
            ]

        SecItemDelete(
            query as CFDictionary
        )

        SecItemAdd(
            query as CFDictionary,
            nil
        )
    }

    private func readToken() -> String? {

        let query:
            [String: Any] = [

                kSecClass as String:
                    kSecClassGenericPassword,

                kSecAttrService as String:
                    keychainService,

                kSecAttrAccount as String:
                    "default",

                kSecReturnData as String:
                    true,

                kSecMatchLimit as String:
                    kSecMatchLimitOne
            ]

        var result:
            AnyObject?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(
            data: data,
            encoding: .utf8
        )
    }

    private func deleteToken() {

        let query:
            [String: Any] = [

                kSecClass as String:
                    kSecClassGenericPassword,

                kSecAttrService as String:
                    keychainService,

                kSecAttrAccount as String:
                    "default"
            ]

        SecItemDelete(
            query as CFDictionary
        )
    }

    private func saveActiveAPI(
        _ url: String
    ) {

        UserDefaults.standard.set(
            url,
            forKey: activeAPIKey
        )
    }

    private func persistSavedAPIs() {

        guard let data =
            try? JSONEncoder().encode(
                savedAPIs
            ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: apiStorageKey
        )
    }

    private func loadSavedAPIs() {

        guard let data =
            UserDefaults.standard.data(
                forKey: apiStorageKey
            ) else {

            tokenField.text =
                readToken()

            return
        }

        savedAPIs =
            (try? JSONDecoder().decode(
                [SavedAPI].self,
                from: data
            )) ?? []

        tokenField.text =
            readToken()
    }

    private func reloadSavedList() {

        scrollView.subviews.forEach {
            $0.removeFromSuperview()
        }

        let rowHeight: CGFloat = 46

        for (index, api) in
            savedAPIs.enumerated() {

            let row =
                TPIOSAPIRow(
                    frame: CGRect(
                        x: 0,
                        y: CGFloat(index) * rowHeight,
                        width: scrollView.bounds.width,
                        height: rowHeight - 4
                    )
                )

            row.configure(
                url: api.url
            )

            row.onSelect = {
                [weak self] in

                self?.urlField.text =
                    api.url

                self?.tokenField.text =
                    self?.readToken()

                self?.saveActiveAPI(
                    api.url
                )

                self?.statusLabel.text =
                    "Đã chọn API"
            }

            row.onDelete = {
                [weak self] in

                guard let self else {
                    return
                }

                self.savedAPIs.remove(
                    at: index
                )

                self.persistSavedAPIs()
                self.reloadSavedList()
            }

            scrollView.addSubview(row)
        }

        let contentHeight =
            CGFloat(savedAPIs.count) *
            rowHeight

        scrollView.contentSize =
            CGSize(
                width: scrollView.bounds.width,
                height: contentHeight
            )

        if savedAPIs.isEmpty {

            emptyLabel =
                UILabel(
                    frame: scrollView.bounds
                )

            emptyLabel.text =
                "Chưa có API"

            emptyLabel.textColor =
                UIColor.white.withAlphaComponent(0.55)

            emptyLabel.font =
                .systemFont(ofSize: 13)

            emptyLabel.textAlignment =
                .center

            scrollView.addSubview(
                emptyLabel
            )
        }
    }
}

final class TPIOSAPIRow: UIView {

    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?

    private let urlLabel = UILabel()
    private let selectButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor =
            UIColor.white.withAlphaComponent(0.08)

        layer.cornerRadius = 10

        urlLabel.textColor = .white
        urlLabel.font =
            .systemFont(ofSize: 12)

        urlLabel.lineBreakMode =
            .byTruncatingMiddle

        addSubview(urlLabel)

        selectButton.setTitle(
            "Chọn",
            for: .normal
        )

        selectButton.setTitleColor(
            .white,
            for: .normal
        )

        selectButton.titleLabel?.font =
            .systemFont(
                ofSize: 11,
                weight: .semibold
            )

        selectButton.addTarget(
            self,
            action: #selector(selectTapped),
            for: .touchUpInside
        )

        addSubview(selectButton)

        deleteButton.setTitle(
            "Xóa",
            for: .normal
        )

        deleteButton.setTitleColor(
            UIColor.white.withAlphaComponent(0.75),
            for: .normal
        )

        deleteButton.titleLabel?.font =
            .systemFont(
                ofSize: 11,
                weight: .regular
            )

        deleteButton.addTarget(
            self,
            action: #selector(deleteTapped),
            for: .touchUpInside
        )

        addSubview(deleteButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(url: String) {
        urlLabel.text = url
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        deleteButton.frame =
            CGRect(
                x: bounds.width - 52,
                y: 0,
                width: 48,
                height: bounds.height
            )

        selectButton.frame =
            CGRect(
                x: bounds.width - 104,
                y: 0,
                width: 48,
                height: bounds.height
            )

        urlLabel.frame =
            CGRect(
                x: 10,
                y: 0,
                width: max(0, bounds.width - 114),
                height: bounds.height
            )
    }

    @objc private func selectTapped() {
        onSelect?()
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}