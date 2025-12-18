import Foundation

enum VehicleCatalog {
    /// A small built-in catalog: enough to cover most users, with a manual fallback.
    /// This keeps the UX "pick from list" without pulling remote databases.
    /// Makes shown in pickers.
    static let pickerMakes: [String] = [
        // RU / CIS (canonical display in Cyrillic)
        "ВАЗ", "ГАЗ", "КамАЗ", "Лада", "Москвич", "УАЗ",

        // Popular in RU market (EU/JP/KR)
        "Audi", "BMW", "Chevrolet", "Citroën", "Ford", "Honda", "Hyundai", "Kia", "Lexus",
        "Mazda", "Mercedes-Benz", "Mitsubishi", "Nissan", "Opel", "Peugeot", "Renault", "Skoda",
        "Subaru", "Suzuki", "Toyota", "Volkswagen", "Volvo",

        // Others (common)
        "Acura", "Alfa Romeo", "Cadillac", "Chrysler", "Dodge", "Fiat", "Infiniti", "Isuzu",
        "Jaguar", "Jeep", "Land Rover", "Mini", "Porsche", "SEAT", "Smart", "SsangYong",

        // China (popular)
        "BYD", "Changan", "Chery", "Exeed", "Geely", "Great Wall", "Haval", "Hongqi", "Jetour",
        "Jaecoo", "Lifan", "Omoda", "Tank", "Voyah", "Zeekr",

        // EV
        "Tesla"
    ]

    /// Backwards-compatible aliases (e.g. old saved values).
    static let makeAliases: [String: String] = [
        "VAZ": "ВАЗ",
        "LADA": "Лада",
        "Lada": "Лада",
        "UAZ": "УАЗ",
        "GAZ": "ГАЗ",
        "KAMAZ": "КамАЗ",
        "Moskvich": "Москвич",
        "MOSKVICH": "Москвич",
    ]

    private static let domesticMakes: Set<String> = ["ВАЗ", "Лада", "УАЗ", "ГАЗ", "КамАЗ", "Москвич"]

    static func isDomestic(make raw: String?) -> Bool {
        guard let c = canonicalMake(raw) else { return false }
        return domesticMakes.contains(c)
    }

    static func canonicalMake(_ raw: String?) -> String? {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return makeAliases[t] ?? t
    }

    static func isKnownMake(_ raw: String?) -> Bool {
        guard let c = canonicalMake(raw) else { return false }
        return pickerMakes.contains(c)
    }

