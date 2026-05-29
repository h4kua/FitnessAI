#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct AnalyticsView: View {
    @ObservedObject private var viewModel: AnalyticsViewModel

    public init(viewModel: AnalyticsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FitnessSpacing.large) {
                    header

                    FitnessCard(title: "Data Policy") {
                        Text("Analytics is opt-in and designed for aggregate product quality signals only. Health data remains on device unless a future feature introduces explicit cloud sync.")
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }

                    FitnessCard(title: "Current Status") {
                        Text(viewModel.analyticsEnabled ? "Anonymous analytics enabled" : "Anonymous analytics disabled")
                            .foregroundStyle(viewModel.analyticsEnabled ? FitnessTheme.success : FitnessTheme.secondaryText)
                    }

                    FitnessCard(title: "Vision & Core ML Path") {
                        VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                            Text("Camera-based exercise form feedback already follows an on-device Vision path, and the architecture leaves room for a stronger Core ML model later without changing the product story.")
                                .font(FitnessTypography.body)
                                .foregroundStyle(FitnessTheme.secondaryText)

                            HStack(spacing: FitnessSpacing.small) {
                                MetricBadge(systemImage: "eye", text: "Vision")
                                MetricBadge(systemImage: "cpu.fill", text: "Core ML Ready", tint: FitnessTheme.caution)
                            }
                        }
                    }

                    FitnessCard(title: "App Store Readiness") {
                        VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                            Text("The current app direction already reflects several App Store readiness themes: privacy messaging, permission descriptions, on-device processing context, and clear user-facing states.")
                                .font(FitnessTypography.body)
                                .foregroundStyle(FitnessTheme.secondaryText)

                            HStack(spacing: FitnessSpacing.small) {
                                MetricBadge(systemImage: "hand.raised.fill", text: "Privacy Copy")
                                MetricBadge(systemImage: "iphone.gen3", text: "iPhone-first UX", tint: FitnessTheme.success)
                                MetricBadge(systemImage: "shippingbox.fill", text: "Release Path", tint: FitnessTheme.caution)
                            }
                        }
                    }
                }
                .padding(FitnessSpacing.large)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .navigationTitle("Privacy")
            .task {
                guard viewModel.loadState == .idle else {
                    return
                }

                await viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.small) {
            MetricBadge(systemImage: "lock.shield.fill", text: "Privacy, AI, and release")

            Text("Privacy & Analytics")
                .font(FitnessTypography.hero)
                .foregroundStyle(FitnessTheme.primaryText)

            Text("Explain the on-device intelligence story clearly so the app feels trustworthy, modern, and ready for a polished demo.")
                .font(FitnessTypography.body)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
    }
}
