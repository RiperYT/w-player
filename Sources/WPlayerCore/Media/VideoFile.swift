import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What AVFoundation reads from a video file.
public struct VideoInfo: Equatable, Sendable {
    public var duration: Double
    public var width: Int
    public var height: Int
    /// The video track's codec as a four-character code: "hvc1", "avc1"…
    public var codec: String
    public var hasAudio: Bool

    public var isHEVC: Bool { codec == "hvc1" || codec == "hev1" }
}

public enum VideoFileError: LocalizedError {
    case noVideoTrack
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack: "The file has no video in it."
        case .exportFailed(let reason): "The video couldn't be converted for the Lock Screen: \(reason)"
        }
    }
}

public enum VideoFile {
    public static func info(of url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw VideoFileError.noVideoTrack }
        let (size, transform, formats) = try await track.load(.naturalSize, .preferredTransform, .formatDescriptions)
        let shown = size.applying(transform)
        let duration = try await asset.load(.duration).seconds
        let codec = formats.first.map { fourCC(CMFormatDescriptionGetMediaSubType($0)) } ?? ""
        let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
        return VideoInfo(duration: duration.isFinite ? duration : 0, width: Int(abs(shown.width)),
                         height: Int(abs(shown.height)), codec: codec, hasAudio: hasAudio)
    }

    /// A PNG of one frame (a second in, or the first frame of a shorter video), at most `maxWidth` wide.
    public static func writeThumbnail(of url: URL, to destination: URL, maxWidth: CGFloat = 1280) async throws {
        try await writeFrame(of: url, to: destination, type: .png, maxWidth: maxWidth)
    }

    /// The first frame at full size as a JPEG: the system wallpaper behind the moving one, which the menu bar takes its
    /// colour from. The first frame, because that's what the loop starts on.
    public static func writeStill(of url: URL, to destination: URL) async throws {
        try await writeFrame(of: url, to: destination, type: .jpeg, maxWidth: nil, at: 0)
    }

    static func writeFrame(of url: URL, to destination: URL, type: UTType, maxWidth: CGFloat?, at seconds: Double? = nil) async throws {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        if let maxWidth { generator.maximumSize = CGSize(width: maxWidth, height: maxWidth) }
        let duration = try await asset.load(.duration).seconds
        let at = CMTime(seconds: seconds ?? (duration > 2 ? 1 : 0), preferredTimescale: 600)
        let (image, _) = try await generator.image(at: at)
        guard let target = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(target, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(target) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// A QuickTime movie in HEVC, which is what the Lock Screen plays. A video that is HEVC already only changes its
    /// container: re-encoding a 10-bit HEVC file with Apple's HEVC presets turns 20 MB into gigabytes.
    public static func exportForLockScreen(_ source: URL, to destination: URL) async throws {
        let info = try await info(of: source)
        let preset = info.isHEVC ? AVAssetExportPresetPassthrough : AVAssetExportPresetHEVCHighestQuality
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: preset) else {
            throw VideoFileError.exportFailed("no export session for \(preset)")
        }
        try? FileManager.default.removeItem(at: destination)
        do {
            try await session.export(to: destination, as: .mov)
        } catch {
            throw VideoFileError.exportFailed(error.localizedDescription)
        }
    }

    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
