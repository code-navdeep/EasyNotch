//
//  LyricsPanelView.swift
//  EasyNotch
//

import SwiftUI

struct LyricsPanelView: View {
    @ObservedObject var musicManager = MusicManager.shared

    var body: some View {
        Group {
            if musicManager.isFetchingLyrics {
                statusText("Loading lyrics…")
            } else if !musicManager.syncedLyrics.isEmpty {
                syncedLyricsView
            } else if !musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                plainLyricsView
            } else {
                statusText("No lyrics found")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var syncedLyricsView: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = musicManager.estimatedPlaybackPosition(at: timeline.date)
            let currentIndex = musicManager.lyricLineIndex(at: elapsed) ?? 0

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(musicManager.syncedLyrics.enumerated()), id: \.offset) { index, line in
                            Text(line.text)
                                .font(index == currentIndex ? .headline : .subheadline)
                                .foregroundStyle(index == currentIndex ? Color.white : Color.gray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 16)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.smooth) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(currentIndex, anchor: .center)
                }
            }
        }
    }

    private var plainLyricsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(musicManager.currentLyrics)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    LyricsPanelView()
        .frame(width: 500, height: 150)
        .background(.black)
}
