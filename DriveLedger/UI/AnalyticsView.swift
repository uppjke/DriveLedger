//
//  AnalyticsView.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import Charts

struct AnalyticsView: View {
    let entries: [LogEntry]

    @State private var fuelMode: FuelConsumption.Mode = .perFillUp

    private enum Period: String, CaseIterable, Identifiable {
        case d30 = "30д"
        case d90 = "90д"
        case y1 = "365д"
        var id: String { rawValue }

        var days: Int {
            switch self {
            case .d30: return 30
            case .d90: return 90
            case .y1: return 365
            }
        }
    }

    @State private var period: Period = .d30

    private var fromDate: Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
    }

    private var periodEntries: [LogEntry] {
        entries.filter { $0.date >= fromDate }
    }

    private var totalCost: Double {
        periodEntries.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costFuel: Double {
        periodEntries.filter { $0.kind == .fuel }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costService: Double {
        periodEntries.filter { $0.kind == .service }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costPurchase: Double {
        periodEntries.filter { $0.kind == .purchase }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costTolls: Double {
        periodEntries.filter { $0.kind == .tolls }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costFines: Double {
        periodEntries.filter { $0.kind == .fines }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costCarwash: Double {
        periodEntries.filter { $0.kind == .carwash }.compactMap { $0.totalCost }.reduce(0, +)
    }

    private var costParking: Double {
        periodEntries.filter { $0.kind == .parking }.compactMap { $0.totalCost }.reduce(0, +)
    }

    // MARK: - Fuel series
    private var allFuelSeries: [(date: Date, value: Double)] {
        FuelConsumption.series(existingEntries: entries, mode: fuelMode)
    }

    private var periodFuelSeries: [(date: Date, value: Double)] {
        allFuelSeries.filter { $0.date >= fromDate }
    }

    private var avgConsumption: Double? {
        let values = periodFuelSeries.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var minConsumption: Double? { periodFuelSeries.map { $0.value }.min() }
    private var maxConsumption: Double? { periodFuelSeries.map { $0.value }.max() }

    // MARK: - Distance (driven) series + forecast

    private struct OdometerPoint: Identifiable {
        let id = UUID()
        let date: Date
        let km: Double
    }

    private var odometerPoints: [OdometerPoint] {
        // Use one point per day (max odometer), to reduce jitter from multiple same-day entries.
        // Also include a baseline point at the period start (if we have an older odometer) so
        // "проехал за период" is accurate.
        var perDayMax: [Date: Int] = [:]
        let cal = Calendar.current

        for e in entries {
            guard let km = e.odometerKm else { continue }
            guard e.date >= fromDate else { continue }
            let day = cal.startOfDay(for: e.date)
            perDayMax[day] = max(perDayMax[day] ?? km, km)
        }

        let baselineKm = entries
            .filter { ($0.odometerKm != nil) && ($0.date < fromDate) }
            .max(by: { $0.date < $1.date })
            .flatMap { $0.odometerKm }

        var points: [OdometerPoint] = perDayMax
            .map { (day, km) in OdometerPoint(date: day, km: Double(km)) }

        if let baselineKm {
            points.append(OdometerPoint(date: fromDate, km: Double(baselineKm)))
        }

        return points.sorted { $0.date < $1.date }
    }

    private func linearForecast(points: [OdometerPoint]) -> (slopeKmPerDay: Double, interceptKm: Double, startDate: Date)? {
        // y = intercept + slope * x, where x is days since startDate.
        guard points.count >= 1, let startDate = points.first?.date else { return nil }

        if points.count == 1 {
            return (0, points[0].km, startDate)
        }

        let xs: [Double] = points.map { $0.date.timeIntervalSince(startDate) / 86_400 }
        let ys: [Double] = points.map { $0.km }

        let n = Double(points.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }

        let denom = (n * sumXX - sumX * sumX)

        // If all points have the same x (e.g. multiple entries on the same day), fall back to a flat forecast.
        if abs(denom) <= 1e-9 {
            let intercept = sumY / n
            return (0, intercept, startDate)
        }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept, startDate)
    }

    private var odometerForecast: (line: [OdometerPoint], predictedAtHorizon: Int, horizonDays: Int)? {
        guard let last = odometerPoints.last else { return nil }
        let horizonDays = period.days
        guard let reg = linearForecast(points: odometerPoints) else { return nil }

        let cal = Calendar.current
        let futureDate = cal.date(byAdding: .day, value: horizonDays, to: last.date) ?? last.date

        func predictKm(at date: Date) -> Double {
            let x = date.timeIntervalSince(reg.startDate) / 86_400
            return reg.interceptKm + reg.slopeKmPerDay * x
        }

        let predicted = Int(predictKm(at: futureDate).rounded())
        let forecastLine = [
            OdometerPoint(date: last.date, km: last.km),
            OdometerPoint(date: futureDate, km: Double(predicted))
        ]

        return (forecastLine, predicted, horizonDays)
    }

    private struct TravelPoint: Identifiable {
        let id = UUID()
        let date: Date
        let km: Double
    }

    private var travelPoints: [TravelPoint] {
        guard let first = odometerPoints.first else { return [] }
        let base = first.km
        return odometerPoints.map { p in
            TravelPoint(date: p.date, km: max(0, p.km - base))
        }
    }

    private var travelTotalKm: Int? {
        guard let last = travelPoints.last else { return nil }
        return Int(last.km.rounded())
    }

    private var travelForecast: (line: [TravelPoint], predictedDistance: Int, horizonDays: Int)? {
        guard let lastOdo = odometerPoints.last, let firstOdo = odometerPoints.first else { return nil }
        guard let reg = linearForecast(points: odometerPoints) else { return nil }
        let horizonDays = period.days

        let base = firstOdo.km
        let currentTravel = max(0, lastOdo.km - base)
        let daily = max(0, reg.slopeKmPerDay)
        let predictedDistance = Int((daily * Double(horizonDays)).rounded())

        let cal = Calendar.current
        let futureDate = cal.date(byAdding: .day, value: horizonDays, to: lastOdo.date) ?? lastOdo.date

        let line = [
            TravelPoint(date: lastOdo.date, km: currentTravel),
            TravelPoint(date: futureDate, km: currentTravel + Double(predictedDistance))
        ]

        return (line, predictedDistance, horizonDays)
    }

    // MARK: - Charts data

    private struct CostPoint: Identifiable {
        let id = UUID()
        let bucket: Date
        let kindLabel: String
        let cost: Double
    }

    private var bucketUnit: Calendar.Component {
        period == .d30 ? .day : .weekOfYear
    }

    private func bucketStart(for date: Date) -> Date {
        let cal = Calendar.current
        switch bucketUnit {
        case .day:
            return cal.startOfDay(for: date)
        case .weekOfYear:
            return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        default:
            return cal.startOfDay(for: date)
        }
    }

    private var costPoints: [CostPoint] {
        var dict: [Date: (fuel: Double, service: Double, purchase: Double, tolls: Double, fines: Double, carwash: Double, parking: Double)] = [:]

        for e in periodEntries {
            guard let cost = e.totalCost, cost > 0 else { continue }
            let b = bucketStart(for: e.date)
            var cur = dict[b] ?? (0,0,0,0,0,0,0)

            switch e.kind {
            case .fuel: cur.fuel += cost
            case .service: cur.service += cost
            case .purchase: cur.purchase += cost
            case .tolls: cur.tolls += cost
            case .fines: cur.fines += cost
            case .carwash: cur.carwash += cost
            case .parking: cur.parking += cost
            default: break
            }
            dict[b] = cur
        }

        let buckets = dict.keys.sorted()
        var points: [CostPoint] = []
        for b in buckets {
            let v = dict[b] ?? (0,0,0,0,0,0,0)
            if v.fuel > 0 { points.append(.init(bucket: b, kindLabel: "Заправки", cost: v.fuel)) }
            if v.service > 0 { points.append(.init(bucket: b, kindLabel: "ТО", cost: v.service)) }
            if v.purchase > 0 { points.append(.init(bucket: b, kindLabel: "Покупки", cost: v.purchase)) }
            if v.tolls > 0 { points.append(.init(bucket: b, kindLabel: "Платные дороги", cost: v.tolls)) }
            if v.parking > 0 { points.append(.init(bucket: b, kindLabel: "Парковка", cost: v.parking)) }
            if v.fines > 0 { points.append(.init(bucket: b, kindLabel: "Штрафы", cost: v.fines)) }
            if v.carwash > 0 { points.append(.init(bucket: b, kindLabel: "Автомойка", cost: v.carwash)) }
        }

        return points.sorted { a, b in
            if a.bucket != b.bucket { return a.bucket < b.bucket }
            return a.kindLabel < b.kindLabel
        }
    }

    var body: some View {
        Group {
            Section {
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Расходы") {
                HStack {
                    Label("Всего", systemImage: "sum")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(totalCost, format: .currency(code: DLFormatters.currencyCode))
                        .font(.headline)
                }

                HStack {
                    Label("Заправки", systemImage: "fuelpump")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costFuel, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("ТО", systemImage: "wrench.and.screwdriver")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costService, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("Покупки", systemImage: "cart")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costPurchase, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("Платные дороги", systemImage: "road.lanes")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costTolls, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("Штрафы", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costFines, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("Автомойка", systemImage: "drop")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costCarwash, format: .currency(code: DLFormatters.currencyCode))
                }

                HStack {
                    Label("Парковка", systemImage: "parkingsign.circle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(costParking, format: .currency(code: DLFormatters.currencyCode))
                }
            }

            Section("Динамика расходов") {
                if costPoints.isEmpty {
                    ContentUnavailableView(
                        "Нет данных",
                        systemImage: "chart.bar",
                        description: Text("Добавьте записи с суммой, чтобы построить график")
                    )
                } else {
                    Chart(costPoints) { p in
                        BarMark(
                            x: .value("Период", p.bucket, unit: bucketUnit),
                            y: .value("Сумма", p.cost)
                        )
                        .foregroundStyle(by: .value("Тип", p.kindLabel))
                    }
                    .chartLegend(.visible)
                    .frame(height: 220)
                }
            }

            Section("Пробег") {
                if travelPoints.isEmpty {
                    ContentUnavailableView(
                        "Недостаточно данных",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Добавьте хотя бы одно значение пробега в выбранном периоде")
                    )
                } else {
                    if let total = travelTotalKm {
                        HStack {
                            Label("Проехал", systemImage: "speedometer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(total) км")
                                .font(.headline)
                        }
                    }

                    if let forecast = travelForecast {
                        HStack {
                            Text("Прогноз · \(forecast.horizonDays) дней")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(forecast.predictedDistance) км")
                        }
                    }

                    Chart {
                        ForEach(travelPoints) { p in
                            LineMark(
                                x: .value("Дата", p.date),
                                y: .value("км", p.km)
                            )
                        }

                        ForEach(travelPoints) { p in
                            PointMark(
                                x: .value("Дата", p.date),
                                y: .value("км", p.km)
                            )
                        }

                        if let forecast = travelForecast {
                            ForEach(forecast.line) { p in
                                LineMark(
                                    x: .value("Дата", p.date),
                                    y: .value("км", p.km)
                                )
                                .foregroundStyle(.tint)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            }
                        }
                    }
                    .frame(height: 220)
                    .padding(.leading, 6)
                }
            }

            Section("Расход топлива") {
                Picker("Режим", selection: $fuelMode) {
                    ForEach(FuelConsumption.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let avg = avgConsumption {
                    HStack {
                        Label("Средний", systemImage: "gauge")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(DLFormatters.consumption(avg)) л/100км")
                            .font(.headline)
                    }

                    if let mn = minConsumption, let mx = maxConsumption {
                        HStack {
                            Text("Мин/Макс")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(DLFormatters.consumption(mn)) / \(DLFormatters.consumption(mx))")
                        }
                    }

                    if periodFuelSeries.count >= 1 {
                        Chart {
                            if periodFuelSeries.count >= 2 {
                                ForEach(Array(periodFuelSeries.enumerated()), id: \.offset) { _, p in
                                    LineMark(
                                        x: .value("Дата", p.date),
                                        y: .value("л/100км", p.value)
                                    )
                                }
                            }

                            ForEach(Array(periodFuelSeries.enumerated()), id: \.offset) { _, p in
                                PointMark(
                                    x: .value("Дата", p.date),
                                    y: .value("л/100км", p.value)
                                )
                            }

                            RuleMark(y: .value("Средний", avg))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .overlay, alignment: .topLeading) {
                                    Text("avg")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
                                        .padding(.top, 6)
                                        .padding(.leading, 6)
                                }
                        }
                        .frame(height: 220)
                        // Give axis labels and annotations a bit more breathing room.
                        .padding(.leading, 6)

                        if periodFuelSeries.count == 1 {
                            Text("Пока доступна одна точка (2 заправки с пробегом дают 1 расчёт). График линией появится после следующей заправки.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ContentUnavailableView(
                            "Недостаточно данных",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Добавьте минимум две заправки с пробегом, чтобы посчитать расход")
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "Недостаточно данных",
                        systemImage: "gauge.with.dots.needle.33percent",
                        description: Text("Добавьте минимум две заправки с пробегом, чтобы посчитать расход")
                    )
                }
            }
        }
    }
}