    /// Very small model suggestions per make (not exhaustive). Users can always type a custom model.
    static let modelsByMake: [String: [String]] = [
        // RU / CIS (use Cyrillic for domestic models)
        "ВАЗ": [
            "2101", "2102", "2103", "2104", "2105", "2106", "2107",
            "2108", "2109", "21099",
            "2110", "2111", "2112",
            "2113", "2114", "2115",
            "2121 Нива", "2131", "2329"
        ],
        "ГАЗ": ["Газель", "Соболь", "Волга", "Садко"],
        "КамАЗ": ["5490", "65115", "6520"],
        "Лада": ["Гранта", "Веста", "Ларгус", "Нива Legend", "Нива Travel", "Калина", "Приора"],
        "Москвич": ["3", "3e", "6"],
        "УАЗ": ["Патриот", "Хантер", "Буханка", "Пикап", "Профи"],

        // Others
        "Audi": ["A3", "A4", "A6", "Q3", "Q5"],
        "Acura": ["MDX", "RDX", "TLX"],
        "Alfa Romeo": ["Giulia", "Stelvio"],
        "BYD": ["Song", "Han", "Atto 3"],
        "BMW": ["1 Series", "3 Series", "5 Series", "X3", "X5"],
        "Cadillac": ["Escalade", "XT5", "CTS"],
        "Changan": ["CS35", "CS55", "CS75"],
        "Chery": ["Tiggo 4", "Tiggo 7", "Tiggo 8"],
        "Chevrolet": ["Cruze", "Aveo", "Niva", "Captiva"],
        "Citroën": ["C3", "C4", "C5", "Berlingo"],
        "Chrysler": ["300C", "Pacifica"],
        "Dodge": ["Charger", "Durango"],
        "Exeed": ["TXL", "VX"],
        "Fiat": ["Punto", "500", "Doblo"],
        "Ford": ["Focus", "Fiesta", "Mondeo", "Kuga"],
        "Geely": ["Coolray", "Atlas", "Emgrand"],
        "Great Wall": ["Wingle", "H3", "H5"],
        "Haval": ["Jolion", "F7", "Dargo"],
        "Hongqi": ["H5", "H9"],
        "Honda": ["Civic", "Accord", "CR-V", "Fit"],
        "Hyundai": ["Solaris", "Elantra", "Tucson", "Santa Fe"],
        "Infiniti": ["Q50", "QX50", "QX60"],
        "Isuzu": ["D-Max", "MU-X"],
        "Jaguar": ["XE", "XF", "F-Pace"],
        "Jaecoo": ["J7"],
        "Jeep": ["Grand Cherokee", "Wrangler", "Compass"],
        "Jetour": ["X70", "X90"],
        "Kia": ["Rio", "Ceed", "Sportage", "Sorento"],
        "Land Rover": ["Discovery", "Range Rover", "Defender"],
        "Lexus": ["IS", "ES", "RX", "NX"],
        "Lifan": ["X60", "X70", "Solano"],
        "Mazda": ["Mazda 3", "Mazda 6", "CX-5", "CX-30"],
        "Mercedes-Benz": ["A-Class", "C-Class", "E-Class", "GLC"],
        "Mini": ["Cooper", "Countryman"],
        "Mitsubishi": ["Lancer", "Outlander", "ASX", "Pajero"],
        "Nissan": ["Qashqai", "X-Trail", "Juke", "Almera"],
        "Opel": ["Astra", "Corsa", "Insignia"],
        "Omoda": ["C5"],
        "Porsche": ["Cayenne", "Macan", "Panamera"],
        "Peugeot": ["208", "308", "3008", "Partner"],
        "Renault": ["Logan", "Sandero", "Duster", "Kaptur"],
        "SEAT": ["Ibiza", "Leon"],
        "Skoda": ["Octavia", "Rapid", "Kodiaq", "Superb"],
        "Smart": ["Fortwo"],
        "SsangYong": ["Actyon", "Kyron", "Rexton"],
        "Subaru": ["Impreza", "Forester", "Outback"],
        "Suzuki": ["Swift", "Vitara", "SX4"],
        "Tank": ["300", "500"],
        "Tesla": ["Model 3", "Model Y", "Model S"],
        "Toyota": ["Corolla", "Camry", "RAV4", "Land Cruiser"],
        "Volkswagen": ["Polo", "Golf", "Passat", "Tiguan"],
        "Volvo": ["XC40", "XC60", "XC90", "S60"],
        "Voyah": ["Free", "Dream"],
        "Zeekr": ["001", "X"]
    ]

    static func models(forMake rawMake: String) -> [String] {
        let make = canonicalMake(rawMake) ?? rawMake
        return modelsByMake[make] ?? []
    }

