#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct CoachChatView: View {
    @ObservedObject private var viewModel: CoachChatViewModel
    @FocusState private var isInputFocused: Bool

    public init(viewModel: CoachChatViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: FitnessSpacing.small) {
                        // AI avatar in toolbar
                        ZStack {
                            Circle()
                                .fill(FitnessTheme.accentGradient)
                                .frame(width: 32, height: 32)
                            Image(systemName: "brain")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Coach")
                                .font(FitnessTypography.subtitle)
                                .foregroundStyle(FitnessTheme.primaryText)
                            Text("Llama 3.3 · Groq")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(FitnessTheme.accent)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearHistory()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                    .disabled(viewModel.messages.count <= 1)
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    if viewModel.isThinking {
                        thinkingIndicator.id("thinking")
                    }
                }
                .padding(.horizontal, FitnessSpacing.medium)
                .padding(.top, FitnessSpacing.medium)
                .padding(.bottom, FitnessSpacing.small)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isThinking) { thinking in
                if thinking {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: FitnessSpacing.small) {
            if message.role == .user {
                Spacer(minLength: 50)

                Text(message.content)
                    .font(FitnessTypography.body)
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, FitnessSpacing.medium)
                    .padding(.vertical, FitnessSpacing.small + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(FitnessTheme.accentGradient)
                    )
                    .shadow(color: FitnessTheme.accent.opacity(0.25), radius: 4)

            } else {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(FitnessTheme.accentGradient)
                        .frame(width: 30, height: 30)
                    Image(systemName: "brain")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                }

                Text(LocalizedStringKey(message.content))
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.primaryText)
                    .padding(.horizontal, FitnessSpacing.medium)
                    .padding(.vertical, FitnessSpacing.small + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(FitnessTheme.surface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
                            )
                    )

                Spacer(minLength: 50)
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(alignment: .bottom, spacing: FitnessSpacing.small) {
            ZStack {
                Circle()
                    .fill(FitnessTheme.accentGradient)
                    .frame(width: 30, height: 30)
                Image(systemName: "brain")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(FitnessTheme.accent.opacity(0.70))
                        .frame(width: 7, height: 7)
                        .scaleEffect(viewModel.isThinking ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: viewModel.isThinking
                        )
                }
            }
            .padding(.horizontal, FitnessSpacing.medium)
            .padding(.vertical, FitnessSpacing.small + 2)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(FitnessTheme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
                    )
            )

            Spacer(minLength: 50)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: FitnessSpacing.small) {
            TextField("Ask your AI coach…", text: $viewModel.inputText, axis: .vertical)
                .font(FitnessTypography.body)
                .foregroundStyle(FitnessTheme.primaryText)
                .tint(FitnessTheme.accent)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, FitnessSpacing.medium)
                .padding(.vertical, FitnessSpacing.small + 2)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(FitnessTheme.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    isInputFocused ? FitnessTheme.accent.opacity(0.40) : FitnessTheme.surfaceStroke,
                                    lineWidth: 1.5
                                )
                        )
                )
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.send() } }

            Button {
                Task { await viewModel.send() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? FitnessTheme.accentGradient : LinearGradient(colors: [FitnessTheme.surface2], startPoint: .top, endPoint: .bottom))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? Color.black : FitnessTheme.secondaryText)
                }
            }
            .disabled(!canSend)
            .animation(.easeOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, FitnessSpacing.medium)
        .padding(.vertical, FitnessSpacing.small)
        .background(
            Rectangle()
                .fill(FitnessTheme.surface.opacity(0.95))
                .shadow(color: FitnessTheme.shadow.opacity(0.50), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !viewModel.isThinking
    }
}
