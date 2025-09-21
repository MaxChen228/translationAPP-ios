import SwiftUI

/// 全局迷你播放器 - 與 GlobalAudioSessionManager 配合工作
struct GlobalAudioMiniPlayerView: View {
    @ObservedObject private var globalAudio = GlobalAudioSessionManager.shared
    @Environment(\.locale) private var locale

    var body: some View {
        if globalAudio.shouldShowMiniPlayer,
           let session = globalAudio.currentSession {
            VStack(spacing: 0) {
                // 可點擊的迷你播放器主體
                Button {
                    globalAudio.returnToSession()
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        // 播放/暫停按鈕
                        Button {
                            globalAudio.togglePlayback()
                        } label: {
                            ZStack {
                                AudioProgressRingView(
                                    progress: Double(session.currentCardIndex) / Double(max(1, session.totalCards)),
                                    size: 40
                                )
                                Image(systemName: (globalAudio.speechManager.isPlaying && !globalAudio.speechManager.isPaused) ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(DS.Palette.primary)
                        .clipShape(Circle())

                        // 控制按鈕
                        Button {
                            globalAudio.skipToNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(DS.Palette.primary)
                        }
                        .frame(width: 32, height: 32)

                        // 卡片信息
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.deckName)
                                .dsType(DS.Font.bodyEmph)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(session.progressText)
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // 停止按鈕
                        Button {
                            globalAudio.endSession()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 28, height: 28)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial)
                .dsTopHairline(color: DS.Palette.border.opacity(0.35))
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .dsAnimation(DS.AnimationToken.subtle, value: globalAudio.shouldShowMiniPlayer)
        }
    }
}

// MARK: - Legacy AudioMiniPlayerView (保留給舊版本兼容)

struct AudioMiniPlayerView: View {
    var title: String
    var index: Int
    var total: Int
    var isPlaying: Bool
    var isPaused: Bool
    var progress: Double = 0
    var level: Double = 0
    var onPrev: () -> Void
    var onToggle: () -> Void
    var onNext: () -> Void
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Combined ring + play/pause circle button
            ZStack {
                AudioProgressRingView(progress: progress, size: 40)
                Button(action: onToggle) {
                    Image(systemName: (isPlaying && !isPaused) ? "pause.fill" : "play.fill")
                }
                .buttonStyle(DSPrimaryCircleButton(diameter: 30))
            }

            DSQuickActionIconButton(systemName: "backward.fill", labelKey: "flashcards.prev", action: onPrev, style: .outline, size: 34)

            DSQuickActionIconButton(systemName: "forward.fill", labelKey: "content.next", action: onNext, style: .outline, size: 34)

            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .dsType(DS.Font.section)
                Text("\(index)/\(total)")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }

            DSQuickActionIconButton(systemName: "xmark", labelKey: "action.cancel", action: onStop, style: .outline, size: 34)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
        .dsTopHairline(color: DS.Palette.border.opacity(0.35))
    }
}
