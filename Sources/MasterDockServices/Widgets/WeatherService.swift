import Foundation
import Combine
import CoreLocation

public struct WeatherInfo: Equatable, Sendable {
    public let temperature: Int
    public let condition: String
    public let locationName: String
    public let highTemp: Int
    public let lowTemp: Int
    public let iconSystemName: String
    
    public init(
        temperature: Int = 72,
        condition: String = "Partly Cloudy",
        locationName: String = "",
        highTemp: Int = 78,
        lowTemp: Int = 58,
        iconSystemName: String = "cloud.sun.fill"
    ) {
        self.temperature = temperature
        self.condition = condition
        self.locationName = locationName
        self.highTemp = highTemp
        self.lowTemp = lowTemp
        self.iconSystemName = iconSystemName
    }
}

/// Weather for wherever this Mac is. It asks macOS for the location once (the person can say no),
/// and otherwise uses the city from the Mac's time zone. Units follow the Mac's region settings.
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()
    
    @Published public private(set) var currentWeather: WeatherInfo = WeatherInfo(temperature: 0, condition: "Loading", locationName: "", highTemp: 0, lowTemp: 0, iconSystemName: "cloud.sun.fill")
    
    private let locationManager = CLLocationManager()
    private var lastCoordinate: CLLocationCoordinate2D?
    private var refreshTimer: Timer?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        fetchWeather()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        refreshTimer?.tolerance = 120
    }
    
    public func fetchWeather() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Don't pop up a permission request on its own; the welcome screen asks.
            fetchFromTimeZone()
        case .authorizedAlways, .authorized:
            locationManager.requestLocation()
            if let coordinate = lastCoordinate { load(latitude: coordinate.latitude, longitude: coordinate.longitude, name: "") }
        default:
            fetchFromTimeZone()
        }
    }
    
    // MARK: Location
    
    public static let locationAskedKey = "weather_location_asked"
    
    /// Shows macOS's location prompt (once). Called from the welcome screen.
    public func requestLocationAccess() {
        UserDefaults.standard.set(true, forKey: Self.locationAskedKey)
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            fetchWeather()
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized: manager.requestLocation()
        case .denied, .restricted: fetchFromTimeZone()
        default: break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastCoordinate = location.coordinate
        load(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, name: "")
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let city = placemarks?.first?.locality else { return }
            DispatchQueue.main.async {
                let w = self.currentWeather
                self.currentWeather = WeatherInfo(temperature: w.temperature, condition: w.condition, locationName: city,
                                                  highTemp: w.highTemp, lowTemp: w.lowTemp, iconSystemName: w.iconSystemName)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if lastCoordinate == nil { fetchFromTimeZone() }
    }
    
    /// No location permission: look up the city in the Mac's time zone (e.g. America/Los_Angeles).
    private func fetchFromTimeZone() {
        let identifier = TimeZone.current.identifier
        let city = identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? ""
        guard !city.isEmpty,
              let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1") else { return }
        Task {
            guard let result = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
                  let first = (json["results"] as? [[String: Any]])?.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double else { return }
            self.load(latitude: lat, longitude: lon, name: (first["name"] as? String) ?? city)
        }
    }
    
    // MARK: Forecast
    
    private var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }
    
    private func load(latitude: Double, longitude: Double, name: String) {
        let unit = usesFahrenheit ? "fahrenheit" : "celsius"
        Task {
            guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=\(unit)&timezone=auto") else { return }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let temp = current["temperature_2m"] as? Double,
                   let weatherCode = current["weather_code"] as? Int,
                   let daily = json["daily"] as? [String: Any],
                   let maxTemps = daily["temperature_2m_max"] as? [Double],
                   let minTemps = daily["temperature_2m_min"] as? [Double] {
                    
                    let (conditionName, iconName) = self.decodeWeatherCode(weatherCode)
                    await MainActor.run {
                        let keepName = name.isEmpty ? self.currentWeather.locationName : name
                        self.currentWeather = WeatherInfo(
                            temperature: Int(temp.rounded()),
                            condition: conditionName,
                            locationName: keepName,
                            highTemp: Int((maxTemps.first ?? temp + 5).rounded()),
                            lowTemp: Int((minTemps.first ?? temp - 5).rounded()),
                            iconSystemName: iconName
                        )
                    }
                }
            } catch {
                // Keep showing the last weather.
            }
        }
    }
    
    private func decodeWeatherCode(_ code: Int) -> (String, String) {
        switch code {
        case 0:
            return ("Clear Sky", "sun.max.fill")
        case 1, 2:
            return ("Partly Cloudy", "cloud.sun.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51...67:
            return ("Rain Showers", "cloud.rain.fill")
        case 71...77:
            return ("Snow", "cloud.snow.fill")
        case 95...99:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        default:
            return ("Mostly Sunny", "sun.max.fill")
        }
    }
}
