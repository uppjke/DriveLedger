//
//  AnalyticsView.swift
//  DriveLedger
//

import SwiftUI
import Foundation
import Charts

struct AnalyticsView: View {
    let entries: [LogEntry]

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

    // Расход берём из пересчитанного поля `fuelConsumptionLPer100km` (FuelConsumption.recalculateAll),
    // чтобы учитывать логику FuelFillKind (full/partial) и избежать расхождений.
    private struct FuelPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }

    private var fuelConsumptionPoints: [FuelPoint] {
        entries
            .filter { $0.kind == .fuel }
            .compactMap { e in
                guard let v = e.fuelConsumptionLPer100km, v.isFinite, v > 0 else { return nil }
                return FuelPoint(id: e.id, date: e.date, value: v)
            }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                return a.id.uuidString < b.id.uuidString
            }
    }

    private var periodFuelConsumptionPoints: [FuelPoint] {
        fuelConsumptionPoints.filter { $0.date >= fromDate }
    }

    private var avgConsumption: Double? {
        let values = periodFuelConsumptionPoints.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var minConsumption: Double? {
        periodFuelConsumptionPoints.map { $0.value }.min()
    }

    private var maxConsumption: Double? {
        periodFuelConsumptionPoints.map { $0.value }.max()
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
        var dict: [Date: (fuel: Double, service: Double, purchase: Double)] = [:]

        for e in periodEntries {
            guard let cost = e.totalCost, cost > 0 else { continue }
            let b = bucketStart(for: e.date)
            var cur = dict[b] ?? (0,0,0)

            switch e.kind {
            case .fuel: cur.fuel += cost
            case .service: cur.service += cost
            case .purchase: cur.purchase += cost
            default: break
            }
            dict[b] = cur
        }

        let buckets = dict.keys.sorted()
        var points: [CostPoint] = []
        for b in buckets {
            let v = dict[b] ?? (0,0,0)
            if v.fuel > 0 { points.append(.init(bucket: b, kindLabel: "Заправки", cost: v.fuel)) }
            if v.service > 0 { points.append(.init(bucket: b, kindLabel: "ТО", cost: v.service)) }
            if v.purchase > 0 { points.append(.init(bucket: b, kindLabel: "Покупки", cost: v.purchase)) }
        }

        // гарантируем стабильный порядок
        return points.sorted { a, b in
            if a.bucket != b.bucket { return a.bucket < b.bucket }
            return a.kindLabel < b.kindLabel
        }
    }

    private var fuelConsumptionSeries: [FuelPoint] {
        periodFuelConsumptionPoints
            .sorted { $0.date < $1.date }
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

            Section("Расход топлива") {
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

                    if fuelConsumptionSeries.count >= 1 {
                        Chart {
                            if fuelConsumptionSeries.count >= 2 {
                                ForEach(fuelConsumptionSeries) { p in
                                    LineMark(
                                        x: .value("Дата", p.date),
                                        y: .value("л/100км", p.value)
                                    )
                                }
                            }

                            ForEach(fuelConsumptionSeries) { p in
                                PointMark(
                                    x: .value("Дата", p.date),
                                    y: .value("л/100км", p.value)
                                )
                            }

                            RuleMark(y: .value("Средний", avg))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .topLeading) {
                                    Text("avg")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                        }
                        .frame(height: 220)

                        if fuelConsumptionSeries.count == 1 {
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
