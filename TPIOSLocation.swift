import UIKit
import CoreLocation
import MapKit

// Dựng lại từ bản .dylib đã biên dịch (source gốc bị mất do khoá tài khoản
// GitHub) — chữ ký property/method dưới đây đã được xác nhận qua symbol
// table thật của binary, phần THÂN hàm là suy luận hợp lý theo tên gọi và
// theo phong cách các panel khác trong project (TPIOSMenu/TPIOSBypass).
// Chỗ nào không chắc chắn 100% đều có ghi chú riêng.
final class TPIOSLocation: UIView,
                           UIGestureRecognizerDelegate,
                           UITextFieldDelegate,
                           CLLocationManagerDelegate,
                           MKMapViewDelegate {

    // MARK: Callbacks (giống TPIOSBypass/TPIOSQuotaScanner)

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?

    // MARK: Model lưu trữ

    private struct SavedLocation: Codable {
        let address: String
        let latitude: Double
        let longitude: Double
        let altitude: Double
    }

    private let storageKey = "TPIOSLocation.SavedLocations.v1"
    private var savedLocations: [SavedLocation] = []

    // MARK: Header

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    // MARK: Tabs

    private let tabControl = UISegmentedControl(items: ["Tìm kiếm", "Đã lưu"])

    // MARK: Nội dung cuộn

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // MARK: Tab tìm kiếm

    private let instructionLabel = UILabel()
    private let searchField = UITextField()
    private let searchButton = UIButton(type: .system)

    private let mapView = MKMapView()
    private let mapTypeControl = UISegmentedControl(items: ["Chuẩn", "Vệ tinh", "Kết hợp"])

    private let latitudeField = UITextField()
    private let longitudeField = UITextField()
    private let altitudeField = UITextField()
    private let addressField = UITextField()

    private let statusLabel = UILabel()
    private let applyButton = UIButton(type: .system)
    private let saveCurrentButton = UIButton(type: .system)

    // MARK: Card "Giả GPS" — CHƯA nối hook thật, xem ghi chú ở spoofSwitchChanged()

    private let spoofCard = UIView()
    private let spoofTitleLabel = UILabel()
    private let spoofSubtitleLabel = UILabel()
    private let spoofSwitch = UISwitch()

    // MARK: Tab đã lưu

    private let savedTitleLabel = UILabel()
    private let savedStack = UIStackView()
    private let emptySavedLabel = UILabel()

    // MARK: Footer / resize

    private let footerLabel = UILabel()
    private let resizeHandle = UILabel()

    private var moveStartFrame = CGRect.zero
    private var moveStartPoint = CGPoint.zero
    private var resizeStartFrame = CGRect.zero
    private var resizeStartPoint = CGPoint.zero

    private let minWidth: CGFloat = 280
    private let minHeight: CGFloat = 380
    private let handleSize: CGFloat = 30
    private let headerHeight: CGFloat = 64

    // MARK: Trạng thái vị trí đang chọn

    private var selectedCoordinate: CLLocationCoordinate2D?
    private var selectedAddress: String = ""
    private var selectedAltitude: Double = 0

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Setup

    private func setup() {

        backgroundColor = UIColor(
            red: 0.045, green: 0.05, blue: 0.065, alpha: 0.98
        )
        layer.cornerRadius = 24
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.42
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        clipsToBounds = false

        setupHeader()
        setupTabControl()
        setupSearchTab()
        setupSpoofCard()
        setupSavedTab()
        setupFooter()
        setupResize()
        setupMove()

        locationManager.delegate = self
        mapView.delegate = self

        searchField.delegate = self
        latitudeField.delegate = self
        longitudeField.delegate = self
        altitudeField.delegate = self
        addressField.delegate = self

        reloadSavedLocations()
        tabChanged()
    }

    private func setupHeader() {

        headerView.backgroundColor = UIColor(
            red: 0.075, green: 0.085, blue: 0.105, alpha: 1
        )
        headerView.layer.cornerRadius = 24
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(headerView)

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = UIColor.white.withAlphaComponent(0.75)
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        backButton.layer.cornerRadius = 15
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        headerView.addSubview(backButton)

        titleLabel.text = "Vị trí"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        headerView.addSubview(titleLabel)

        subtitleLabel.text = "TÌM KIẾM & GIẢ LẬP GPS"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        headerView.addSubview(subtitleLabel)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor.white.withAlphaComponent(0.75)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        closeButton.layer.cornerRadius = 15
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)
    }

    private func setupTabControl() {
        tabControl.selectedSegmentIndex = 0
        tabControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        addSubview(tabControl)

        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    private func setupSearchTab() {

        instructionLabel.text = "Tìm địa điểm, chạm vào bản đồ, hoặc nhập toạ độ tay"
        instructionLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        instructionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        instructionLabel.numberOfLines = 0
        contentView.addSubview(instructionLabel)

        configureEditableField(searchField)
        searchField.placeholder = "Nhập tên địa điểm..."
        searchField.returnKeyType = .search
        contentView.addSubview(searchField)
        addClearButton(to: searchField, action: #selector(clearSearchTapped))

        searchButton.setTitle("Tìm", for: .normal)
        styleSmallButton(searchButton)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        contentView.addSubview(searchButton)

        mapView.layer.cornerRadius = 16
        mapView.clipsToBounds = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tap)
        contentView.addSubview(mapView)

        mapTypeControl.selectedSegmentIndex = 0
        mapTypeControl.addTarget(self, action: #selector(mapTypeChanged), for: .valueChanged)
        contentView.addSubview(mapTypeControl)

        configureEditableField(latitudeField)
        latitudeField.placeholder = "Vĩ độ"
        latitudeField.keyboardType = .numbersAndPunctuation
        latitudeField.addTarget(self, action: #selector(manualLocationEditingEnded(_:)), for: .editingDidEnd)
        contentView.addSubview(latitudeField)
        addClearButton(to: latitudeField, action: #selector(clearLatitudeTapped))

        configureEditableField(longitudeField)
        longitudeField.placeholder = "Kinh độ"
        longitudeField.keyboardType = .numbersAndPunctuation
        longitudeField.addTarget(self, action: #selector(manualLocationEditingEnded(_:)), for: .editingDidEnd)
        contentView.addSubview(longitudeField)
        addClearButton(to: longitudeField, action: #selector(clearLongitudeTapped))

        configureEditableField(altitudeField)
        altitudeField.placeholder = "Độ cao (m)"
        altitudeField.keyboardType = .numbersAndPunctuation
        altitudeField.addTarget(self, action: #selector(manualLocationEditingEnded(_:)), for: .editingDidEnd)
        contentView.addSubview(altitudeField)
        addClearButton(to: altitudeField, action: #selector(clearAltitudeTapped))

        configureEditableField(addressField)
        addressField.placeholder = "Địa chỉ"
        addressField.addTarget(self, action: #selector(manualAddressEditingEnded(_:)), for: .editingDidEnd)
        contentView.addSubview(addressField)
        addClearButton(to: addressField, action: #selector(clearAddressTapped))

        statusLabel.text = "Chưa chọn vị trí"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.numberOfLines = 0
        contentView.addSubview(statusLabel)

        applyButton.setTitle("Áp dụng", for: .normal)
        styleSmallButton(applyButton)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        contentView.addSubview(applyButton)

        saveCurrentButton.setTitle("Lưu vị trí này", for: .normal)
        styleSmallButton(saveCurrentButton)
        saveCurrentButton.addTarget(self, action: #selector(saveCurrentTapped), for: .touchUpInside)
        contentView.addSubview(saveCurrentButton)
    }

    private func setupSpoofCard() {

        spoofCard.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        spoofCard.layer.cornerRadius = 14
        contentView.addSubview(spoofCard)

        spoofTitleLabel.text = "Giả lập GPS"
        spoofTitleLabel.textColor = .white
        spoofTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        spoofCard.addSubview(spoofTitleLabel)

        // GHI CHÚ: qua kiểm tra bản dylib, công tắc này KHÔNG có bất kỳ
        // hook/swizzle nào can thiệp vào CLLocationManager hệ thống — chỉ
        // là 1 công tắc UI, bật/tắt chưa làm app khác nhận toạ độ giả.
        // Cần bổ sung cơ chế thật (vd sửa clients.plist của locationd,
        // hoặc hook init CLLocationManager) nếu muốn tính năng hoạt động
        // thật sự — hiện tại đang để placeholder log lại trạng thái.
        spoofSubtitleLabel.text = "Bật để mô phỏng vị trí đã chọn (đang phát triển)"
        spoofSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        spoofSubtitleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        spoofSubtitleLabel.numberOfLines = 0
        spoofCard.addSubview(spoofSubtitleLabel)

        spoofSwitch.addTarget(self, action: #selector(spoofSwitchChanged), for: .valueChanged)
        spoofCard.addSubview(spoofSwitch)
    }

    private func setupSavedTab() {

        savedTitleLabel.text = "Vị trí đã lưu"
        savedTitleLabel.textColor = .white
        savedTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        contentView.addSubview(savedTitleLabel)

        savedStack.axis = .vertical
        savedStack.spacing = 8
        contentView.addSubview(savedStack)

        emptySavedLabel.text = "Chưa lưu vị trí nào"
        emptySavedLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        emptySavedLabel.font = .systemFont(ofSize: 12, weight: .regular)
        emptySavedLabel.textAlignment = .center
        contentView.addSubview(emptySavedLabel)
    }

    private func setupFooter() {
        footerLabel.text = "Kéo tiêu đề để di chuyển  •  ↘ để đổi kích thước"
        footerLabel.textColor = UIColor.white.withAlphaComponent(0.34)
        footerLabel.font = .systemFont(ofSize: 9, weight: .medium)
        footerLabel.textAlignment = .center
        footerLabel.adjustsFontSizeToFitWidth = true
        footerLabel.minimumScaleFactor = 0.75
        addSubview(footerLabel)
    }

    private func setupMove() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(moveView(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        headerView.addGestureRecognizer(pan)
    }

    private func setupResize() {
        resizeHandle.text = "↘"
        resizeHandle.textColor = UIColor.white.withAlphaComponent(0.42)
        resizeHandle.font = .systemFont(ofSize: 19, weight: .medium)
        resizeHandle.textAlignment = .center
        resizeHandle.isUserInteractionEnabled = true
        addSubview(resizeHandle)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(resizeView(_:)))
        pan.cancelsTouchesInView = false
        resizeHandle.addGestureRecognizer(pan)
    }

    // MARK: Style helper dùng chung

    private func configureEditableField(_ field: UITextField) {
        field.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        field.textColor = .white
        field.tintColor = .white
        field.font = .systemFont(ofSize: 13, weight: .regular)
        field.layer.cornerRadius = 10
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        field.leftView = pad
        field.leftViewMode = .always
    }

    private func addClearButton(to field: UITextField, action: Selector) {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.35)
        button.frame = CGRect(x: 0, y: 0, width: 28, height: 24)
        button.addTarget(self, action: action, for: .touchUpInside)
        field.rightView = button
        field.rightViewMode = .whileEditing
    }

    private func styleSmallButton(_ button: UIButton) {
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 10
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        headerView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        backButton.frame = CGRect(x: 14, y: 17, width: 30, height: 30)
        closeButton.frame = CGRect(x: bounds.width - 44, y: 17, width: 30, height: 30)
        titleLabel.frame = CGRect(x: 52, y: 12, width: bounds.width - 104, height: 24)
        subtitleLabel.frame = CGRect(x: 52, y: 36, width: bounds.width - 104, height: 14)

        let tabTop = headerHeight + 10
        tabControl.frame = CGRect(x: 14, y: tabTop, width: bounds.width - 28, height: 32)

        let scrollTop = tabTop + 42
        scrollView.frame = CGRect(
            x: 0, y: scrollTop,
            width: bounds.width, height: bounds.height - scrollTop - 30
        )

        let contentWidth = bounds.width - 28
        var y: CGFloat = 12

        instructionLabel.frame = CGRect(x: 14, y: y, width: contentWidth, height: 30)
        y += 36

        searchField.frame = CGRect(x: 14, y: y, width: contentWidth - 60, height: 36)
        searchButton.frame = CGRect(x: 14 + contentWidth - 54, y: y, width: 54, height: 36)
        y += 44

        mapView.frame = CGRect(x: 14, y: y, width: contentWidth, height: 180)
        y += 188

        mapTypeControl.frame = CGRect(x: 14, y: y, width: contentWidth, height: 28)
        y += 36

        let fieldWidth = (contentWidth - 16) / 3
        latitudeField.frame = CGRect(x: 14, y: y, width: fieldWidth, height: 36)
        longitudeField.frame = CGRect(x: 14 + fieldWidth + 8, y: y, width: fieldWidth, height: 36)
        altitudeField.frame = CGRect(x: 14 + (fieldWidth + 8) * 2, y: y, width: fieldWidth, height: 36)
        y += 44

        addressField.frame = CGRect(x: 14, y: y, width: contentWidth, height: 36)
        y += 44

        statusLabel.frame = CGRect(x: 14, y: y, width: contentWidth, height: 32)
        y += 38

        let halfWidth = (contentWidth - 8) / 2
        applyButton.frame = CGRect(x: 14, y: y, width: halfWidth, height: 38)
        saveCurrentButton.frame = CGRect(x: 14 + halfWidth + 8, y: y, width: halfWidth, height: 38)
        y += 46

        spoofCard.frame = CGRect(x: 14, y: y, width: contentWidth, height: 62)
        spoofTitleLabel.frame = CGRect(x: 14, y: 10, width: contentWidth - 80, height: 18)
        spoofSubtitleLabel.frame = CGRect(x: 14, y: 30, width: contentWidth - 80, height: 26)
        spoofSwitch.frame = CGRect(x: contentWidth - 65, y: 16, width: 51, height: 31)
        y += 74

        savedTitleLabel.frame = CGRect(x: 14, y: y, width: contentWidth, height: 22)
        y += 28

        emptySavedLabel.frame = CGRect(x: 14, y: y, width: contentWidth, height: 30)

        let savedRowHeight = savedStack.arrangedSubviews.isEmpty
            ? 0
            : CGFloat(savedStack.arrangedSubviews.count) * 44
        savedStack.frame = CGRect(x: 14, y: y, width: contentWidth, height: savedRowHeight)
        y += max(savedRowHeight, 30) + 12

        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: y)
        scrollView.contentSize = CGSize(width: bounds.width, height: y)

        footerLabel.frame = CGRect(x: 14, y: bounds.height - 22, width: bounds.width - 28, height: 16)
        resizeHandle.frame = CGRect(
            x: bounds.width - handleSize, y: bounds.height - handleSize,
            width: handleSize, height: handleSize
        )
    }

    // MARK: Tabs

    @objc private func tabChanged() {
        let searching = tabControl.selectedSegmentIndex == 0

        for view in [instructionLabel, searchField, searchButton, mapView, mapTypeControl,
                     latitudeField, longitudeField, altitudeField, addressField,
                     statusLabel, applyButton, saveCurrentButton, spoofCard] as [UIView] {
            view.isHidden = !searching
        }

        savedTitleLabel.isHidden = searching
        savedStack.isHidden = searching
        emptySavedLabel.isHidden = searching || savedLocations.isEmpty

        setNeedsLayout()
    }

    // MARK: Tìm kiếm

    @objc private func searchTapped() {
        searchLocation()
    }

    private func searchLocation() {
        guard let query = searchField.text, query.isEmpty == false else { return }

        searchField.resignFirstResponder()
        statusLabel.text = "Đang tìm kiếm..."

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                guard let item = response?.mapItems.first else {
                    self.statusLabel.text = "Không tìm thấy địa điểm phù hợp"
                    return
                }

                let address = item.name ?? item.placemark.title ?? ""
                self.setSelectedLocation(
                    coordinate: item.placemark.coordinate,
                    altitude: 0,
                    address: address,
                    centerMap: true
                )
            }
        }
    }

    @objc private func clearSearchTapped() {
        searchField.text = ""
    }

    // MARK: Bản đồ

    @objc private func mapTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        reverseGeocode(coordinate: coordinate, altitude: 0)
    }

    @objc private func mapTypeChanged() {
        switch mapTypeControl.selectedSegmentIndex {
        case 1: mapView.mapType = .satellite
        case 2: mapView.mapType = .hybrid
        default: mapView.mapType = .standard
        }
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let coordinate = view.annotation?.coordinate else { return }
        reverseGeocode(coordinate: coordinate, altitude: 0)
    }

    // MARK: Geocode

    private func reverseGeocode(coordinate: CLLocationCoordinate2D, altitude: Double) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        statusLabel.text = "Đang xác định địa chỉ..."

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let address = self.formatAddress(placemarks?.first)
                self.setSelectedLocation(
                    coordinate: coordinate,
                    altitude: altitude,
                    address: address,
                    centerMap: true
                )
            }
        }
    }

    private func formatAddress(_ placemark: CLPlacemark?) -> String {
        guard let placemark else { return "" }

        let parts = [
            placemark.name,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { $0 }

        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return unique.joined(separator: ", ")
    }

    // MARK: Nhập tay

    @objc private func manualLocationEditingEnded(_ field: UITextField) {
        applyManualLocationFields()
    }

    @objc private func manualAddressEditingEnded(_ field: UITextField) {
        guard let address = addressField.text, address.isEmpty == false else { return }

        statusLabel.text = "Đang tìm toạ độ..."
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self, let location = placemarks?.first?.location else {
                    self?.statusLabel.text = "Không tìm thấy toạ độ cho địa chỉ này"
                    return
                }
                self.setSelectedLocation(
                    coordinate: location.coordinate,
                    altitude: location.altitude,
                    address: address,
                    centerMap: true
                )
            }
        }
    }

    private func applyManualLocationFields() {
        guard
            let latText = latitudeField.text, let lat = Double(latText),
            let lonText = longitudeField.text, let lon = Double(lonText)
        else {
            statusLabel.text = "Toạ độ không hợp lệ"
            return
        }

        let altitude = Double(altitudeField.text ?? "") ?? 0
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        reverseGeocode(coordinate: coordinate, altitude: altitude)
    }

    @objc private func applyTapped() {
        applyManualLocationFields()
    }

    @objc private func clearLatitudeTapped() { latitudeField.text = "" }
    @objc private func clearLongitudeTapped() { longitudeField.text = "" }
    @objc private func clearAltitudeTapped() { altitudeField.text = "" }
    @objc private func clearAddressTapped() { addressField.text = "" }

    private func setSelectedLocation(
        coordinate: CLLocationCoordinate2D,
        altitude: Double,
        address: String,
        centerMap: Bool
    ) {
        selectedCoordinate = coordinate
        selectedAltitude = altitude
        selectedAddress = address

        latitudeField.text = String(format: "%.6f", coordinate.latitude)
        longitudeField.text = String(format: "%.6f", coordinate.longitude)
        altitudeField.text = String(format: "%.1f", altitude)
        addressField.text = address
        statusLabel.text = address.isEmpty ? "Đã chọn vị trí" : address

        mapView.annotations.forEach { mapView.removeAnnotation($0) }
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        pin.title = address
        mapView.addAnnotation(pin)

        if centerMap {
            let region = MKCoordinateRegion(
                center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: true)
        }
    }

    // MARK: Lưu vị trí

    @objc private func saveCurrentTapped() {
        saveSelectedLocation()
    }

    private func saveSelectedLocation() {
        guard let coordinate = selectedCoordinate else {
            statusLabel.text = "Chưa có vị trí để lưu"
            return
        }

        let saved = SavedLocation(
            address: selectedAddress,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: selectedAltitude
        )

        savedLocations.removeAll {
            abs($0.latitude - saved.latitude) < 0.000001 &&
            abs($0.longitude - saved.longitude) < 0.000001
        }
        savedLocations.insert(saved, at: 0)

        persistSavedLocations()
        reloadSavedLocations()
    }

    private func persistSavedLocations() {
        guard let data = try? JSONEncoder().encode(savedLocations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func reloadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }

        savedStack.arrangedSubviews.forEach {
            savedStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for saved in savedLocations {
            savedStack.addArrangedSubview(makeSavedRow(for: saved))
        }

        emptySavedLabel.isHidden = tabControl.selectedSegmentIndex == 0 || savedLocations.isEmpty == false
        setNeedsLayout()
    }

    private func makeSavedRow(for saved: SavedLocation) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        row.layer.cornerRadius = 10
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let label = UILabel()
        label.text = saved.address.isEmpty
            ? String(format: "%.4f, %.4f", saved.latitude, saved.longitude)
            : saved.address
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.numberOfLines = 1

        let useButton = UIButton(type: .system)
        useButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        useButton.tintColor = UIColor.white.withAlphaComponent(0.7)
        useButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.setSelectedLocation(
                coordinate: CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude),
                altitude: saved.altitude,
                address: saved.address,
                centerMap: true
            )
            self.tabControl.selectedSegmentIndex = 0
            self.tabChanged()
        }, for: .touchUpInside)

        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = UIColor.systemRed.withAlphaComponent(0.8)
        deleteButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.savedLocations.removeAll {
                $0.latitude == saved.latitude && $0.longitude == saved.longitude
            }
            self.persistSavedLocations()
            self.reloadSavedLocations()
        }, for: .touchUpInside)

        [label, useButton, deleteButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: useButton.leadingAnchor, constant: -8),

            useButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -4),
            useButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            useButton.widthAnchor.constraint(equalToConstant: 32),

            deleteButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            deleteButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 32)
        ])

        return row
    }

    // MARK: Công tắc giả GPS (UI only — xem ghi chú ở setupSpoofCard)

    @objc private func spoofSwitchChanged() {
        // TODO: chưa có cơ chế thật can thiệp CLLocationManager hệ thống.
        // Đây chỉ log lại trạng thái để không mất thao tác người dùng.
        TPIOSLog.shared.log(
            "TPIOSLocation: spoofSwitch = \(spoofSwitch.isOn) (chưa nối hook thật)"
        )
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        reverseGeocode(coordinate: location.coordinate, altitude: location.altitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusLabel.text = "Không lấy được vị trí hiện tại: \(error.localizedDescription)"
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: Đóng / quay lại

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: Di chuyển

    @objc private func moveView(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }

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

    // MARK: Đổi kích thước

    @objc private func resizeView(_ gesture: UIPanGestureRecognizer) {
        guard let parent = superview else { return }

        switch gesture.state {
        case .began:
            resizeStartFrame = frame
            resizeStartPoint = gesture.location(in: parent)
        case .changed:
            let point = gesture.location(in: parent)
            let dx = point.x - resizeStartPoint.x
            let dy = point.y - resizeStartPoint.y

            let width = max(minWidth, min(resizeStartFrame.width + dx, parent.bounds.width - resizeStartFrame.origin.x))
            let height = max(minHeight, min(resizeStartFrame.height + dy, parent.bounds.height - resizeStartFrame.origin.y))

            frame = CGRect(
                x: resizeStartFrame.origin.x, y: resizeStartFrame.origin.y,
                width: width, height: height
            )
        default:
            break
        }
    }

    private func clamp(_ rect: inout CGRect, in parent: UIView) {
        let maxX = max(0, parent.bounds.width - rect.width)
        let maxY = max(0, parent.bounds.height - rect.height)
        rect.origin.x = max(0, min(rect.origin.x, maxX))
        rect.origin.y = max(0, min(rect.origin.y, maxY))
    }

    // MARK: UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        true
    }
}
