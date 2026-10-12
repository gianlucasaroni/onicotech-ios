import Foundation

enum TaxRegime: String, Codable, CaseIterable, Identifiable {
    case forfettarioStartup5 = "forfettario_startup_5"
    case forfettarioStandard15 = "forfettario_standard_15"
    case ordinario = "ordinario"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .forfettarioStartup5: return "Forfettario 5% (Nuova Attività)"
        case .forfettarioStandard15: return "Forfettario 15% (Ordinario)"
        case .ordinario: return "Regime Ordinario (IRPEF + IVA)"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .forfettarioStartup5: return "5% Start-up"
        case .forfettarioStandard15: return "15% Standard"
        case .ordinario: return "Ordinario"
        }
    }
}

enum PensionType: String, Codable, CaseIterable, Identifiable {
    case inpsCraftsmen = "inps_craftsmen"
    case inpsSeparate = "inps_separate"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .inpsCraftsmen: return "INPS Gestione Artigiani"
        case .inpsSeparate: return "INPS Gestione Separata"
        }
    }
}

struct AtecoDetail: Codable, Identifiable {
    var id: String { code }
    var code: String
    var title: String
    var description: String
    var profitabilityCoeff: Double
    var category: String
}

let beautyAtecoCodes: [AtecoDetail] = [
    AtecoDetail(
        code: "96.22.01",
        title: "Servizi di manicure e pedicure (ATECO 2025)",
        description: "Nuovo codice ISTAT 2025 dedicato: ricostruzione unghie, nail art, semipermanente, pedicure.",
        profitabilityCoeff: 0.67,
        category: "Servizi alla persona"
    ),
    AtecoDetail(
        code: "96.02.03",
        title: "Servizi di manicure e pedicure (ATECO 2007 - Storico)",
        description: "Codice precedente ISTAT 2007/2022, ancora presente nelle partite IVA già avviate.",
        profitabilityCoeff: 0.67,
        category: "Servizi alla persona"
    ),
    AtecoDetail(
        code: "96.02.02",
        title: "Servizi degli istituti di bellezza",
        description: "Trattamenti viso/corpo, trucco, depilazione ed estetica.",
        profitabilityCoeff: 0.67,
        category: "Servizi alla persona"
    ),
    AtecoDetail(
        code: "96.09.09",
        title: "Altre attività di servizi per la persona",
        description: "Lash maker, make-up artist, consulenze beauty freelance.",
        profitabilityCoeff: 0.67,
        category: "Servizi alla persona"
    ),
    AtecoDetail(
        code: "47.75.10",
        title: "Commercio al dettaglio cosmetici",
        description: "Rivendita retail nel salone di olietti, creme e cosmetici.",
        profitabilityCoeff: 0.40,
        category: "Commercio al dettaglio"
    )
]

struct TaxCalculationResult {
    var grossAmountCents: Int
    var netAmountCents: Int
    var profitabilityCoeff: Double
    var forfettarioExpensesCents: Int
    var taxableIncomeCents: Int
    var inpsContributionsCents: Int
    var inpsEffectiveRatePercent: Double
    var taxableAfterInpsCents: Int
    var taxAmountCents: Int
    var taxRatePercent: Double
    var vatAmountCents: Int
    var materialCostCents: Int
    var suggestedPriceCents: Int
    var suggestedPriceRounded5Cents: Int
    var netMarginPercent: Double
    var effectiveTaxBurdenPercent: Double
    
    var formattedGross: String {
        String(format: "€%.2f", Double(grossAmountCents) / 100.0)
    }
    
    var formattedNet: String {
        String(format: "€%.2f", Double(netAmountCents) / 100.0)
    }
    
    var formattedSuggestedRounded: String {
        String(format: "€%.2f", Double(suggestedPriceRounded5Cents) / 100.0)
    }
    
    var formattedInps: String {
        String(format: "€%.2f", Double(inpsContributionsCents) / 100.0)
    }
    
    var formattedTax: String {
        String(format: "€%.2f", Double(taxAmountCents) / 100.0)
    }
    
    var formattedMaterials: String {
        String(format: "€%.2f", Double(materialCostCents) / 100.0)
    }
}