    /// Generation suggestions for popular make+model pairs.
    /// Key format: "<make>|<model>".
    static let generationsByMakeModel: [String: [String]] = [
        // Лада / ВАЗ
        "Лада|Гранта": ["I (2011–2018)", "I рестайлинг (2018–н.в.)"],
        "Лада|Веста": ["I (2015–2022)", "NG (2023–н.в.)"],
        "Лада|Ларгус": ["I (2012–2022)", "I рестайлинг (2021–н.в.)"],
        "Лада|Калина": ["I (2004–2013)", "II (2013–2018)"],
        "Лада|Приора": ["I (2007–2013)", "I рестайлинг (2013–2018)"],
        "Лада|Нива Legend": ["2121/2131"],
        "Лада|Нива Travel": ["I"],

        "ВАЗ|2101": ["I"],
        "ВАЗ|2102": ["I"],
        "ВАЗ|2103": ["I"],
        "ВАЗ|2104": ["I"],
        "ВАЗ|2105": ["I"],
        "ВАЗ|2106": ["I"],
        "ВАЗ|2107": ["I"],
        "ВАЗ|2108": ["I"],
        "ВАЗ|2109": ["I"],
        "ВАЗ|21099": ["I"],
        "ВАЗ|2110": ["I"],
        "ВАЗ|2111": ["I"],
        "ВАЗ|2112": ["I"],
        "ВАЗ|2113": ["I"],
        "ВАЗ|2114": ["I"],
        "ВАЗ|2115": ["I"],
        "ВАЗ|2121 Нива": ["2121", "21213", "2131"],

        // УАЗ
        "УАЗ|Патриот": ["I (2005–2014)", "рестайлинг (2014–2016)", "обновление (2016–2019)", "обновление (2019–н.в.)"],
        "УАЗ|Хантер": ["315195"],
        "УАЗ|Буханка": ["452"],
        "УАЗ|Пикап": ["I"],
        "УАЗ|Профи": ["I"],

        // ГАЗ
        "ГАЗ|Газель": ["Бизнес", "Next"],
        "ГАЗ|Соболь": ["Бизнес", "4x4"],
        "ГАЗ|Волга": ["3110", "31105"],
        "ГАЗ|Садко": ["I", "Next"],

        // Москвич
        "Москвич|3": ["I"],
        "Москвич|3e": ["I"],
        "Москвич|6": ["I"],

        // КамАЗ (грубо)
        "КамАЗ|5490": ["I"],
        "КамАЗ|65115": ["I"],
        "КамАЗ|6520": ["I"],

        // Toyota
        "Toyota|Camry": ["XV40", "XV50", "XV70"],
        "Toyota|Corolla": ["E120", "E150", "E170", "E210"],
        "Toyota|RAV4": ["XA30", "XA40", "XA50"],

        // Volkswagen
        "Volkswagen|Polo": ["Mk5", "Mk6"],
        "Volkswagen|Passat": ["B6", "B7", "B8"],

        // BMW
        "BMW|3 Series": ["E46", "E90", "F30", "G20"],
        "BMW|5 Series": ["E60", "F10", "G30"],

        // Mercedes-Benz
        "Mercedes-Benz|C-Class": ["W204", "W205", "W206"],
        "Mercedes-Benz|E-Class": ["W211", "W212", "W213"],

        // Hyundai / Kia
        "Hyundai|Solaris": ["I", "II"],
        "Kia|Rio": ["III", "IV"],

        // Renault
        "Renault|Duster": ["I", "II"],
        "Renault|Logan": ["I", "II"],

        // Skoda
        "Skoda|Octavia": ["A5", "A7", "A8"],
        "Skoda|Rapid": ["I", "I рестайлинг"],
        "Skoda|Kodiaq": ["I"],

        // Chery / Geely / Haval
        "Haval|F7": ["I", "II"],
        "Geely|Coolray": ["I"],
        "Chery|Tiggo 7": ["I", "Pro"],
        "Chery|Tiggo 8": ["I", "Pro"],
    ]

    static func generations(make: String, model: String) -> [String] {
        let mk = canonicalMake(make) ?? make
        return generationsByMakeModel["\(mk)|\(model)"] ?? []
    }

