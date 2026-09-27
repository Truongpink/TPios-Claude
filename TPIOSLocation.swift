import UIKit

final class TPIOSViTri: UIView {

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    private struct SavedLocation: Codable {
        let id: String
        var name: String
        var latitude: Double
        var longitude: Double
        var altitude: Double
        var address: String
    }

    private let storageKey = "TPIOSViTri.SavedLocations.v1"

    private var savedLocations: [SavedLocation] = []
    private var selectedLocationID: String?

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    private let nameField = UITextField()
    private let latitudeField = UITextField()
    private let longitudeField = UITextField()
    private let altitudeField = UITextField()
    private let addressField = UITextField()

    private let saveButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private let listTitleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let emptyLabel = UILabel()
    private let resizeHandle = UILabel()

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
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        clipsToBounds = true

        setupHeader()
        setupFields()
        setupSavedList()
        setupResize()
        setupMove()
        loadSavedLocations()
    }

    private func setupHeader() {
        headerView.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )

        addSubview(headerView)

        titleLabel.text = "Vị trí"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        backButton.setTitle("‹", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 30)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        headerView.addSubview(backButton)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.75)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        closeButton.layer.cornerRadius = 17
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)
    }

    private func setupFields() {
        configureField(nameField, placeholder: "Tên vị trí", keyboard: .default)
        configureField(latitudeField, placeholder: "Vĩ độ (Latitude)", keyboard: .numbersAndPunctuation)
        configureField(longitudeField, placeholder: "Kinh độ (Longitude)", keyboard: .numbersAndPunctuation)
        configureField(altitudeField, placeholder: "Độ cao (m)", keyboard: .numbersAndPunctuation)
        configureField(addressField, placeholder: "Địa chỉ / ghi chú", keyboard: .default)

        addSubview(nameField)
        addSubview(latitudeField)
        addSubview(longitudeField)
        addSubview(altitudeField)
        addSubview(addressField)

        configureActionButton(saveButton, title: "Lưu vị trí", action: #selector(saveLocationTapped))
        configureActionButton(clearButton, title: "Xóa nhập", action: #selector(clearFieldsTapped))

        addSubview(saveButton)
        addSubview(clearButton)

        statusLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.numberOfLines = 2
        addSubview(statusLabel)
    }

    private func configureField(
        _ field: UITextField,
        placeholder: String,
        keyboard: UIKeyboardType
    ) {
        field.placeholder = placeholder
        field.textColor = .white
        field.tintColor = .white
        field.backgroundColor = UIColor(
            red: 0.075,
            green: 0.085,
            blue: 0.105,
            alpha: 1
        )
        field.layer.cornerRadius = 11
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        field.leftViewMode = .always
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.keyboardType = keyboard
    }

    private func configureActionButton(
        _ button: UIButton,
        title: String,
        action: Selector
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func setupSavedList() {
        listTitleLabel.text = "Vị trí đã lưu"
        listTitleLabel.textColor = .white
        listTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        addSubview(listTitleLabel)

        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        addSubview(scrollView)

        emptyLabel.text = "Chưa có vị trí"
        emptyLabel.textColor = UIColor.white.withAlphaComponent(0.50)
        emptyLabel.font = .systemFont(ofSize: 13)
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
        resizeHandle.textColor = UIColor.white.withAlphaComponent(0.55)
        resizeHandle.font = .systemFont(ofSize: 19, weight: .medium)
        resizeHandle.textAlignment = .center
        resizeHandle.isUserInteractionEnabled = true
        addSubview(resizeHandle)

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(resizeView(_:))
        )
        pan.cancelsTouchesInView = false
        resizeHandle.addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        headerView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: 56
        )

        backButton.frame = CGRect(
            x: 4,
            y: 8,
            width: 42,
            height: 38
        )

        titleLabel.frame = CGRect(
            x: 50,
            y: 8,
            width: max(0, bounds.width - 100),
            height: 38
        )

        closeButton.frame = CGRect(
            x: bounds.width - 46,
            y: 10,
            width: 34,
            height: 34
        )

        let side: CGFloat = 10
        let gap: CGFloat = 8
        let half = max(0, (bounds.width - side * 2 - gap) / 2)

        nameField.frame = CGRect(
            x: side,
            y: 66,
            width: max(0, bounds.width - side * 2),
            height: 34
        )

        latitudeField.frame = CGRect(
            x: side,
            y: 108,
            width: half,
            height: 34
        )

        longitudeField.frame = CGRect(
            x: side + half + gap,
            y: 108,
            width: half,
            height: 34
        )

        altitudeField.frame = CGRect(
            x: side,
            y: 150,
            width: half,
            height: 34
        )

        addressField.frame = CGRect(
            x: side + half + gap,
            y: 150,
            width: half,
            height: 34
        )

        saveButton.frame = CGRect(
            x: side,
            y: 192,
            width: half,
            height: 36
        )

        clearButton.frame = CGRect(
            x: side + half + gap,
            y: 192,
            width: half,
            height: 36
        )

        statusLabel.frame = CGRect(
            x: side,
            y: 234,
            width: max(0, bounds.width - side * 2),
            height: 30
        )

        listTitleLabel.frame = CGRect(
            x: side,
            y: 266,
            width: max(0, bounds.width - side * 2),
            height: 22
        )

        scrollView.frame = CGRect(
            x: side,
            y: 292,
            width: max(0, bounds.width - side * 2),
            height: max(0, bounds.height - 304)
        )

        resizeHandle.frame = CGRect(
            x: bounds.width - 30,
            y: bounds.height - 30,
            width: 30,
            height: 30
        )

        reloadSavedList()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func moveView(_ gesture: UIPanGestureRecognizer) {
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
            clamp(&newFrame, in: parent)
            frame = newFrame

        default:
            break
        }
    }

    @objc private func resizeView(_ gesture: UIPanGestureRecognizer) {
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

            let minimumWidth: CGFloat = 260
            let minimumHeight: CGFloat = 400
            let maximumWidth = max(minimumWidth, parent.bounds.width - resizeStartFrame.origin.x)
            let maximumHeight = max(minimumHeight, parent.bounds.height - resizeStartFrame.origin.y)

            frame = CGRect(
                x: resizeStartFrame.origin.x,
                y: resizeStartFrame.origin.y,
                width: min(max(minimumWidth, resizeStartFrame.width + dx), maximumWidth),
                height: min(max(minimumHeight, resizeStartFrame.height + dy), maximumHeight)
            )

        default:
            break
        }
    }

    @objc private func saveLocationTapped() {
        guard let latitude = Double(latitudeField.text ?? ""),
              let longitude = Double(longitudeField.text ?? ""),
              latitude >= -90, latitude <= 90,
              longitude >= -180, longitude <= 180 else {
            statusLabel.text = "Tọa độ không hợp lệ."
            return
        }

        let item = SavedLocation(
            id: UUID().uuidString,
            name: nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? nameField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
                : "Vị trí \(savedLocations.count + 1)",
            latitude: latitude,
            longitude: longitude,
            altitude: Double(altitudeField.text ?? "") ?? 0,
            address: addressField.text ?? ""
        )

        savedLocations.append(item)
        selectedLocationID = item.id
        persistSavedLocations()
        reloadSavedList()

        statusLabel.text = "Đã lưu và chọn vị trí: \(item.name)"
    }

    @objc private func clearFieldsTapped() {
        nameField.text = nil
        latitudeField.text = nil
        longitudeField.text = nil
        altitudeField.text = nil
        addressField.text = nil
        statusLabel.text = "Đã xóa ô nhập."
    }

    private func loadSavedLocations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([SavedLocation].self, from: data) else {
            return
        }

        savedLocations = values
        reloadSavedList()
    }

    private func persistSavedLocations() {
        guard let data = try? JSONEncoder().encode(savedLocations) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func reloadSavedList() {
        scrollView.subviews
            .filter { $0 !== emptyLabel }
            .forEach { $0.removeFromSuperview() }

        if savedLocations.isEmpty {
            emptyLabel.isHidden = false
            emptyLabel.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
            return
        }

        emptyLabel.isHidden = true

        let rowHeight: CGFloat = 72
        let width = max(0, scrollView.bounds.width)

        for (index, location) in savedLocations.enumerated() {
            let row = makeLocationRow(location, index: index, width: width)
            row.frame = CGRect(
                x: 0,
                y: CGFloat(index) * rowHeight,
                width: width,
                height: rowHeight - 6
            )
            scrollView.addSubview(row)
        }

        scrollView.contentSize = CGSize(
            width: width,
            height: CGFloat(savedLocations.count) * rowHeight
        )
    }

    private func makeLocationRow(
        _ location: SavedLocation,
        index: Int,
        width: CGFloat
    ) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        row.layer.cornerRadius = 12

        let title = UILabel()
        title.text = "\(index + 1). \(location.name)"
        title.textColor = .white
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        row.addSubview(title)

        let detail = UILabel()
        detail.text = String(
            format: "%.6f, %.6f • %.0fm",
            location.latitude,
            location.longitude,
            location.altitude
        )
        detail.textColor = UIColor.white.withAlphaComponent(0.62)
        detail.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        row.addSubview(detail)

        let select = UIButton(type: .system)
        select.setTitle(
            selectedLocationID == location.id ? "Đang chọn" : "Chọn",
            for: .normal
        )
        select.setTitleColor(.white, for: .normal)
        select.backgroundColor = selectedLocationID == location.id
            ? UIColor.systemGreen.withAlphaComponent(0.55)
            : UIColor.white.withAlphaComponent(0.10)
        select.layer.cornerRadius = 9
        select.tag = index
        select.addTarget(self, action: #selector(selectLocationTapped(_:)), for: .touchUpInside)
        row.addSubview(select)

        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "trash"), for: .normal)
        delete.tintColor = UIColor.systemRed.withAlphaComponent(0.9)
        delete.tag = index
        delete.addTarget(self, action: #selector(deleteLocationTapped(_:)), for: .touchUpInside)
        row.addSubview(delete)

        title.frame = CGRect(x: 10, y: 8, width: max(0, width - 130), height: 20)
        detail.frame = CGRect(x: 10, y: 31, width: max(0, width - 130), height: 18)
        select.frame = CGRect(x: max(0, width - 110), y: 16, width: 66, height: 32)
        delete.frame = CGRect(x: max(0, width - 42), y: 16, width: 32, height: 32)

        return row
    }

    @objc private func selectLocationTapped(_ button: UIButton) {
        guard savedLocations.indices.contains(button.tag) else {
            return
        }

        let location = savedLocations[button.tag]
        selectedLocationID = location.id

        nameField.text = location.name
        latitudeField.text = String(format: "%.6f", location.latitude)
        longitudeField.text = String(format: "%.6f", location.longitude)
        altitudeField.text = String(format: "%.0f", location.altitude)
        addressField.text = location.address

        statusLabel.text = "Đã chọn: \(location.name)"
        reloadSavedList()
    }

    @objc private func deleteLocationTapped(_ button: UIButton) {
        guard savedLocations.indices.contains(button.tag) else {
            return
        }

        let removed = savedLocations.remove(at: button.tag)

        if selectedLocationID == removed.id {
            selectedLocationID = savedLocations.first?.id
        }

        persistSavedLocations()
        reloadSavedList()
        statusLabel.text = "Đã xóa: \(removed.name)"
    }

    private func clamp(_ rect: inout CGRect, in parent: UIView) {
        let maxX = max(0, parent.bounds.width - rect.width)
        let maxY = max(0, parent.bounds.height - rect.height)

        rect.origin.x = max(0, min(rect.origin.x, maxX))
        rect.origin.y = max(0, min(rect.origin.y, maxY))
    }
}