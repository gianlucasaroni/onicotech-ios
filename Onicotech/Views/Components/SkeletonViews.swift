import SwiftUI

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Primitives

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Dashboard Skeleton

struct DashboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonRect(width: 180, height: 14)
                    SkeletonRect(width: 220, height: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Stat cards
                HStack(spacing: 16) {
                    StatCardSkeleton()
                    StatCardSkeleton()
                }
                .padding(.horizontal)
                
                // Banner
                SkeletonRect(height: 70, cornerRadius: 16)
                    .padding(.horizontal)
                
                // Next appointments header
                SkeletonRect(width: 200, height: 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Appointment rows
                ForEach(0..<3, id: \.self) { _ in
                    AppointmentRowSkeleton()
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct StatCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SkeletonCircle(size: 20)
                SkeletonRect(width: 60, height: 14)
                Spacer()
            }
            SkeletonRect(width: 80, height: 28)
            SkeletonRect(width: 100, height: 12)
        }
        .padding(12)
        .background(Color.systemBackgroundCompat)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Appointment List Skeleton

struct AppointmentListSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                AppointmentRowSkeleton()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

struct AppointmentRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SkeletonRect(width: 110, height: 18)
                Spacer()
                SkeletonRect(width: 80, height: 22, cornerRadius: 12)
            }
            SkeletonRect(width: 150, height: 14)
            SkeletonRect(width: 200, height: 13)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client List Skeleton

struct ClientListSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                ClientRowSkeleton()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

struct ClientRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonRect(width: 160, height: 18)
            HStack(spacing: 6) {
                SkeletonCircle(size: 14)
                SkeletonRect(width: 120, height: 14)
            }
            HStack(spacing: 6) {
                SkeletonCircle(size: 14)
                SkeletonRect(width: 180, height: 14)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Service List Skeleton

struct ServiceListSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                ServiceRowSkeleton()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

struct ServiceRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonRect(width: 140, height: 18)
                    SkeletonRect(width: 200, height: 12)
                }
                Spacer()
                SkeletonCircle(size: 28)
            }
            HStack {
                SkeletonRect(width: 80, height: 22, cornerRadius: 12)
                Spacer()
                SkeletonRect(width: 60, height: 16)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Statistics Skeleton

struct StatisticsSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chart card
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonRect(width: 220, height: 18)
                    SkeletonRect(height: 200, cornerRadius: 12)
                }
                .padding()
                .background(Color.secondaryGroupedBackgroundCompat)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // Pie chart
                VStack(alignment: .leading, spacing: 16) {
                    SkeletonRect(width: 120, height: 18)
                    SkeletonCircle(size: 200)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.secondaryGroupedBackgroundCompat)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // Top list
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonRect(width: 140, height: 18)
                        .padding(.horizontal)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            SkeletonRect(width: 130, height: 16)
                            Spacer()
                            SkeletonRect(width: 60, height: 16)
                        }
                        .padding()
                        .background(Color.secondaryGroupedBackgroundCompat)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Previews

#Preview("Dashboard Skeleton") {
    DashboardSkeletonView()
}

#Preview("Appointment Skeleton") {
    AppointmentListSkeletonView()
}

#Preview("Client Skeleton") {
    ClientListSkeletonView()
}

#Preview("Service Skeleton") {
    ServiceListSkeletonView()
}

#Preview("Statistics Skeleton") {
    StatisticsSkeletonView()
}
