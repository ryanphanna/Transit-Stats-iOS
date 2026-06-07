import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct LoginView: View {
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var isEnteringCode = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingLogin = false
    @State private var resendCooldown: Int = 0

    @StateObject private var api = TransitStatsAPI.shared

    var body: some View {
        ZStack {
            Color.deepNavy.ignoresSafeArea()
            
            // Subtle top glow
            VStack {
                LinearGradient(colors: [Color.blue.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 400)
                Spacer()
            }
            .ignoresSafeArea()

            if showingLogin {
                loginForm
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                landingScreen
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showingLogin)
    }

    // MARK: - Landing Screen

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                    Image(systemName: "tram.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Transit Stats")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Know your commute better\nthan the TTC does.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            VStack(spacing: 10) {
                featureRow(icon: "tram.circle.fill",
                           color: .blue,
                           title: "Log every trip",
                           detail: "Start and end trips in seconds, anywhere")
                featureRow(icon: "chart.bar.fill",
                           color: .indigo,
                           title: "See your patterns",
                           detail: "Routes, time, stops — all tracked over time")
                featureRow(icon: "message.fill",
                           color: Color(hex: "5E5CE6"),
                           title: "Works with your texts",
                           detail: "Log via SMS too, syncs to the app instantly")
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showingLogin = true
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.blue, .brandBlue],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 28)

                Text("Sign in with your phone number")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.bottom, 52)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        showingLogin = false
                        isEnteringCode = false
                        phoneNumber = ""
                        otpCode = ""
                        errorMessage = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))

                Text(isEnteringCode ? "Enter your code" : "Sign in")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(isEnteringCode
                     ? "We sent a 6-digit code to \(phoneNumber)"
                     : "Enter your phone number to continue")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.2), value: isEnteringCode)

            Spacer()

            VStack(spacing: 14) {
                if !isEnteringCode {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    TextField("6-Digit Code", text: $otpCode)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: { isEnteringCode ? verifyOtp() : requestOtp() }) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isEnteringCode ? "Verify & Sign In" : "Send Code")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color.blue, .brandBlue],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isLoading || (isEnteringCode ? otpCode.isEmpty : phoneNumber.isEmpty))

                if isEnteringCode {
                    HStack {
                        Button(action: {
                            isEnteringCode = false
                            otpCode = ""
                            errorMessage = nil
                        }) {
                            Text("Change Number")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Button(action: requestOtp) {
                            Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend Code")
                                .font(.subheadline)
                                .foregroundColor(resendCooldown > 0 ? .white.opacity(0.2) : .white.opacity(0.35))
                        }
                        .disabled(resendCooldown > 0)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEnteringCode)
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
    
    private func requestOtp() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await api.requestOtp(phoneNumber: phoneNumber)
                await MainActor.run {
                    isLoading = false
                    isEnteringCode = true
                    startResendCooldown()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { resendCooldown -= 1 }
            }
        }
    }
    
    private func verifyOtp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let customToken = try await api.verifyOtp(phoneNumber: phoneNumber, code: otpCode)
                
                // Sign in to Firebase Auth using Custom Token
                try await Auth.auth().signIn(withCustomToken: customToken)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