    /// Engine suggestions for make+model+generation.
    /// Key format: "<make>|<model>|<generation>" or "<make>|<model>|" (no generation).
    static let enginesByMakeModelGeneration: [String: [String]] = [
        // Лада
        "Лада|Гранта|": ["1.6 8V (87/90 л.с.)", "1.6 16V (98/106 л.с.)"],
        "Лада|Веста|": ["1.6 (106 л.с.)", "1.8 (122 л.с.)", "1.6 16V (113 л.с.)"],
        "Лада|Ларгус|": ["1.6 8V (87/90 л.с.)", "1.6 16V (102/106 л.с.)"],
        "Лада|Калина|": ["1.4 16V (89 л.с.)", "1.6 8V", "1.6 16V"],
        "Лада|Приора|": ["1.6 16V (98 л.с.)", "1.6 16V (106 л.с.)"],
        "Лада|Нива Legend|": ["1.7 (80–83 л.с.)"],
        "Лада|Нива Travel|": ["1.7 (80 л.с.)"],

        // ВАЗ классика (часто руками)
        "ВАЗ|2101|": ["1.2", "1.3"],
        "ВАЗ|2102|": ["1.2", "1.3"],
        "ВАЗ|2103|": ["1.5"],
        "ВАЗ|2104|": ["1.3", "1.5"],
        "ВАЗ|2105|": ["1.3", "1.5", "1.6"],
        "ВАЗ|2106|": ["1.6"],
        "ВАЗ|2107|": ["1.5", "1.6"],
        "ВАЗ|2108|": ["1.3", "1.5"],
        "ВАЗ|2109|": ["1.3", "1.5"],
        "ВАЗ|21099|": ["1.5"],
        "ВАЗ|2110|": ["1.5 8V", "1.6 8V", "1.6 16V"],
        "ВАЗ|2111|": ["1.5 8V", "1.6 8V", "1.6 16V"],
        "ВАЗ|2112|": ["1.5 16V", "1.6 16V"],
        "ВАЗ|2113|": ["1.5", "1.6"],
        "ВАЗ|2114|": ["1.5", "1.6"],
        "ВАЗ|2115|": ["1.5", "1.6"],
        "ВАЗ|2121 Нива|": ["1.6", "1.7"],

        // УАЗ
        "УАЗ|Патриот|": ["2.7 ZMZ-409 (128–150 л.с.)", "2.3 дизель (Iveco/ЗМЗ)", "2.2 дизель"],
        "УАЗ|Хантер|": ["2.7", "2.2 дизель"],
        "УАЗ|Буханка|": ["2.7"],
        "УАЗ|Пикап|": ["2.7"],
        "УАЗ|Профи|": ["2.7"],

        // ГАЗ
        "ГАЗ|Газель|": ["2.7 УМЗ", "2.9 УМЗ", "2.8 дизель Cummins"],
        "ГАЗ|Соболь|": ["2.7 УМЗ", "2.8 дизель Cummins"],
        "ГАЗ|Волга|": ["2.3 ZMZ-406", "2.4 ZMZ-405"],
        "ГАЗ|Садко|": ["4.4 дизель", "4.1 дизель"],

        // Москвич
        "Москвич|3|": ["1.5T"],
        "Москвич|3e|": ["Электро"],
        "Москвич|6|": ["1.5T"],
    ]

