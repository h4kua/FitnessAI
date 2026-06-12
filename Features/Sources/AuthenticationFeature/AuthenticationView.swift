#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct AuthenticationView: View {
    @ObservedObject private var viewModel: AuthenticationViewModel
    @FocusState private var focused: Field?
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorPresses: Int = 0

    private enum Field: Hashable {
        case name, email, password, confirmPassword
        case resetEmail
        case phoneNumber
        case otp
    }

    public init(viewModel: AuthenticationViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            FitnessTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch viewModel.authMode {
                    case .signIn, .register:
                        standardAuthContent
                    case .forgotPassword:
                        forgotPasswordContent
                    case .phoneNumber:
                        phoneNumberContent
                    case .phoneOTP(let verificationID):
                        phoneOTPContent(verificationID: verificationID)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: viewModel.authMode)
        .onTapGesture { focused = nil }
        .onChange(of: viewModel.errorMessage) { _ in
            guard viewModel.errorMessage != nil else { return }
            withAnimation(.default) { errorPresses += 1 }
        }
    }

    // MARK: - Standard Sign-In / Register Screen

    private var standardAuthContent: some View {
        VStack(spacing: 0) {
            header(
                subtitle: viewModel.authMode == .signIn
                    ? "Welcome back! Sign in to continue."
                    : "Create your account and start training."
            )
            .padding(.top, 60)
            .padding(.bottom, FitnessSpacing.xLarge)

            modePicker
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.large)

            standardFormCard
                .padding(.horizontal, FitnessSpacing.large)

            if let msg = viewModel.errorMessage {
                errorBanner(msg)
                    .padding(.horizontal, FitnessSpacing.large)
                    .padding(.top, FitnessSpacing.medium)
                    .modifier(ShakeEffect(presses: errorPresses))

                // Smart actions below the error
                if viewModel.isEmailAlreadyInUse {
                    emailAlreadyInUseActions
                        .padding(.horizontal, FitnessSpacing.large)
                        .padding(.top, FitnessSpacing.small)
                }
            }

            ctaButton
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.top, FitnessSpacing.large)

            divider
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.vertical, FitnessSpacing.medium)

            googleButton
                .padding(.horizontal, FitnessSpacing.large)

            phoneButton
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.top, FitnessSpacing.small)

            switchModeButton
                .padding(.top, FitnessSpacing.large)

            skipButton
                .padding(.top, FitnessSpacing.small)
                .padding(.bottom, FitnessSpacing.xxLarge)
        }
    }

    // MARK: - Forgot Password Screen

    private var forgotPasswordContent: some View {
        VStack(spacing: 0) {
            backButton
                .padding(.top, 60)
                .padding(.horizontal, FitnessSpacing.large)

            header(subtitle: "Enter your email and we'll send you a password reset link.")
                .padding(.top, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)

            // Email input card
            VStack(spacing: FitnessSpacing.medium) {
                inputField(
                    icon: "envelope.fill",
                    placeholder: "Registered email address",
                    text: $viewModel.resetEmail,
                    field: .resetEmail,
                    keyboard: .emailAddress
                )
            }
            .padding(FitnessSpacing.large)
            .background(FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, FitnessSpacing.large)

            if let msg = viewModel.errorMessage {
                errorBanner(msg)
                    .padding(.horizontal, FitnessSpacing.large)
                    .padding(.top, FitnessSpacing.medium)
                    .modifier(ShakeEffect(presses: errorPresses))
            }

            if let success = viewModel.forgotPasswordSuccess {
                successBanner(success)
                    .padding(.horizontal, FitnessSpacing.large)
                    .padding(.top, FitnessSpacing.medium)
            }

            // Send Reset Link button
            Button {
                focused = nil
                Task { await viewModel.sendPasswordReset() }
            } label: {
                Group {
                    if viewModel.loadState == .loading {
                        ProgressView().tint(.black)
                    } else {
                        Label("Send Reset Link", systemImage: "envelope.badge.fill")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.loadState == .loading || !viewModel.isForgotPasswordFormValid || viewModel.forgotPasswordSuccess != nil)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.top, FitnessSpacing.large)

            // If success, show "Back to Sign In" button
            if viewModel.forgotPasswordSuccess != nil {
                Button {
                    viewModel.switchToSignIn()
                } label: {
                    Text("Back to Sign In")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.accent)
                        .fontWeight(.semibold)
                }
                .padding(.top, FitnessSpacing.medium)
            }

            Spacer().frame(height: FitnessSpacing.xxLarge)
        }
    }

    // MARK: - Phone Number Screen

    private var phoneNumberContent: some View {
        VStack(spacing: 0) {
            backButton
                .padding(.top, 60)
                .padding(.horizontal, FitnessSpacing.large)

            header(subtitle: "Enter your phone number to receive a 6-digit verification code.")
                .padding(.top, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)

            VStack(spacing: FitnessSpacing.medium) {
                // Phone number with +XX prefix
                HStack(spacing: FitnessSpacing.medium) {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(FitnessTheme.accent)
                        .frame(width: 20)
                    TextField("+1 234 567 8900", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .foregroundStyle(FitnessTheme.primaryText)
                        .focused($focused, equals: .phoneNumber)
                }
                .padding(FitnessSpacing.medium)
                .background(FitnessTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focused == .phoneNumber ? FitnessTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )

                Text("Include your country code, e.g. +62 for Indonesia or +1 for USA.")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(FitnessTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(FitnessSpacing.large)
            .background(FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, FitnessSpacing.large)

            if let msg = viewModel.errorMessage {
                errorBanner(msg)
                    .padding(.horizontal, FitnessSpacing.large)
                    .padding(.top, FitnessSpacing.medium)
                    .modifier(ShakeEffect(presses: errorPresses))
            }

            Button {
                focused = nil
                Task { await viewModel.verifyPhoneNumber() }
            } label: {
                Group {
                    if viewModel.loadState == .loading {
                        ProgressView().tint(.black)
                    } else {
                        Label("Send Code", systemImage: "arrow.right.circle.fill")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.loadState == .loading || !viewModel.isPhoneFormValid)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.top, FitnessSpacing.large)

            Spacer().frame(height: FitnessSpacing.xxLarge)
        }
    }

    // MARK: - Phone OTP Screen

    private func phoneOTPContent(verificationID: String) -> some View {
        VStack(spacing: 0) {
            backButton
                .padding(.top, 60)
                .padding(.horizontal, FitnessSpacing.large)

            header(subtitle: "Enter the 6-digit code we sent to \(viewModel.phoneNumber).")
                .padding(.top, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)

            VStack(spacing: FitnessSpacing.medium) {
                HStack(spacing: FitnessSpacing.medium) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(FitnessTheme.accent)
                        .frame(width: 20)
                    TextField("123456", text: $viewModel.otp)
                        .keyboardType(.numberPad)
                        .foregroundStyle(FitnessTheme.primaryText)
                        .focused($focused, equals: .otp)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .onChange(of: viewModel.otp) { val in
                            // Clamp to 6 digits
                            if val.count > 6 {
                                viewModel.otp = String(val.prefix(6))
                            }
                        }
                }
                .padding(FitnessSpacing.medium)
                .background(FitnessTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focused == .otp ? FitnessTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
            }
            .padding(FitnessSpacing.large)
            .background(FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, FitnessSpacing.large)

            if let msg = viewModel.errorMessage {
                errorBanner(msg)
                    .padding(.horizontal, FitnessSpacing.large)
                    .padding(.top, FitnessSpacing.medium)
                    .modifier(ShakeEffect(presses: errorPresses))
            }

            Button {
                focused = nil
                Task { await viewModel.signInWithPhone(verificationID: verificationID) }
            } label: {
                Group {
                    if viewModel.loadState == .loading {
                        ProgressView().tint(.black)
                    } else {
                        Label("Verify & Sign In", systemImage: "checkmark.shield.fill")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.loadState == .loading || !viewModel.isOTPFormValid)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.top, FitnessSpacing.large)

            // Resend code link
            Button {
                viewModel.goBack()
            } label: {
                Text("Didn't receive a code? ") +
                Text("Go back").foregroundColor(FitnessTheme.accent).bold()
            }
            .font(FitnessTypography.caption)
            .foregroundStyle(FitnessTheme.secondaryText)
            .padding(.top, FitnessSpacing.medium)

            Spacer().frame(height: FitnessSpacing.xxLarge)
        }
    }

    // MARK: - Header

    private func header(subtitle: String) -> some View {
        VStack(spacing: FitnessSpacing.small) {
            ZStack {
                Circle()
                    .fill(FitnessTheme.accentGradient)
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)
            }
            Text("FitnessCoach")
                .font(FitnessTypography.hero)
                .foregroundStyle(FitnessTheme.primaryText)
            Text(subtitle)
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FitnessSpacing.large)
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            viewModel.goBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text("Back")
                    .font(FitnessTypography.caption)
            }
            .foregroundStyle(FitnessTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab("Sign In",  mode: .signIn)
            modeTab("Register", mode: .register)
        }
        .background(FitnessTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func modeTab(_ label: String, mode: AuthenticationViewModel.AuthMode) -> some View {
        Button {
            viewModel.authMode = mode
            viewModel.clearError()
        } label: {
            Text(label)
                .font(FitnessTypography.sectionTitle)
                .foregroundStyle(viewModel.authMode == mode ? .black : FitnessTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    viewModel.authMode == mode
                    ? FitnessTheme.accentGradient
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(4)
    }

    // MARK: - Standard Form Card

    private var standardFormCard: some View {
        VStack(spacing: FitnessSpacing.medium) {
            if viewModel.authMode == .register {
                inputField(icon: "person.fill", placeholder: "Full Name",
                           text: $viewModel.displayName, field: .name, keyboard: .default)
            }

            inputField(icon: "envelope.fill", placeholder: "Email",
                       text: $viewModel.email, field: .email, keyboard: .emailAddress)

            passwordField(placeholder: "Password", text: $viewModel.password,
                          field: .password, show: $showPassword)

            if viewModel.authMode == .register {
                passwordField(placeholder: "Confirm Password", text: $viewModel.confirmPassword,
                              field: .confirmPassword, show: $showConfirmPassword)

                if !viewModel.password.isEmpty {
                    passwordRulesView
                }
            }

            // Forgot password link — only in sign-in mode
            if viewModel.authMode == .signIn {
                Button {
                    viewModel.switchToForgotPassword()
                } label: {
                    Text("Forgot password?")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(FitnessSpacing.large)
        .background(FitnessTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Input Fields

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: FitnessSpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(FitnessTheme.accent)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundStyle(FitnessTheme.primaryText)
                .focused($focused, equals: field)
                .submitLabel(.next)
        }
        .padding(FitnessSpacing.medium)
        .background(FitnessTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(focused == field ? FitnessTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    private func passwordField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        show: Binding<Bool>
    ) -> some View {
        HStack(spacing: FitnessSpacing.medium) {
            Image(systemName: "lock.fill")
                .foregroundStyle(FitnessTheme.accent)
                .frame(width: 20)

            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .foregroundStyle(FitnessTheme.primaryText)
            .focused($focused, equals: field)

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
        }
        .padding(FitnessSpacing.medium)
        .background(FitnessTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(focused == field ? FitnessTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Password Rules

    private var passwordRulesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.passwordRules, id: \.label) { rule in
                HStack(spacing: 8) {
                    Image(systemName: rule.isMet ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(rule.isMet ? FitnessTheme.accent : FitnessTheme.secondaryText)
                    Text(rule.label)
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(rule.isMet ? FitnessTheme.primaryText : FitnessTheme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: FitnessSpacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FitnessTheme.caution)
            Text(message)
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.caution)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FitnessSpacing.medium)
        .background(FitnessTheme.caution.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Success Banner

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: FitnessSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FitnessTheme.success)
            Text(message)
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.success)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FitnessSpacing.medium)
        .background(FitnessTheme.success.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Email-Already-In-Use Smart Actions

    private var emailAlreadyInUseActions: some View {
        HStack(spacing: FitnessSpacing.small) {
            Button {
                viewModel.authMode = .signIn
                viewModel.clearError()
            } label: {
                Text("Sign In Instead")
                    .font(FitnessTypography.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(FitnessTheme.accent)
                    .clipShape(Capsule())
            }

            Button {
                viewModel.switchToForgotPassword()
            } label: {
                Text("Reset Password")
                    .font(FitnessTypography.caption.bold())
                    .foregroundStyle(FitnessTheme.caution)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(FitnessTheme.caution.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            focused = nil
            Task {
                if viewModel.authMode == .signIn {
                    await viewModel.signInWithEmail()
                } else {
                    await viewModel.registerWithEmail()
                }
            }
        } label: {
            Group {
                if viewModel.loadState == .loading {
                    ProgressView().tint(.black)
                } else {
                    Text(viewModel.authMode == .signIn ? "Sign In" : "Create Account")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(viewModel.loadState == .loading ||
                  (viewModel.authMode == .signIn ? !viewModel.isSignInFormValid : !viewModel.isRegisterFormValid))
    }

    // MARK: - Divider

    private var divider: some View {
        HStack {
            Rectangle().fill(FitnessTheme.secondaryText.opacity(0.3)).frame(height: 1)
            Text("or").font(FitnessTypography.tiny).foregroundStyle(FitnessTheme.secondaryText)
                .padding(.horizontal, FitnessSpacing.small)
            Rectangle().fill(FitnessTheme.secondaryText.opacity(0.3)).frame(height: 1)
        }
    }

    // MARK: - Google Button

    private var googleButton: some View {
        Button {
            focused = nil
            Task { await viewModel.signInWithGoogle() }
        } label: {
            HStack(spacing: FitnessSpacing.medium) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 24, height: 24)
                    Text("G")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                }
                Text("Continue with Google")
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FitnessTheme.secondaryText.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(viewModel.loadState == .loading)
    }

    // MARK: - Phone Button

    private var phoneButton: some View {
        Button {
            focused = nil
            viewModel.authMode = .phoneNumber
            viewModel.clearError()
        } label: {
            HStack(spacing: FitnessSpacing.medium) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FitnessTheme.accent)
                    .frame(width: 24)
                Text("Continue with Phone Number")
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FitnessTheme.secondaryText.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(viewModel.loadState == .loading)
    }

    // MARK: - Skip / Guest

    private var skipButton: some View {
        Button {
            viewModel.continueAsGuest()
        } label: {
            HStack(spacing: 8) {
                Text("Skip for now")
                    .font(.callout.weight(.medium))
                Image(systemName: "arrow.right.circle")
                    .font(.callout)
            }
            .foregroundStyle(FitnessTheme.secondaryText.opacity(0.80))
            .padding(.vertical, 10)
            .padding(.horizontal, FitnessSpacing.large)
        }
        .disabled(viewModel.loadState == .loading)
    }

    // MARK: - Switch Mode

    private var switchModeButton: some View {
        Button {
            viewModel.authMode = viewModel.authMode == .signIn ? .register : .signIn
            viewModel.clearError()
        } label: {
            Group {
                if viewModel.authMode == .signIn {
                    Text("Don't have an account? ") +
                    Text("Register").foregroundColor(FitnessTheme.accent).bold()
                } else {
                    Text("Already have an account? ") +
                    Text("Sign In").foregroundColor(FitnessTheme.accent).bold()
                }
            }
            .font(FitnessTypography.caption)
            .foregroundStyle(FitnessTheme.secondaryText)
        }
    }
}

// MARK: - Shake animation modifier
// Usage: .modifier(ShakeEffect(presses: count)) + withAnimation { count += 1 }

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    init(presses: Int) {
        animatableData = CGFloat(presses)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
