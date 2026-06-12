import AVKit
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

// MARK: - Data Models

struct TutorialCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let accentColor: Color
    let exercises: [TutorialExercise]

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TutorialExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let equipmentLabel: String
    let baseFilename: String

    func videoURL(side: Bool) -> URL? {
        let suffix = side ? "-side" : "-front"
        return Bundle.main.bundleURL
            .appendingPathComponent("DataVideo")
            .appendingPathComponent(category)
            .appendingPathComponent("\(baseFilename)\(suffix).mp4")
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Exercise Data

private extension TutorialCategory {
    static let all: [TutorialCategory] = [jumpingJack, pushUp, pullUp, sitUp]

    static let jumpingJack = TutorialCategory(
        id: "JumpingJack", name: "Jumping Jack",
        systemImage: "figure.jumprope", accentColor: FitnessTheme.energy,
        exercises: [
            TutorialExercise(id: "jj-crisscross", name: "Criss-Cross Jacks",       category: "JumpingJack", equipmentLabel: "Cardio",        baseFilename: "male-Cardio-cardio-criss-cross-jacks"),
            TutorialExercise(id: "jj-jumping",    name: "Jumping Jacks",            category: "JumpingJack", equipmentLabel: "Cardio",        baseFilename: "male-Cardio-cardio-jumping-jacks"),
            TutorialExercise(id: "jj-pressjack",  name: "Medicine Ball Press Jack", category: "JumpingJack", equipmentLabel: "Medicine Ball", baseFilename: "male-Medicine-Ball-press-jack"),
        ]
    )

    static let pushUp = TutorialCategory(
        id: "PushUp", name: "Push Up",
        systemImage: "figure.strengthtraining.traditional", accentColor: FitnessTheme.strength,
        exercises: [
            TutorialExercise(id: "pu-basic",    name: "Push-Up",                   category: "PushUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-push-up"),
            TutorialExercise(id: "pu-decline",  name: "Decline Push-Up",           category: "PushUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-decline-push-up"),
            TutorialExercise(id: "pu-diamond",  name: "Diamond Push-Ups",          category: "PushUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-diamond-push-ups"),
            TutorialExercise(id: "pu-incline",  name: "Incline Push-Up",           category: "PushUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-incline-push-up"),
            TutorialExercise(id: "pu-wdiamond", name: "Weighted Diamond Push-Ups", category: "PushUp", equipmentLabel: "Plate",      baseFilename: "male-Plate-weighted-diamond-push-ups"),
            TutorialExercise(id: "pu-weighted", name: "Weighted Push-Ups",         category: "PushUp", equipmentLabel: "Plate",      baseFilename: "male-Plate-weighted-push-ups"),
        ]
    )

    static let pullUp = TutorialCategory(
        id: "PullUp", name: "Pull Up",
        systemImage: "figure.pull.up", accentColor: FitnessTheme.purple,
        exercises: [
            TutorialExercise(id: "plup-basic",       name: "Pull-Up",                         category: "PullUp", equipmentLabel: "Bodyweight", baseFilename: "male-bodyweight-pullup"),
            TutorialExercise(id: "plup-assisted",    name: "Assisted Pull-Up",                category: "PullUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-bodyweight-assisted-pull-up"),
            TutorialExercise(id: "plup-lsit",        name: "L-Sit Pull-Up",                   category: "PullUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-l-sit-pull-up"),
            TutorialExercise(id: "plup-ring",        name: "Ring Pull-Up",                    category: "PullUp", equipmentLabel: "Bodyweight", baseFilename: "male-Bodyweight-ring-pull-up"),
            TutorialExercise(id: "plup-dumbbell",    name: "Dumbbell Weighted Pull-Ups",      category: "PullUp", equipmentLabel: "Dumbbells",  baseFilename: "male-Dumbbells-dumbbell-weighted-pull-ups"),
            TutorialExercise(id: "plup-mach-narrow", name: "Machine Assisted Narrow Pull-Up", category: "PullUp", equipmentLabel: "Machine",    baseFilename: "male-Machine-machine-assisted-narrow-pull-up"),
            TutorialExercise(id: "plup-machine",     name: "Machine Assisted Pull-Up",        category: "PullUp", equipmentLabel: "Machine",    baseFilename: "male-Machine-machine-assisted-pull-up"),
            TutorialExercise(id: "plup-plate",       name: "Weighted Pull-Ups",               category: "PullUp", equipmentLabel: "Plate",      baseFilename: "male-Plate-weighted-pull-ups"),
        ]
    )

    static let sitUp = TutorialCategory(
        id: "SitUp", name: "Sit Up",
        systemImage: "figure.core.training", accentColor: FitnessTheme.accent,
        exercises: [
            TutorialExercise(id: "su-basic",    name: "Sit-Up",               category: "SitUp", equipmentLabel: "Bodyweight",   baseFilename: "male-Bodyweight-situp"),
            TutorialExercise(id: "su-barbell",  name: "Barbell Sit-Up",       category: "SitUp", equipmentLabel: "Barbell",      baseFilename: "male-Barbell-barbell-situp"),
            TutorialExercise(id: "su-dumbbell", name: "Dumbbell Sit-Up",      category: "SitUp", equipmentLabel: "Dumbbells",    baseFilename: "male-Dumbbells-dumbbell-situp"),
            TutorialExercise(id: "su-kettle",   name: "Kettlebell Sit-Up",    category: "SitUp", equipmentLabel: "Kettlebell",   baseFilename: "male-Kettlebells-kettlebell-situp"),
            TutorialExercise(id: "su-plate",    name: "Plate Sit-Up",         category: "SitUp", equipmentLabel: "Plate",        baseFilename: "male-plate-situp"),
            TutorialExercise(id: "su-smith",    name: "Smith Machine Sit-Up", category: "SitUp", equipmentLabel: "Smith Machine", baseFilename: "male-Smithmachine-situp"),
        ]
    )
}

// MARK: - Main Tutorial View

public struct ExerciseTutorialView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    heroBanner
                    categoryGrid
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(for: TutorialCategory.self) { category in
                TutorialCategoryListView(category: category)
            }
            .navigationDestination(for: TutorialExercise.self) { exercise in
                TutorialVideoPlayerView(exercise: exercise)
            }
        }
    }

    private var heroBanner: some View {
        GradientCard(gradient: FitnessTheme.strengthGradient) {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                Label("EXERCISE TUTORIALS", systemImage: "play.circle.fill")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(.black.opacity(0.60))
                    .tracking(1)
                Text("Teknik Latihan\nyang Benar")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.90))
                let totalVideos = TutorialCategory.all.reduce(0) { $0 + $1.exercises.count * 2 }
                Text("\(totalVideos) video · \(TutorialCategory.all.count) kategori")
                    .font(FitnessTypography.caption)
                    .foregroundStyle(.black.opacity(0.60))
            }
        }
        .padding(.top, FitnessSpacing.medium)
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: FitnessSpacing.medium
        ) {
            ForEach(TutorialCategory.all) { category in
                NavigationLink(value: category) {
                    categoryCard(category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryCard(_ category: TutorialCategory) -> some View {
        VStack(spacing: FitnessSpacing.small) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(category.accentColor.opacity(0.18))
                    .frame(height: 80)
                Image(systemName: category.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(category.accentColor)
            }
            VStack(spacing: 2) {
                Text(category.name)
                    .font(FitnessTypography.subtitle)
                    .foregroundStyle(FitnessTheme.primaryText)
                Text("\(category.exercises.count) variasi")
                    .font(FitnessTypography.caption)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
            .padding(.bottom, FitnessSpacing.small)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
                )
        )
        .shadow(color: FitnessTheme.shadow.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Category Exercise List

struct TutorialCategoryListView: View {
    let category: TutorialCategory

    var body: some View {
        ScrollView {
            VStack(spacing: FitnessSpacing.small) {
                ForEach(category.exercises) { exercise in
                    NavigationLink(value: exercise) {
                        exerciseRow(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.vertical, FitnessSpacing.medium)
        }
        .background(FitnessTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func exerciseRow(_ exercise: TutorialExercise) -> some View {
        HStack(spacing: FitnessSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(category.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: category.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(category.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(FitnessTypography.subtitle)
                    .foregroundStyle(FitnessTheme.primaryText)
                    .multilineTextAlignment(.leading)
                Text(exercise.equipmentLabel)
                    .font(FitnessTypography.caption)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(category.accentColor)
        }
        .padding(FitnessSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - Video Player

struct TutorialVideoPlayerView: View {
    let exercise: TutorialExercise
    @State private var showSide = false
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            videoArea
            detailPanel
        }
        .background(FitnessTheme.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadPlayer() }
        .onDisappear { player?.pause() }
        .onChange(of: showSide) { _ in loadPlayer() }
    }

    @ViewBuilder
    private var videoArea: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else {
                VStack(spacing: FitnessSpacing.medium) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(FitnessTheme.tertiaryText)
                    Text("Video tidak tersedia")
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var detailPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FitnessSpacing.large) {
                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text(exercise.name)
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    Label(exercise.equipmentLabel, systemImage: "dumbbell.fill")
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }

                Picker("Sudut Kamera", selection: $showSide) {
                    Text("Tampak Depan").tag(false)
                    Text("Tampak Samping").tag(true)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                    Label("Tips", systemImage: "lightbulb.fill")
                        .font(FitnessTypography.cardTitle)
                        .foregroundStyle(FitnessTheme.caution)
                    Text("Perhatikan posisi tubuh dari tampak depan dan samping untuk memastikan teknik gerakan yang benar dan aman.")
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
                .padding(FitnessSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FitnessTheme.caution.opacity(0.08))
                )
            }
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.top, FitnessSpacing.medium)
            .padding(.bottom, FitnessSpacing.xLarge)
        }
    }

    private func loadPlayer() {
        player?.pause()
        player = nil
        guard let url = exercise.videoURL(side: showSide),
              FileManager.default.fileExists(atPath: url.path) else { return }
        let newPlayer = AVPlayer(url: url)
        newPlayer.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        player = newPlayer
        newPlayer.play()
    }
}
