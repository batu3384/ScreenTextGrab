import AppKit
import SwiftUI

struct MenuBarCard<Content: View>: View {
    let isCompact: Bool
    @ViewBuilder var content: Content

    init(isCompact: Bool, @ViewBuilder content: () -> Content) {
        self.isCompact = isCompact
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(isCompact ? 11 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.04), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

struct MenuBarStatusBadge: View {
    let text: String
    let tint: Color
    let isCompact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isCompact ? 10 : 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.13))
                    )
            )
    }
}

struct MenuBarSecondaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompact ? 11 : 12)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: isCompact ? 9.8 : 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 8 : 9)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 40 : 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct MenuBarSmallActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompact ? 10 : 11)
                Text(title)
            }
            .font(.system(size: isCompact ? 9.5 : 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, isCompact ? 10 : 11)
            .padding(.vertical, isCompact ? 6.5 : 7.5)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MenuBarCompactInlineButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: isCompact ? 11 : 12)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: isCompact ? 9.6 : 10.1, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, isCompact ? 9 : 10)
            .padding(.vertical, isCompact ? 6.5 : 7.5)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 34 : 36)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.13))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.controlStrokeStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MenuBarIconActionButton: View {
    let systemName: String
    let tint: Color
    let isCompact: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: isCompact ? 30 : 32, height: isCompact ? 30 : 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.controlFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(tint.opacity(0.12))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.controlStrokeStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct MenuBarUpdateActionButton: View {
    let presentation: MenuBarUpdatePresentation
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: presentation.content.iconName)
                    .font(.system(size: isCompact ? 9 : 10, weight: .bold))

                Text(presentation.content.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            .font(.system(size: isCompact ? 8.9 : 9.8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 10 : 11)
            .padding(.vertical, isCompact ? 6 : 7)
            .frame(width: presentation.width, height: isCompact ? 32 : 34)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.controlFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(presentation.tint.opacity(presentation.backgroundOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(presentation.tint.opacity(0.48), lineWidth: 1)
            )
            .shadow(color: presentation.tint.opacity(presentation.isAvailable ? 0.16 : 0), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(presentation.isBusy || !presentation.isAvailable)
        .opacity(presentation.isAvailable ? 1 : 0.62)
        .help(presentation.content.helpText)
        .accessibilityLabel(presentation.content.accessibilityLabel)
    }
}

struct MenuBarQuickSettingRow<Control: View>: View {
    let isCompact: Bool
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    init(
        isCompact: Bool,
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) {
        self.isCompact = isCompact
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: isCompact ? 11.5 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: isCompact ? 10 : 10.3, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            control
        }
    }
}

struct MenuBarFeedbackText: View {
    let message: String
    let tint: Color
    let isCompact: Bool

    var body: some View {
        Text(message)
            .font(.system(size: isCompact ? 10 : 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(isCompact ? 2 : 3)
    }
}

struct MenuBarHeaderSection: View {
    let isCompact: Bool
    let headerLine: String
    let updatePresentation: MenuBarUpdatePresentation
    let onUpdate: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: isCompact ? 10 : 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: isCompact ? 38 : 42, height: isCompact ? 38 : 42)
                .clipShape(RoundedRectangle(cornerRadius: isCompact ? 11 : 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenTextGrab")
                    .font(.system(size: isCompact ? 15 : 16.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(headerLine)
                    .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            HStack(spacing: 7) {
                MenuBarUpdateActionButton(
                    presentation: updatePresentation,
                    isCompact: isCompact,
                    action: onUpdate
                )

                MenuBarIconActionButton(
                    systemName: "power",
                    tint: .accentRose,
                    isCompact: isCompact,
                    accessibilityLabel: L10n.accessibilityQuitApp,
                    action: onQuit
                )
            }
        }
    }
}

struct MenuBarStatusSection: View {
    let isCompact: Bool
    let statusTint: Color
    let statusTitle: String
    let statusDescription: String
    let confidenceBadge: (text: String, tint: Color)?
    let permissionBadge: String
    let permissionTint: Color

    var body: some View {
        MenuBarCard(isCompact: isCompact) {
            VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 8, height: 8)

                    Text(statusTitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    if let confidenceBadge {
                        MenuBarStatusBadge(text: confidenceBadge.text, tint: confidenceBadge.tint, isCompact: isCompact)
                    }

                    MenuBarStatusBadge(text: permissionBadge, tint: permissionTint, isCompact: isCompact)
                }

                Text(statusDescription)
                    .font(.system(size: isCompact ? 11 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(isCompact ? 2 : 3)
            }
        }
    }
}

struct MenuBarPrimaryActionSection: View {
    let isCompact: Bool
    let canStartCapture: Bool
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: isCompact ? 15 : 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isCompact ? 32 : 36, height: isCompact ? 32 : 36)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: isCompact ? 14 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: isCompact ? 10.5 : 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(isCompact ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: canStartCapture ? [.accentAmber, .accentCoral] : [Color.controlFillStrong, Color.controlFill],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(canStartCapture ? Color.white.opacity(0.14) : Color.controlStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: canStartCapture ? Color.black.opacity(0.18) : .clear, radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canStartCapture)
        .opacity(canStartCapture ? 1 : 0.76)
    }
}

struct MenuBarNoticeSection: View {
    let isCompact: Bool
    let notice: NoticeContent

    var body: some View {
        MenuBarCard(isCompact: isCompact) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: notice.icon)
                        .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                        .foregroundStyle(notice.tint)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(notice.title)
                            .font(.system(size: isCompact ? 11 : 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(notice.message)
                            .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .lineLimit(isCompact ? 2 : 3)
                    }
                }

                if let actionTitle = notice.actionTitle, let action = notice.action {
                    MenuBarCompactInlineButton(
                        title: actionTitle,
                        icon: "sparkles",
                        tint: notice.tint,
                        isCompact: isCompact,
                        action: action
                    )
                }
            }
        }
    }
}

struct MenuBarImportDropOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.54))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.accentMint.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            )
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.accentMint)

                    Text(L10n.pair("Görsel veya PDF bırak", "Drop an Image or PDF"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(L10n.pair("Görsel dosyası OCR’a gider, PDF dosyası doğrudan içe alınır.", "Image files go through OCR, and PDF files are imported directly."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .padding(18)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
