import StateUI

/// A request through the platform's own networking: the weather in Kraków now, from Open-Meteo, which asks no key.
struct HTTPRequestSample: SampleContent, ExampleContent {
    // listing: HTTPRequestSample
    @Environment(\.application) private var application
    @State private var said = "Ask for the weather"
    // listing: end

    static let id = "httpRequest"
    static let title = "HTTP request"
    static let summary = "A request through the platform's own networking - the weather in Kraków, from Open-Meteo."

    // listing: HTTPRequestSample
    var body: some View {
        VStack {
            // What came back is read here, so an answer builds this closure.
            DebugInfoLabel()

            Button("Weather in Kraków")
                .accessibilityIdentifier("httpRequest.weather")
                .onClicked(.cancelPrevious) {
                    said = "Asking…"
                    do {
                        let response = try await application.send(HTTPRequest(
                            "https://api.open-meteo.com/v1/forecast?latitude=50.06&longitude=19.94"
                                + "&current=temperature_2m,wind_speed_10m"))
                        // Any status is an answer: only no answer at all throws.
                        guard response.status == 200 else {
                            said = "The server answered \(response.status)"
                            return
                        }
                        let temperature = Self.number("temperature_2m", in: response.text)
                        let wind = Self.number("wind_speed_10m", in: response.text)
                        said = "\(temperature) °C, wind \(wind) km/h"
                    } catch let failure as StateUIError {
                        said = "No answer: \(failure.message)"
                    }
                }
                .horizontalAlignment(.center)

            Text(said)
                .accessibilityIdentifier("httpRequest.said")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    /// The number after `"name":` in the answer's `current` part - as much of JSON as two numbers need.
    private static func number(_ name: String, in json: String) -> String {
        let current = json.split(separator: "\"current\":").last ?? ""
        guard let found = current.firstRange(of: "\"\(name)\":") else { return "?" }
        return String(current[found.upperBound...].prefix { "-.0123456789".contains($0) })
    }
    // listing: end

    var notes: (any View)? {
        Text("The request goes through the platform's own networking - its certificates, proxy and cookies. "
            + "Open-Meteo answers without a key.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
