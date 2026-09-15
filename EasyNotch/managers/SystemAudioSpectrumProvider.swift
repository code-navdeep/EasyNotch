//
//  SystemAudioSpectrumProvider.swift
//  EasyNotch
//
//  Captures the system audio mix through a Core Audio process tap and turns it
//  into a small number of smoothed frequency-band levels for the visualizer.
//

import Accelerate
import AudioToolbox
import Combine
import CoreAudio
import Defaults
import Foundation
import os

@available(macOS 14.4, *)
final class SystemAudioSpectrumProvider: ObservableObject {
    static let shared = SystemAudioSpectrumProvider()

    /// Normalized 0...1 level per visualizer bar, low band first.
    @Published private(set) var levels: [Float]
    /// True while the tap is running and delivering samples.
    @Published private(set) var isCapturing: Bool = false

    static let bandCount = 4

    // MARK: - Capture state
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapDescription: CATapDescription?
    private let ioQueue = DispatchQueue(label: "EasyNotch.AudioSpectrum", qos: .userInteractive)

    private var stopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Analysis state (accessed on ioQueue only)
    private static let fftSize = 1024
    private static let log2n = vDSP_Length(10)
    private var fftSetup: FFTSetup?
    private var hannWindow = [Float](repeating: 0, count: fftSize)
    private var sampleBuffer = [Float]()
    private var sampleRate: Double = 48_000
    private var channelCount: Int = 2
    private var smoothedLevels: [Float]
    private var lastPublish = Date.distantPast

    private init() {
        let zeros = [Float](repeating: 0, count: Self.bandCount)
        levels = zeros
        smoothedLevels = zeros

        vDSP_hann_window(&hannWindow, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))

