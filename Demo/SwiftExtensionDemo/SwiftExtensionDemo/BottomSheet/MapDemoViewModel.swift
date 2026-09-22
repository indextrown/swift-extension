//
//  MapDemoViewModel.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import CoreLocation
import Observation

/// SwiftUI 바텀시트 데모의 ViewModel입니다. 위치 권한과 현재 위치만 다룹니다.
///
/// `@Observable`이라 View가 읽은 프로퍼티만 바뀔 때 다시 그립니다. UIKit 데모의
/// `MapHostViewModel`과는 독립적이에요. 같은 일을 하지만 SwiftUI 쪽은 관찰로 알립니다.
@MainActor
@Observable
final class MapDemoViewModel {

    /// `CLLocationCoordinate2D`는 `Equatable`이 아니어서 `onChange`에 쓸 수 있게 감쌉니다.
    struct Coordinate: Equatable {
        var latitude: Double
        var longitude: Double

        var clCoordinate: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
        }
    }

    /// 마지막으로 받은 현재 위치입니다. 아직 없으면 `nil`입니다.
    private(set) var coordinate: Coordinate?

    /// 위치 권한을 받았는지 나타냅니다.
    private(set) var isAuthorized = false

    /// 화면에 보여 줄 한 줄 상태입니다.
    private(set) var message = "위치 권한 확인 중"

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let delegateProxy = LocationDelegateProxy()

    init() {
        self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.manager.delegate = self.delegateProxy

        self.delegateProxy.onAuthorization = { [weak self] status in
            self?.handle(status)
        }
        self.delegateProxy.onLocation = { [weak self] coordinate in
            self?.coordinate = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            self?.message = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }
        self.delegateProxy.onError = { [weak self] description in
            self?.message = "위치 실패: \(description)"
        }
    }

    /// 권한을 확인하고, 있으면 현재 위치를 한 번 요청합니다. 화면이 나타날 때 부릅니다.
    func start() {
        self.handle(self.manager.authorizationStatus)
    }

    /// 현재 위치를 다시 요청합니다. Locate 버튼이 부릅니다.
    func locate() {
        guard self.isAuthorized else {
            self.start()
            return
        }

        self.message = "위치 찾는 중"
        self.manager.requestLocation()
    }

    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self.message = "위치 권한 요청 중"
            self.manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            self.isAuthorized = true
            self.message = "위치 찾는 중"
            self.manager.requestLocation()

        case .denied, .restricted:
            self.isAuthorized = false
            self.message = "위치 권한 없음"

        @unknown default:
            self.message = "알 수 없는 권한 상태"
        }
    }
}



// MARK: - Delegate Proxy

/// `CLLocationManagerDelegate`는 NSObject가 필요해서 ViewModel과 분리합니다.
///
/// 이 객체도 메인 액터에 묶습니다. CLLocationManager는 만든 스레드(메인)에서 알려 주지만 프로토콜
/// 메서드는 격리를 모르므로, 값을 꺼낸 뒤 메인 액터임을 확인하고 ViewModel에 넘깁니다.
@MainActor
private final class LocationDelegateProxy: NSObject, CLLocationManagerDelegate {

    var onAuthorization: ((CLAuthorizationStatus) -> Void)?
    var onLocation: ((CLLocationCoordinate2D) -> Void)?
    var onError: ((String) -> Void)?

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        MainActor.assumeIsolated {
            self.onAuthorization?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }

        MainActor.assumeIsolated {
            self.onLocation?(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let description = error.localizedDescription

        MainActor.assumeIsolated {
            self.onError?(description)
        }
    }
}
