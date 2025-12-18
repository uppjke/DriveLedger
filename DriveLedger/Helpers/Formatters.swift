//
//  Formatters.swift
//  DriveLedger
//
//  Centralized number/currency formatting helpers.
//

import Foundation

enum DLFormatters {
    static let currencyCode = "RUB"

    static func currency(_ value: Double, code: String = currencyCode) -> String {
        value.formatted(.currency(code: code))
    }

    static func liters(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    static func price(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    static func consumption(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}
