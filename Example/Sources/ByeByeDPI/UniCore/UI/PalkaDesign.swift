//
//  PalkaDesign.swift
//  PalkaDPI
//
//  Shared visual language for the Palka interface.
//

import SwiftUI

enum PalkaDesign {
    static let background = Color(red: 0.025, green: 0.075, blue: 0.11)
    static let surface = Color(red: 0.07, green: 0.14, blue: 0.19)
    static let elevatedSurface = Color(red: 0.10, green: 0.20, blue: 0.25)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.68)
    static let textMuted = Color.white.opacity(0.62)
    static let textDim = Color.white.opacity(0.22)

    static let border = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.15)
    static let success = Color(red: 0.30, green: 0.77, blue: 0.76)
    static let successText = Color(red: 0.66, green: 0.91, blue: 0.88)
    static let errorText = Color(red: 0.97, green: 0.51, blue: 0.51)

    static let screenPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cardRadius: CGFloat = 24
}

func palkaLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private struct PalkaGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.height * 0.65
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addCurve(to: CGPoint(x: rect.maxX, y: y), control1: CGPoint(x: rect.width * 0.35, y: y - 30), control2: CGPoint(x: rect.width * 0.65, y: y + 30))
            y += 28
        }
        return path
    }
}

struct PalkaBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PalkaDesign.background

                PalkaGridShape()
                    .stroke(PalkaDesign.success.opacity(0.08), lineWidth: 0.7)

                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        PalkaDesign.background.opacity(0.32),
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.72
                )

                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            PalkaDesign.background.opacity(0),
                            PalkaDesign.background,
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct PalkaCardModifier: ViewModifier {
    let radius: CGFloat
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        selected
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.05),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [PalkaDesign.surface, PalkaDesign.surface]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(selected ? PalkaDesign.borderStrong : PalkaDesign.border, lineWidth: 1)
            )
    }
}

extension View {
    func palkaCard(radius: CGFloat = PalkaDesign.cardRadius, selected: Bool = false) -> some View {
        modifier(PalkaCardModifier(radius: radius, selected: selected))
    }
}

struct PalkaPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.15))
    }
}

struct PalkaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Color(red: 0.027, green: 0.027, blue: 0.055))
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.white, Color(red: 0.91, green: 0.93, blue: 0.97)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.90), lineWidth: 0.5)
            )
            .shadow(color: Color.white.opacity(configuration.isPressed ? 0.18 : 0.10), radius: configuration.isPressed ? 14 : 10, y: 4)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.70)
            .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.15))
    }
}

struct PalkaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(PalkaDesign.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(configuration.isPressed ? 0.11 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PalkaDesign.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.15))
    }
}

struct PalkaCompactPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(red: 0.027, green: 0.027, blue: 0.055))
            .padding(.horizontal, 16)
            .frame(minWidth: 88, minHeight: 44)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.white, Color(red: 0.91, green: 0.93, blue: 0.97)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.90), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.15))
    }
}

struct PalkaStatusDot: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(isActive ? PalkaDesign.success : PalkaDesign.textDim)
            .frame(width: 8, height: 8)
            .shadow(color: isActive ? PalkaDesign.success.opacity(0.8) : .clear, radius: 6)
            .opacity(isActive && pulsing ? 0.42 : 1)
            .onAppear {
                guard isActive && !reduceMotion else { return }
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .onChange(of: isActive) { newValue in
                pulsing = false
                guard newValue && !reduceMotion else { return }
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

struct PalkaIconBadge: View {
    let image: Image

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .foregroundColor(PalkaDesign.textPrimary)
            .frame(width: 19, height: 19)
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

struct PalkaSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased(with: Locale.current))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundColor(PalkaDesign.textMuted)
                .padding(.leading, 4)

            VStack(spacing: 10) {
                content
            }
        }
    }
}

enum PalkaFeedbackKind {
    case success
    case error
}

struct PalkaFeedbackBanner: View {
    let text: String
    let kind: PalkaFeedbackKind

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(text)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundColor(kind == .success ? PalkaDesign.successText : PalkaDesign.errorText)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(
            (kind == .success ? PalkaDesign.successText : PalkaDesign.errorText)
                .opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    (kind == .success ? PalkaDesign.successText : PalkaDesign.errorText)
                        .opacity(0.18),
                    lineWidth: 1
                )
        )
    }
}

private struct PalkaEntranceModifier: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .onAppear {
                if reduceMotion {
                    visible = true
                    return
                }
                withAnimation(
                    Animation
                        .timingCurve(0.32, 0.72, 0, 1, duration: 0.38)
                        .delay(delay)
                ) {
                    visible = true
                }
            }
    }
}

extension View {
    func palkaEntrance(delay: Double = 0) -> some View {
        modifier(PalkaEntranceModifier(delay: delay))
    }
}
