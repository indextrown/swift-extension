//
//  MapHostViewModel.swift
//  SwiftExtension
//
//  Created by 김동현 on 9/22/26.
//

import CoreLocation

/// UIKit 바텀시트 데모의 ViewModel입니다. 위치 권한과 현재 위치만 다룹니다.
///
/// 화면은 `onChange`로 상태를 받아 지도를 옮기고 라벨을 갱신합니다. SwiftUI 데모의
/// `MapDemoViewModel`과는 독립적이에요. 같은 일을 하지만 UIKit 쪽은 클로저로 알립니다.
@MainActor
final class MapHostViewModel: NSObject {

    // MARK: - State

    struct State {
        /// 마지막으로 받은 현재 위치입니다. 아직 없으면 `nil`입니다.
        var coordinate: CLLocationCoordinate2D?

        /// 위치 권한을 받았는지 나타냅니다.
        var isAuthorized = false

        /// 화면에 보여 줄 한 줄 상태입니다.
        var message = "위치 권한 확인 중"
    }

    /// 상태가 바뀔 때마다 호출합니다.
    var onChange: ((State) -> Void)?

    private(set) var state = State() {
        didSet { self.onChange?(self.state) }
    }

    private let manager = CLLocationManager()



    // MARK: - Life Cycle

    override init() {
        super.init()

        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }



    // MARK: - Interface

    /// 권한을 확인하고, 있으면 현재 위치를 한 번 요청합니다. 화면이 열릴 때 부릅니다.
    func start() {
        self.handle(self.manager.authorizationStatus)
    }

    /// 현재 위치를 다시 요청합니다. Locate 버튼이 부릅니다.
    func locate() {
        guard self.state.isAuthorized else {
            self.start()
            return
        }

        self.state.message = "위치 찾는 중"
        self.manager.requestLocation()
    }



    // MARK: - Private

    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self.state.message = "위치 권한 요청 중"
            self.manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            self.state.isAuthorized = true
            self.state.message = "위치 찾는 중"
            self.manager.requestLocation()

        case .denied, .restricted:
            self.state.isAuthorized = false
            self.state.message = "위치 권한 없음"

        @unknown default:
            self.state.message = "알 수 없는 권한 상태"
        }
    }
}



// MARK: - CLLocationManagerDelegate

extension MapHostViewModel: CLLocationManagerDelegate {

    /// CLLocationManager는 만든 스레드(메인)에서 알려 줍니다. 그래도 프로토콜 메서드는 격리를 모르므로
    /// 메인 액터임을 확인하고 들어갑니다.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        MainActor.assumeIsolated {
            self.handle(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }

        MainActor.assumeIsolated {
            self.state.coordinate = coordinate
            self.state.message = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let description = error.localizedDescription

        MainActor.assumeIsolated {
            self.state.message = "위치 실패: \(description)"
        }
    }
}
