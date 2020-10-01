import WidgetKit
import SwiftUI
import Intents
import Charts

let tokyoLocation = CLLocationCoordinate2D(latitude: 35.41, longitude: 139.42)

struct Weather: Codable {
    var cod: String?
    var message: Int?
    var cnt: Int?
    var list: [List]?
    var city: City?
}

struct List: Codable {
    var dt: Date
    var main: Main
    var pop: Double
}

struct Main: Codable {
    var temp: Double
}

struct City: Codable {
    var id: Int
    var name: String
    var coord: Coord
    var country: String
}

struct Coord: Codable {
    var lat: Double = 0.0
    var lon: Double = 0.0
}

struct ChartData {
    var city: String = ""
    var max: Double = 0.0
    var min: Double = 0.0
    var dt: [Date] = []
    var dts: [String] = []
    var pop: [Double] = []
    var temp: [Double] = []
}

func getWeather(from location: CLLocationCoordinate2D) -> Weather {
    var weather = Weather()
    let url = URL(string: "https://api.openweathermap.org/data/2.5/forecast?appid={API_KEY}&units=metric&lat=\(location.latitude)&lon=\(location.longitude)&lang=zh_cn")!
    let request = URLRequest(url: url)
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
        defer {
            semaphore.signal()
        }
        if let error = error {
            // Handle Error
            return
        }
        guard let response = response else {
            // Handle Empty Response
            return
        }
        guard let data = data else {
            // Handle Empty Data
            return
        }
        if let w = try? JSONDecoder().decode(Weather.self, from: data) {
            weather = w
        }
    }
    task.resume()
    semaphore.wait()
    return weather
}

func getChartData(from location: CLLocationCoordinate2D) -> ChartData {
    var chartData = ChartData()
    let weather = getWeather(from: location)
    if weather.list != nil {
        chartData.city = weather.city!.name
        for i in 0..<8{
            chartData.dt.append(weather.list![i].dt)
            chartData.pop.insert(weather.list![i].pop, at: 0)
            chartData.temp.append(weather.list![i].main.temp)
        }
        chartData.max = chartData.temp.max() ?? 0
        chartData.min = chartData.temp.min() ?? 0
        for i in 0..<8 {
            chartData.temp[i] = (chartData.temp[i] - chartData.min + 1) / (chartData.max - chartData.min + 2)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH"
            chartData.dts.append(formatter.string(from: chartData.dt[i]))
        }
    }
    return chartData
}

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), chartData: getChartData(from: tokyoLocation))
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), chartData: getChartData(from: configuration.location!.location!.coordinate))
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 1 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, chartData: getChartData(from: configuration.location!.location!.coordinate))
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let chartData: ChartData
}

struct TrendEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        if entry.chartData.city == "" {
            Text("获取失败！")
        } else {
            HStack{
                VStack{
                    Text("\(entry.chartData.max, specifier: "%.0f")°C").font(.system(size: 13))
                    Spacer()
                    Text("\(entry.chartData.min, specifier: "%.0f")°C").font(.system(size: 13))
                }
                .padding(.top, 5)
                .padding(.bottom, 25)
                VStack{
                    ZStack{
                        Chart(data: entry.chartData.pop)
                            .chartStyle(
                                ColumnChartStyle(column: Capsule().foregroundColor(.gray), spacing: 20)
                            )
                            .padding(.horizontal, 10)
                        Chart(data: entry.chartData.temp)
                            .chartStyle(
                                LineChartStyle(.quadCurve, lineColor: .blue, lineWidth: 4)
                            )
                            .padding(.horizontal, 10)
                    }
                    HStack{
                        ForEach(entry.chartData.dts.indices) { i in
                            Text("\(entry.chartData.dts[i])").font(.system(size: 12))
                            if i != 7 {
                                Text("∙∙").font(.system(size: 12))
                            }
                        }
                        .padding(.leading, -6.6)
                    }
                    .padding(.leading, 9)
                }
                .padding(.trailing, 10)
            }
            .padding(10)
        }
    }
}

@main
struct Trend: Widget {
    let kind: String = "Trend"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            TrendEntryView(entry: entry)
        }
        .configurationDisplayName("The Weather")
        .description("This is a weather chart")
        .supportedFamilies([.systemMedium])
    }
}

struct Trend_Previews: PreviewProvider {
    static var previews: some View {
        TrendEntryView(entry: SimpleEntry(date: Date(), chartData: getChartData(from: tokyoLocation)))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