        Defaults.publisher(.audioReactiveVisualizer)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.reevaluate() }
            }
            .store(in: &cancellables)

        MusicManager.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reevaluate()
            }
            .store(in: &cancellables)
    }

    // MARK: - Start / stop policy
    private func reevaluate() {
        let shouldCapture = Defaults[.audioReactiveVisualizer] && MusicManager.shared.isPlaying

        if shouldCapture {
            stopTask?.cancel()
            stopTask = nil
            if !isCapturing {
                start()
            }
        } else if isCapturing, stopTask == nil {
            // Grace period so pause/play toggles don't churn tap creation.
            stopTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.stop()
                self?.stopTask = nil
            }
        }
    }

    private func start() {
        guard !isCapturing else { return }

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "EasyNotch Visualizer Tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        tapDescription = description

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else {
            Log.media.error("Audio tap creation failed (status \(status, privacy: .public)) — visualizer falls back to animation")
            teardown()
            return
        }
        tapID = newTapID

        readTapFormat()

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "EasyNotch Visualizer",
            kAudioAggregateDeviceUIDKey: "studio.liberated.EasyNotch.visualizer-tap",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[String: Any]](),
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]

        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID)
        guard status == noErr else {
            Log.media.error("Aggregate device creation failed (status \(status, privacy: .public)) — visualizer falls back to animation")
            teardown()
            return
        }
        aggregateDeviceID = newAggregateID

        fftSetup = vDSP_create_fftsetup(Self.log2n, FFTRadix(kFFTRadix2))
        sampleBuffer.removeAll(keepingCapacity: true)

        var newProcID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&newProcID, aggregateDeviceID, ioQueue) { [weak self] _, inInputData, _, _, _ in
            self?.process(bufferList: inInputData)
        }
        guard status == noErr, let procID = newProcID else {
            Log.media.error("IO proc creation failed (status \(status, privacy: .public)) — visualizer falls back to animation")
            teardown()
            return
        }
        ioProcID = procID

        status = AudioDeviceStart(aggregateDeviceID, procID)
        guard status == noErr else {
            Log.media.error("Audio device start failed (status \(status, privacy: .public)) — visualizer falls back to animation")
            teardown()
            return
        }

        isCapturing = true
        Log.media.info("Audio-reactive visualizer capture started")
    }

    private func stop() {
        guard isCapturing || tapID != kAudioObjectUnknown else { return }
        teardown()
        Log.media.info("Audio-reactive visualizer capture stopped")
    }

    private func teardown() {
        if let procID = ioProcID, aggregateDeviceID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        }
        ioProcID = nil

        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        tapDescription = nil

        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }

        isCapturing = false
        let zeros = [Float](repeating: 0, count: Self.bandCount)
        smoothedLevels = zeros
        levels = zeros
    }

    private func readTapFormat() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format)
        if status == noErr, format.mSampleRate > 0 {
            sampleRate = format.mSampleRate
            channelCount = max(1, Int(format.mChannelsPerFrame))
        }
    }

    // MARK: - Sample processing (ioQueue)
    private func process(bufferList: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard let firstBuffer = buffers.first,
              let data = firstBuffer.mData else { return }

        let floatCount = Int(firstBuffer.mDataByteSize) / MemoryLayout<Float>.size
        guard floatCount > 0 else { return }
        let samples = data.bindMemory(to: Float.self, capacity: floatCount)

        // Mono mix: average interleaved channels; a deinterleaved first buffer is
        // a single channel already (channelCount divides into separate buffers).
        let channels = Int(firstBuffer.mNumberChannels) > 0 ? Int(firstBuffer.mNumberChannels) : channelCount
        let frameCount = floatCount / max(1, channels)
        sampleBuffer.reserveCapacity(sampleBuffer.count + frameCount)
        if channels <= 1 {
            sampleBuffer.append(contentsOf: UnsafeBufferPointer(start: samples, count: floatCount))
        } else {
            for frame in 0..<frameCount {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += samples[frame * channels + channel]
                }
                sampleBuffer.append(sum / Float(channels))
            }
        }

        guard sampleBuffer.count >= Self.fftSize else { return }
        if sampleBuffer.count > Self.fftSize {
            sampleBuffer.removeFirst(sampleBuffer.count - Self.fftSize)
        }

        // Throttle analysis + publishing to ~30 Hz.
        let now = Date()
        guard now.timeIntervalSince(lastPublish) >= 1.0 / 30.0 else { return }
        lastPublish = now

        computeAndPublishLevels()
    }

    private func computeAndPublishLevels() {
        guard let setup = fftSetup else { return }

        var windowed = [Float](repeating: 0, count: Self.fftSize)
        vDSP_vmul(sampleBuffer, 1, hannWindow, 1, &windowed, 1, vDSP_Length(Self.fftSize))

        let halfSize = Self.fftSize / 2
        var realParts = [Float](repeating: 0, count: halfSize)
        var imagParts = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        realParts.withUnsafeMutableBufferPointer { realPointer in
            imagParts.withUnsafeMutableBufferPointer { imagPointer in
                var splitComplex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                windowed.withUnsafeBytes { rawPointer in
                    let complexPointer = rawPointer.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complexPointer.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfSize))
                }
                vDSP_fft_zrip(setup, &splitComplex, 1, Self.log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Log-spaced band edges in Hz, folded onto FFT bins.
        let bandEdges: [Double] = [60, 250, 1_000, 4_000, 12_000]
        let binWidth = sampleRate / Double(Self.fftSize)
        var newLevels = [Float](repeating: 0, count: Self.bandCount)

        for band in 0..<Self.bandCount {
            let lowBin = max(1, Int(bandEdges[band] / binWidth))
            let highBin = min(halfSize - 1, max(lowBin + 1, Int(bandEdges[band + 1] / binWidth)))
            var sum: Float = 0
            for bin in lowBin..<highBin {
                sum += magnitudes[bin]
            }
            let mean = sum / Float(highBin - lowBin)
            // Map power to a 0...1 level over a ~50 dB display range.
            let db = 10 * log10(mean + 1e-12)
            let normalized = (db + 58) / 50
            newLevels[band] = min(max(normalized, 0), 1)
        }

        // Fast attack, slow decay.
        for band in 0..<Self.bandCount {
            if newLevels[band] >= smoothedLevels[band] {
                smoothedLevels[band] = newLevels[band]
            } else {
                smoothedLevels[band] = smoothedLevels[band] * 0.75 + newLevels[band] * 0.25
            }
        }

        let published = smoothedLevels
        DispatchQueue.main.async { [weak self] in
            self?.levels = published
        }
    }
}
