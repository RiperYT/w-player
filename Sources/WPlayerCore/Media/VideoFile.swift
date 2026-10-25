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
        return VideoInfo(duration: duration.isFinite ? duration : 0, width: Int(abs(shown.width)),
                         height: Int(abs(shown.height)), codec: codec)
    }

    /// A PNG of one frame (a second in, or the first frame of a shorter video), at most `maxWidth` wide.
    public static func writeThumbnail(of url: URL, to destination: URL, maxWidth: CGFloat = 1280) async throws {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        let duration = try await asset.load(.duration).seconds
        let at = CMTime(seconds: duration > 2 ? 1 : 0, preferredTimescale: 600)
        let (image, _) = try await generator.image(at: at)
        guard let target = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(target, image, nil)
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
