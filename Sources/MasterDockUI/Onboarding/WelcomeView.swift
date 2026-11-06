import SwiftUI
import MasterDockCore
import MasterDockServices

/// First-launch welcome: what Master Dock is, how to open it, and the permissions it uses.
/// Four short pages, and every permission is optional.
public struct WelcomeView: View {
    public static let seenKey = "has_seen_welcome_v1"

    let onFinish: () -> Void
    @State private var page = 0
    @State private var goingForward = true
    private let pageCount = 4

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: WelcomeIntroPage()
                case 1: WelcomeGesturePage()
                case 2: WelcomePermissionsPage()
                default: WelcomeDonePage()
                }
            }
            .id(page)
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Bottom bar: back, page dots, continue
            HStack {
                Button(page == 0 ? "Skip" : "Back") {
                    if page == 0 { finish() } else { go(to: page - 1) }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 90, alignment: .leading)

                Spacer()

                HStack(spacing: 7) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.white : Color.white.opacity(0.25))
                            .frame(width: index == page ? 18 : 7, height: 7)
                            .onTapGesture { go(to: index) }
                    }
                }

                Spacer()

                Button(action: { page == pageCount - 1 ? finish() : go(to: page + 1) }) {
                    Text(page == pageCount - 1 ? "Open Master Dock" : "Continue")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(GlassTheme.accentBlue))
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
                .keyboardShortcut(.defaultAction)
                .frame(minWidth: 90, alignment: .trailing)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 470)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                LinearGradient(colors: [GlassTheme.accentBlue.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    private func go(to newPage: Int) {
        goingForward = newPage > page
        withAnimation(.spring(response: 0.4, dampingFraction: 1)) { page = newPage }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        onFinish()
    }
}

// MARK: - Pages

private struct WelcomePageLayout<Art: View, Extra: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let art: Art
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            art
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
            }
            extra
            Spacer(minLength: 10)
        }
        .padding(.horizontal, 30)
    }
}

private struct WelcomeIntroPage: View {
    var body: some View {
        WelcomePageLayout(
            title: "Welcome to Master Dock",
            subtitle: "A sidebar for your Mac with AI, music, your calendar, clipboard and more, one swipe away."
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [GlassTheme.accentBlue, GlassTheme.accentCyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: GlassTheme.accentBlue.opacity(0.5), radius: 18, y: 6)
                Image(systemName: "dock.rectangle")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(.white)
            }
        } extra: {
            HStack(spacing: 18) {
                feature("sparkles", "AI")
                feature("music.note", "Music")
                feature("calendar", "Calendar")
                feature("doc.on.clipboard", "Clipboard")
                feature("square.grid.2x2", "Widgets")
            }
            .padding(.top, 8)
        }
    }

    private func feature(_ icon: String, _ name: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.08)))
            Text(name)
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

private struct WelcomeGesturePage: View {
    @State private var swipe = false

    var body: some View {
        WelcomePageLayout(
            title: "Open it anytime",
            subtitle: "Put two fingers on the left edge of your trackpad and swipe right. Swipe farther to talk to the AI with your voice."
        ) {
            // A little trackpad with two fingers sliding in from the left edge.
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    .frame(width: 200, height: 130)
                VStack(spacing: 14) {
                    Circle().fill(Color.white.opacity(0.9)).frame(width: 18, height: 18)
                    Circle().fill(Color.white.opacity(0.9)).frame(width: 18, height: 18)
                }
                .shadow(color: GlassTheme.accentCyan.opacity(0.8), radius: 8)
                .offset(x: swipe ? 140 : 12)
                .opacity(swipe ? 0.2 : 1)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { swipe = true }
            }
        } extra: {
            HStack(spacing: 8) {
                Text("No trackpad? Press")
                    .foregroundColor(.white.opacity(0.7))
                Text(GlobalHotKeys.toggleDock.display)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)))
            }
            .font(.system(size: 13))
            .padding(.top, 6)
        }
    }
}

private struct WelcomePermissionsPage: View {
    @ObservedObject private var permissions = PermissionManager.shared
    @State private var locationAsked = UserDefaults.standard.bool(forKey: WeatherService.locationAskedKey)

    var body: some View {
        WelcomePageLayout(
            title: "Allow what you want",
            subtitle: "Everything is optional and stays on this Mac. You can change these later in Settings."
        ) {
            EmptyView()
        } extra: {
            VStack(spacing: 10) {
                row(icon: "calendar", title: "Calendar", detail: "Show and add your events",
                    granted: permissions.isCalendarGranted) {
                    permissions.requestCalendar { _ in
                        Task { await CalendarService.shared.refreshEvents() }
                    }
                }
                row(icon: "mic.fill", title: "Microphone", detail: "Talk to the AI with your voice",
                    granted: permissions.isMicrophoneGranted) {
                    permissions.requestMicrophone()
                }
                row(icon: "location.fill", title: "Location", detail: "Weather for where you are",
                    granted: locationAsked) {
                    WeatherService.shared.requestLocationAccess()
                    locationAsked = true
                }
            }
            .frame(maxWidth: 400)
            .padding(.top, 4)
        }
        .onAppear { permissions.checkAllPermissions() }
    }

    private func row(icon: String, title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTypography.bodyBold).foregroundColor(.white)
                Text(detail).font(AppTypography.caption).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            if granted {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(AppTypography.captionBold)
                    .foregroundColor(GlassTheme.accentEmerald)
            } else {
                Button("Allow", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

private struct WelcomeDonePage: View {
    var body: some View {
        WelcomePageLayout(
            title: "You're all set",
            subtitle: "Click Edit Widgets at the bottom of the dock to pick, hide and reorder cards. Double click any card title to rename it."
        ) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(GlassTheme.accentEmerald, Color.white.opacity(0.1))
                .shadow(color: GlassTheme.accentEmerald.opacity(0.4), radius: 16)
        } extra: {
            Text("Tip: right click the Master Dock icon in the menu bar for more options.")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 6)
        }
    }
}
