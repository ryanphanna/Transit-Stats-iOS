import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var appEnv: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @Query private var profiles: [UserProfile]
    @State private var profileImage: UIImage? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var displayName: String = UserDefaults.standard.string(forKey: "displayName") ?? ""
    @State private var isEditingName = false
    @FocusState private var isNameFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var accent: Color { appEnv.accent }
    private var resolvedName: String { displayName.isEmpty ? "Transit Rider" : displayName }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                            ZStack {
                                if let img = profileImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(accent.opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(accent.opacity(0.6))
                                }
                            }
                            .overlay(Circle().stroke(accent.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.borderless)

                        VStack(alignment: .leading, spacing: 3) {
                            if isEditingName {
                                TextField("Your name", text: $displayName)
                                    .fontWeight(.semibold)
                                    .focused($isNameFocused)
                                    .onSubmit {
                                        UserDefaults.standard.set(displayName, forKey: "displayName")
                                        isEditingName = false
                                    }
                            } else {
                                Text(resolvedName)
                                    .fontWeight(.semibold)
                            }
                            Text("Account ID: \(authManager.currentUser?.uid.prefix(4) ?? "")••••\(authManager.currentUser?.uid.suffix(4) ?? "")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(isEditingName ? "Save" : "Edit") {
                            if isEditingName {
                                UserDefaults.standard.set(displayName, forKey: "displayName")
                                isEditingName = false
                            } else {
                                isEditingName = true
                                isNameFocused = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(accent)
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }

                Section("Plan") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile?.isPremium == true ? "Premium" : "Free")
                                .fontWeight(.semibold)
                            Text(profile?.isPremium == true ? "All features unlocked" : "Basic trip logging")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                                Button(action: { appEnv.accentKey = theme.rawValue }) {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(theme == .auto
                                                      ? AppTheme.agencyColor(for: appEnv.homeAgency)
                                                      : theme.swatchColor)
                                                .frame(width: 32, height: 32)
                                            if appEnv.accentKey == theme.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .black))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        Text(theme.label)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(appEnv.accentKey == theme.rawValue ? accent : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text("Auto mode matches your app accent to your most-ridden transit agency.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineSpacing(2)

                        if let agency = appEnv.homeAgency {
                            HStack {
                                Text("Home Agency")
                                    .font(.system(size: 13))
                                Spacer()
                                Text(agency)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Theme")
                }

                if profile?.isAdmin == true {
                    Section("Developer") {
                        Toggle(isOn: $locationManager.isHighFidelityEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Breadcrumb Tracking")
                                    .fontWeight(.medium)
                                Text("Records GPS path during trips. Higher battery usage.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .tint(accent)
                    }
                }

                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppEnvironment.appVersion).foregroundColor(.gray)
                    }
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text(AppEnvironment.platformName).foregroundColor(.gray)
                    }
                }

                Section("Support") {
                    let version = AppEnvironment.appVersion
                    let uid = authManager.currentUser?.uid.prefix(8) ?? "unknown"
                    let subject = "Transit%20Stats%20Feedback%20v\(version)%20[\(uid)]"
                    Link(destination: URL(string: "mailto:\(AppEnvironment.supportEmail)?subject=\(subject)")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(accent)
                                .frame(width: 24)
                            Text("Contact Us")
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: { authManager.signOut() }) {
                        HStack {
                            Spacer()
                            Text("Sign Out").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .onAppear { profileImage = ProfileImageManager.shared.load() }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    ProfileImageManager.shared.save(image)
                    profileImage = image
                }
            }
        }
    }
}

