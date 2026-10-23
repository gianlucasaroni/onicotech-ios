import SwiftUI

struct CuringTimerView: View {
    @ObservedObject var timerManager = CuringTimerManager.shared
    
    let presets = [30, 60, 90, 120]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Circular Timer Gauge
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: timerManager.isRunning || timerManager.remainingSeconds > 0 ? timerManager.progress : 1.0)
                        .stroke(
                            Color.purple,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timerManager.progress)
                        .frame(width: 100, height: 100)
                    
                    VStack(spacing: 2) {
                        Text(timerManager.isRunning || timerManager.remainingSeconds > 0 ? timerManager.formattedRemainingTime : "\(timerManager.totalSeconds)s")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .monospacedDigit()
                        
                        Text(timerManager.isRunning ? "Polimerizzazione" : "Timer Lampada")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
                
                // Controls
                if timerManager.isRunning {
                    HStack(spacing: 12) {
                        Button(action: { timerManager.pause() }) {
                            Image(systemName: "pause.fill")
                                .font(.body)
                        }
                        .tint(.orange)
                        
                        Button(action: { timerManager.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.body)
                        }
                        .tint(.red)
                    }
                } else if timerManager.remainingSeconds > 0 {
                    HStack(spacing: 12) {
                        Button(action: { timerManager.resume() }) {
                            Image(systemName: "play.fill")
                                .font(.body)
                        }
                        .tint(.green)
                        
                        Button(action: { timerManager.stop() }) {
                            Image(systemName: "xmark")
                                .font(.body)
                        }
                        .tint(.gray)
                    }
                }
                
                // Preset Buttons
                Text("PRESET RAPIDI")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(presets, id: \.self) { seconds in
                        Button(action: {
                            timerManager.start(seconds: seconds)
                        }) {
                            Text("\(seconds)s")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .tint(timerManager.totalSeconds == seconds && (timerManager.isRunning || timerManager.remainingSeconds > 0) ? .purple : .white.opacity(0.15))
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Timer UV")
    }
}
