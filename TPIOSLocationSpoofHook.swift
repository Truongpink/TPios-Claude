import CoreLocation

// Hook thật cho tính năng giả GPS. Tweak được tiêm thẳng vào tiến trình
// Shopee nên swizzle ở đây tác động lên CHÍNH runtime đó — khi bật spoof,
// mọi CLLocationManager trong tiến trình (của Shopee lẫn của chính
// TPIOSLocation) đều nhận toạ độ giả.
//
// Nguyên tắc an toàn: khi tắt spoof, gọi thẳng implementation gốc, không
// đổi hành vi thật của app. Khi bật spoof, KHÔNG gọi implementation gốc
// (không đụng tới GPS thật), chỉ trả thẳng toạ độ giả — tránh trường hợp
// vị trí thật đến sau đè lên vị trí giả.
final class TPIOSLocationSpoofHook {

    static let shared = TPIOSLocationSpoofHook()

    private var didInstall = false

    var isEnabled = false {
        didSet {
            TPIOSLog.shared.log("LocationSpoof: isEnabled = \(isEnabled)")
        }
    }

    var fakeCoordinate: CLLocationCoordinate2D?
    var fakeAltitude: Double = 0

    private init() {}

    func install() {

        guard didInstall == false else {
            return
        }
        didInstall = true

        swizzle(
            originalSelector: #selector(CLLocationManager.startUpdatingLocation),
            swizzledSelector: #selector(CLLocationManager.tpios_startUpdatingLocation)
        )

        swizzle(
            originalSelector: #selector(CLLocationManager.requestLocation),
            swizzledSelector: #selector(CLLocationManager.tpios_requestLocation)
        )

        swizzle(
            originalSelector: NSSelectorFromString("location"),
            swizzledSelector: #selector(CLLocationManager.tpios_location)
        )

        TPIOSLog.shared.log("LocationSpoof: đã hook CLLocationManager (startUpdatingLocation/requestLocation/location)")
    }

    private func swizzle(originalSelector: Selector, swizzledSelector: Selector) {

        guard
            let originalMethod = class_getInstanceMethod(CLLocationManager.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(CLLocationManager.self, swizzledSelector)
        else {
            TPIOSLog.shared.log("LocationSpoof: không lấy được method \(originalSelector) để swizzle")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    fileprivate func makeFakeLocationIfEnabled() -> CLLocation? {

        guard isEnabled, let coordinate = fakeCoordinate else {
            return nil
        }

        return CLLocation(
            coordinate: coordinate,
            altitude: fakeAltitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
    }
}

extension CLLocationManager {

    @objc fileprivate func tpios_startUpdatingLocation() {

        guard let fake = TPIOSLocationSpoofHook.shared.makeFakeLocationIfEnabled() else {
            // Spoof đang tắt — gọi implementation gốc (đã bị hoán đổi
            // bằng method_exchangeImplementations), không đổi hành vi thật.
            self.tpios_startUpdatingLocation()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.locationManager?(self, didUpdateLocations: [fake])
        }
    }

    @objc fileprivate func tpios_requestLocation() {

        guard let fake = TPIOSLocationSpoofHook.shared.makeFakeLocationIfEnabled() else {
            self.tpios_requestLocation()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.locationManager?(self, didUpdateLocations: [fake])
        }
    }

    @objc fileprivate func tpios_location() -> CLLocation? {

        if let fake = TPIOSLocationSpoofHook.shared.makeFakeLocationIfEnabled() {
            return fake
        }

        return self.tpios_location()
    }
}
