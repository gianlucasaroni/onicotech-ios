import SwiftUI

struct TaxCalculatorView: View {
    @State private var calculationMode: String = "net_to_gross" // "net_to_gross" | "gross_to_net"
    @State private var amountString: String = "100"
    
    @State private var selectedRegime: TaxRegime = .forfettarioStartup5
    @State private var selectedAteco: String = "96.02.03"
    @State private var selectedPension: PensionType = .inpsCraftsmen
    @State private var hasInpsDiscount35: Bool = true
    @State private var materialCostPercent: Double = 10.0
    
    private var amountCents: Int {
        let clean = amountString.replacingOccurrences(of: ",", with: ".")
        let euros = Double(clean) ?? 0.0
        return Int(round(euros * 100))
    }
    
    private var result: TaxCalculationResult {
        TaxEngine.calculate(
            mode: calculationMode,
            amountCents: max(0, amountCents),
            regime: selectedRegime,
            atecoCode: selectedAteco,
            pension: selectedPension,
            hasInpsDiscount35: hasInpsDiscount35,
            materialCostPercent: materialCostPercent
        )
    }
    
    private var scenario5: TaxCalculationResult {
        TaxEngine.calculate(
            mode: calculationMode,
            amountCents: max(0, amountCents),
            regime: .forfettarioStartup5,
            atecoCode: selectedAteco,
            pension: selectedPension,
            hasInpsDiscount35: hasInpsDiscount35,
            materialCostPercent: materialCostPercent
        )
    }
    
    private var scenario15: TaxCalculationResult {
        TaxEngine.calculate(
            mode: calculationMode,
            amountCents: max(0, amountCents),
            regime: .forfettarioStandard15,
            atecoCode: selectedAteco,
            pension: selectedPension,
            hasInpsDiscount35: hasInpsDiscount35,
            materialCostPercent: materialCostPercent
        )
    }
    
    var body: some View {
        Form {
            // Mode Segmented Picker
            Section {
                Picker("Modalità Calcolo", selection: $calculationMode) {
                    Text("🎯 Netto ➔ Prezzo").tag("net_to_gross")
                    Text("📊 Prezzo ➔ Netto").tag("gross_to_net")
                }
                .pickerStyle(.segmented)
            } footer: {
                if calculationMode == "net_to_gross" {
                    Text("Inserisci il netto desiderato in tasca per scoprire quanto chiedere alla cliente a listino.")
                } else {
                    Text("Inserisci il prezzo lordo incassato per calcolare quanto ti resta pulito dopo tasse e INPS.")
                }
            }
            
            // Amount Input & Presets
            Section(calculationMode == "net_to_gross" ? "Netto Desiderato in Tasca" : "Prezzo Trattamento / Incasso") {
                HStack {
                    Text("€")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.purple)
                    TextField("Importo", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .bold()
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([35, 50, 70, 100, 120, 150], id: \.self) { val in
                            Button("\(val) €") {
                                amountString = "\(val)"
                            }
                            .buttonStyle(.bordered)
                            .tint(amountString == "\(val)" ? .purple : .gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Hero Result Section
            Section {
                VStack(spacing: 12) {
                    Text(calculationMode == "net_to_gross" ? "PREZZO CONSIGLIATO DA CHIEDERE" : "GUADAGNO NETTO EFFETTIVO")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.secondary)
                    
                    Text(calculationMode == "net_to_gross" ? result.formattedSuggestedRounded : result.formattedNet)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(calculationMode == "net_to_gross" ? .purple : .green)
                    
                    if calculationMode == "net_to_gross" {
                        Text("Prezzo esatto: \(result.formattedGross) • Arrotondato a listino: \(result.formattedSuggestedRounded)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Chiedendo \(result.formattedSuggestedRounded), dopo imposta (\(Int(result.taxRatePercent))%) e INPS (\(String(format: "%.1f", result.inpsEffectiveRatePercent))%) ti rimarranno esattamente \(result.formattedNet) netti puliti.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.top, 4)
                    } else {
                        Text("Margine Netto: \(String(format: "%.1f", result.netMarginPercent))% • Prelievo Totale: \(String(format: "%.1f", result.effectiveTaxBurdenPercent))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Breakdown Metrics
            Section("Dettaglio Quote") {
                LabeledContent("Guadagno Netto in Tasca", value: result.formattedNet)
                LabeledContent("Previdenza INPS (\(String(format: "%.1f", result.inpsEffectiveRatePercent))%)", value: "- \(result.formattedInps)")
                LabeledContent("Imposta Sostitutiva (\(Int(result.taxRatePercent))%)", value: "- \(result.formattedTax)")
                if result.materialCostCents > 0 {
                    LabeledContent("Stima Costo Materiali (\(Int(materialCostPercent))%)", value: "- \(result.formattedMaterials)")
                }
            }
            
            // Tax Configuration
            Section("Inquadramento Fiscale Salone") {
                Picker("Regime Fiscale", selection: $selectedRegime) {
                    ForEach(TaxRegime.allCases) { regime in
                        Text(regime.title).tag(regime)
                    }
                }
                
                Picker("Codice ATECO", selection: $selectedAteco) {
                    ForEach(beautyAtecoCodes) { ateco in
                        Text("\(ateco.code) - \(ateco.title) (\(Int(ateco.profitabilityCoeff * 100))%)").tag(ateco.code)
                    }
                }
                
                Picker("Cassa INPS", selection: $selectedPension) {
                    ForEach(PensionType.allCases) { pension in
                        Text(pension.title).tag(pension)
                    }
                }
                
                if selectedPension == .inpsCraftsmen && selectedRegime != .ordinario {
                    Toggle("Riduzione 35% Contributi Artigiani", isOn: $hasInpsDiscount35)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Costi Materiali Cabina")
                        Spacer()
                        Text("\(Int(materialCostPercent))%")
                            .foregroundColor(.purple)
                            .bold()
                    }
                    Slider(value: $materialCostPercent, in: 0...35, step: 5)
                }
            }
            
            // Comparison Scenarios
            Section("Confronto Rapido tra Regimi") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Forfettario 5%")
                            .font(.headline)
                        Text(calculationMode == "net_to_gross" ? "Chiedi: \(scenario5.formattedSuggestedRounded)" : "Netto: \(scenario5.formattedNet)")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Forfettario 15%")
                            .font(.headline)
                        Text(calculationMode == "net_to_gross" ? "Chiedi: \(scenario15.formattedSuggestedRounded)" : "Netto: \(scenario15.formattedNet)")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                }
            }
            
            // Notes
            Section("Normativa") {
                Text("• Regime Forfettario: esente da IVA e ritenuta d'acconto (L. 190/2014). Limite ricavi annuo: 85.000 €.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("• ATECO 96.02.03: il 67% dei ricavi è imponibile; il 33% è riconosciuto forfettariamente come spesa senza giustificativi.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Calcolatore Fiscale")
    }
}

#Preview {
    NavigationStack {
        TaxCalculatorView()
    }
}