enum TaxEngine {
    static func calculate(
        mode: String, // "net_to_gross" or "gross_to_net"
        amountCents: Int,
        regime: TaxRegime,
        atecoCode: String,
        pension: PensionType,
        hasInpsDiscount35: Bool,
        materialCostPercent: Double
    ) -> TaxCalculationResult {
        let ateco = beautyAtecoCodes.first { $0.code == atecoCode } ?? beautyAtecoCodes[0]
        let coeff = ateco.profitabilityCoeff
        
        var taxRate = 0.05
        switch regime {
        case .forfettarioStartup5: taxRate = 0.05
        case .forfettarioStandard15: taxRate = 0.15
        case .ordinario: taxRate = 0.23
        }
        
        var inpsRate = 0.2607
        if pension == .inpsCraftsmen {
            inpsRate = hasInpsDiscount35 ? (0.24 * 0.65) : 0.24
        }
        
        let materialRatio = max(0, materialCostPercent) / 100.0
        let isOrdinario = regime == .ordinario
        
        var grossCents = 0
        var netCents = 0
        
        if mode == "net_to_gross" {
            let targetNet = Double(amountCents)
            if !isOrdinario {
                let kTaxInps = coeff * (inpsRate + (1.0 - inpsRate) * taxRate)
                var totalDeductionRatio = kTaxInps + materialRatio
                if totalDeductionRatio >= 0.99 { totalDeductionRatio = 0.99 }
                grossCents = Int(round(targetNet / (1.0 - totalDeductionRatio)))
                netCents = amountCents
            } else {
                let expRatio = 0.25
                let irpefRate = taxRate + 0.025
                let factorNetOverNetVat = (1.0 - expRatio) * (1.0 - inpsRate - (1.0 - inpsRate) * irpefRate)
                var factorNetOverGross = (factorNetOverNetVat / 1.22) - materialRatio
                if factorNetOverGross <= 0.10 { factorNetOverGross = 0.10 }
                grossCents = Int(round(targetNet / factorNetOverGross))
                netCents = amountCents
            }
        } else {
            grossCents = amountCents
        }
        
        let grossF = Double(grossCents)
        var vatCents = 0
        var forfettarioExpensesCents = 0
        var taxableIncomeCents = 0
        var inpsCents = 0
        var taxableAfterInpsCents = 0
        var taxCents = 0
        var materialCents = 0
        
        if !isOrdinario {
            vatCents = 0
            forfettarioExpensesCents = Int(round(grossF * (1.0 - coeff)))
            let taxableF = grossF * coeff
            taxableIncomeCents = Int(round(taxableF))
            
            let inpsF = taxableF * inpsRate
            inpsCents = Int(round(inpsF))
            
            let taxableAfterInpsF = max(0, taxableF - inpsF)
            taxableAfterInpsCents = Int(round(taxableAfterInpsF))
            
            let taxF = taxableAfterInpsF * taxRate
            taxCents = Int(round(taxF))
            
            let materialF = grossF * materialRatio
            materialCents = Int(round(materialF))
            
            if mode != "net_to_gross" {
                let netF = max(0, grossF - inpsF - taxF - materialF)
                netCents = Int(round(netF))
            }
        } else {
            let netVatGross = grossF / 1.22
            vatCents = Int(round(grossF - netVatGross))
            
            let expRatio = 0.25
            forfettarioExpensesCents = Int(round(netVatGross * expRatio))
            
            let taxableF = max(0, netVatGross - (netVatGross * expRatio))
            taxableIncomeCents = Int(round(taxableF))
            
            let inpsF = taxableF * inpsRate
            inpsCents = Int(round(inpsF))
            
            let taxableAfterInpsF = max(0, taxableF - inpsF)
            taxableAfterInpsCents = Int(round(taxableAfterInpsF))
            
            let irpefRate = taxRate + 0.025
            taxCents = Int(round(taxableAfterInpsF * irpefRate))
            
            materialCents = Int(round(grossF * materialRatio))
            
            if mode != "net_to_gross" {
                let netF = max(0, grossF - Double(vatCents) - inpsF - Double(taxCents) - Double(materialCents))
                netCents = Int(round(netF))
            }
        }
        
        var netMarginPct = 0.0
        var effectiveBurdenPct = 0.0
        if grossCents > 0 {
            netMarginPct = round((Double(netCents) / Double(grossCents)) * 10000) / 100
            effectiveBurdenPct = round((Double(inpsCents + taxCents + vatCents) / Double(grossCents)) * 10000) / 100
        }
        
        var suggestedRounded5 = grossCents
        if grossCents % 500 != 0 {
            suggestedRounded5 = ((grossCents / 500) + 1) * 500
        }
        
        return TaxCalculationResult(
            grossAmountCents: grossCents,
            netAmountCents: netCents,
            profitabilityCoeff: coeff,
            forfettarioExpensesCents: forfettarioExpensesCents,
            taxableIncomeCents: taxableIncomeCents,
            inpsContributionsCents: inpsCents,
            inpsEffectiveRatePercent: round(inpsRate * 10000) / 100,
            taxableAfterInpsCents: taxableAfterInpsCents,
            taxAmountCents: taxCents,
            taxRatePercent: round(taxRate * 10000) / 100,
            vatAmountCents: vatCents,
            materialCostCents: materialCents,
            suggestedPriceCents: grossCents,
            suggestedPriceRounded5Cents: suggestedRounded5,
            netMarginPercent: netMarginPct,
            effectiveTaxBurdenPercent: effectiveBurdenPct
        )
    }
}
