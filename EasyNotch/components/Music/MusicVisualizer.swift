//
//  MusicVisualizer.swift
//  EasyNotch
//
import AppKit
import Cocoa
import Defaults
import SwiftUI

class AudioSpectrum: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = true
    private var animationTimer: Timer?
    private var isLiveMode: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth: CGFloat = 2
        let barCount = 4
        let spacing: CGFloat = barWidth
        let totalWidth = CGFloat(barCount) * (barWidth + spacing)
        let totalHeight: CGFloat = 14
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0 ..< barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.fillColor = NSColor.white.cgColor
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            let path = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                                    xRadius: barWidth / 2,
                                    yRadius: barWidth / 2)
            barLayer.path = path.cgPath
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }

    // MARK: - Live (audio-reactive) mode

    /// Drives the bars from measured audio levels (0...1 per bar).
    func setLevels(_ levels: [CGFloat]) {
        guard levels.count == barLayers.count else { return }

        if !isLiveMode {
            isLiveMode = true
            animationTimer?.invalidate()
            animationTimer = nil
            barLayers.forEach { $0.removeAllAnimations() }
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        for (i, barLayer) in barLayers.enumerated() {
            let scale = 0.25 + min(max(levels[i], 0), 1) * 0.75
            barLayer.transform = CATransform3DMakeScale(1, scale, 1)
            barScales[i] = scale
        }
        CATransaction.commit()
    }

    /// Returns to the decorative random animation.
    func endLiveMode() {
        guard isLiveMode else { return }
        isLiveMode = false
        resetBars()
        if isPlaying {
            startAnimating()
        }
    }

    // MARK: - Random (decorative) mode

    private func startAnimating() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updateBars()
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }

    private func updateBars() {
        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]
            let targetScale = CGFloat.random(in: 0.35 ... 1.0)
            barScales[i] = targetScale
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = currentScale
            animation.toValue = targetScale
            animation.duration = 0.3
            animation.autoreverses = true
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 24, preferred: 24)
            barLayer.add(animation, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        guard !isLiveMode else { return }
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool
    var liveLevels: [Float]? = nil

    func makeNSView(context: Context) -> AudioSpectrum {
        let spectrum = AudioSpectrum()
        apply(to: spectrum)
        return spectrum
    }

    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: AudioSpectrum) {
        if let liveLevels = liveLevels {
            view.setLevels(liveLevels.map { CGFloat($0) })
        } else {
            view.endLiveMode()
            view.setPlaying(isPlaying)
        }
    }
}

/// Chooses between the audio-reactive spectrum (when enabled, available, and
/// capturing) and the decorative random animation.
struct SpectrumVisualizerView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @Default(.audioReactiveVisualizer) var audioReactive

    var body: some View {
        if #available(macOS 14.4, *), audioReactive {
            LiveSpectrumView()
        } else {
            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
        }
    }
}

@available(macOS 14.4, *)
private struct LiveSpectrumView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var provider = SystemAudioSpectrumProvider.shared

    var body: some View {
        AudioSpectrumView(
            isPlaying: $musicManager.isPlaying,
            liveLevels: provider.isCapturing ? provider.levels : nil
        )
    }
}

#Preview {
    AudioSpectrumView(isPlaying: .constant(true))
        .frame(width: 16, height: 20)
        .padding()
}