    static func engines(make: String, model: String, generation: String?) -> [String] {
        let mk = canonicalMake(make) ?? make
        let gen = (generation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !gen.isEmpty {
            let k = "\(mk)|\(model)|\(gen)"
            if let v = enginesByMakeModelGeneration[k] { return v }
        }
        return enginesByMakeModelGeneration["\(mk)|\(model)|"] ?? []
    }

    /// Attempts to infer body style from make+model.
    /// Returns a VehicleBodyStyleOption rawValue (e.g. "sedan", "suv") or nil.
    static func inferredBodyStyle(make rawMake: String, model rawModel: String) -> String? {
        let make = canonicalMake(rawMake) ?? rawMake
        let model = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !make.isEmpty, !model.isEmpty else { return nil }

        // Domestic focus
        if isDomestic(make: make) {
            if make == "Лада" {
                switch model {
                case "Гранта", "Веста", "Приора": return VehicleBodyStyleOption.sedan.rawValue
                case "Ларгус": return VehicleBodyStyleOption.wagon.rawValue
                case "Калина": return VehicleBodyStyleOption.hatchback.rawValue
                case "Нива Legend", "Нива Travel": return VehicleBodyStyleOption.suv.rawValue
                default: break
                }
            }
            if make == "ВАЗ" {
                switch model {
                case "2108", "2109", "2112", "2113", "2114": return VehicleBodyStyleOption.hatchback.rawValue
                case "2111": return VehicleBodyStyleOption.wagon.rawValue
                case "2121 Нива", "2131", "2329": return VehicleBodyStyleOption.suv.rawValue
                default:
                    // Most classic VAZ numbers are sedans.
                    if model.hasPrefix("21") || model.hasPrefix("210") { return VehicleBodyStyleOption.sedan.rawValue }
                }
            }
            if make == "УАЗ" {
                switch model {
                case "Патриот", "Хантер", "Пикап": return VehicleBodyStyleOption.suv.rawValue
                case "Буханка", "Профи": return VehicleBodyStyleOption.van.rawValue
                default: break
                }
            }
            if make == "Москвич" {
                switch model {
                case "3", "3e": return VehicleBodyStyleOption.crossover.rawValue
                case "6": return VehicleBodyStyleOption.sedan.rawValue
                default: break
                }
            }
            if make == "ГАЗ" {
                switch model {
                case "Газель", "Соболь": return VehicleBodyStyleOption.van.rawValue
                case "Волга": return VehicleBodyStyleOption.sedan.rawValue
                case "Садко": return VehicleBodyStyleOption.van.rawValue
                default: break
                }
            }
            if make == "КамАЗ" {
                return VehicleBodyStyleOption.van.rawValue
            }
        }

        // Common global heuristics / explicit picks
        if make == "Toyota" {
            switch model {
            case "Camry", "Corolla": return VehicleBodyStyleOption.sedan.rawValue
            case "RAV4", "Land Cruiser": return VehicleBodyStyleOption.suv.rawValue
            default: break
            }
        }
        if make == "Volkswagen" {
            switch model {
            case "Polo", "Passat": return VehicleBodyStyleOption.sedan.rawValue
            case "Tiguan": return VehicleBodyStyleOption.suv.rawValue
            default: break
            }
        }
        if make == "Renault" {
            switch model {
            case "Logan": return VehicleBodyStyleOption.sedan.rawValue
            case "Sandero": return VehicleBodyStyleOption.hatchback.rawValue
            case "Duster", "Kaptur": return VehicleBodyStyleOption.crossover.rawValue
            default: break
            }
        }
        if make == "Hyundai" {
            switch model {
            case "Solaris", "Elantra": return VehicleBodyStyleOption.sedan.rawValue
            case "Tucson", "Santa Fe": return VehicleBodyStyleOption.suv.rawValue
            default: break
            }
        }
        if make == "Kia" {
            switch model {
            case "Rio": return VehicleBodyStyleOption.sedan.rawValue
            case "Ceed": return VehicleBodyStyleOption.hatchback.rawValue
            case "Sportage", "Sorento": return VehicleBodyStyleOption.suv.rawValue
            default: break
            }
        }

        // Keyword fallback
        let lowered = model.lowercased()
        if lowered.contains("suv") || lowered.contains("crossover") { return VehicleBodyStyleOption.suv.rawValue }
        if lowered.contains("wagon") { return VehicleBodyStyleOption.wagon.rawValue }
        if lowered.contains("pickup") { return VehicleBodyStyleOption.pickup.rawValue }

        return nil
    }

    static let iconSymbols: [String] = [
        "car.fill",
        "car",
        "suv.side.front.fill",
        "suv.side.front",
        "bus.fill",
        "bus",
        "truck.pickup.side.fill",
        "truck.pickup.side",
        "car.2.fill"
    ]
}
