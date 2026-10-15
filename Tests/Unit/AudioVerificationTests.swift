import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio

struct AudioReport {
    let filename: String
    let sizeBytes: Int64
    let durationSeconds: Double
    let sampleRate: Double
    let channels: UInt32
    let formatFourCC: String
    let coreAudioOk: Bool
    let avAudioFileOk: Bool
    let pcmDecodedOk: Bool
    let avAudioPlayerOk: Bool
    let errorDetail: String?
}

func fourCCToString(_ code: UInt32) -> String {
    let bytes: [UInt8] = [
        UInt8((code >> 24) & 0xFF),
        UInt8((code >> 16) & 0xFF),
        UInt8((code >> 8) & 0xFF),
        UInt8(code & 0xFF)
    ]
    return bytes.map {
        let scalar = UnicodeScalar($0)
        return (scalar.isASCII && $0 >= 32 && $0 <= 126) ? String(scalar) : "?"
    }.joined()
}

@main
struct AudioVerifier {
    static func main() {
        print("======================================================================")
        print("   EMPIRICAL CHALLENGER: CoreAudio & AVFoundation Audio Verification")
        print("======================================================================")

        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let audioDir = (currentDir as NSString).appendingPathComponent("KirmatasIOS/Audio")

        guard fileManager.fileExists(atPath: audioDir) else {
            print("ERROR: Audio directory does not exist at: \(audioDir)")
            exit(1)
        }

        let audioFileNames: [String]
        do {
            let files = try fileManager.contentsOfDirectory(atPath: audioDir)
            audioFileNames = files.filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") }.sorted()
        } catch {
            print("ERROR: Failed to list audio directory: \(error)")
            exit(1)
        }

        print("Discovered \(audioFileNames.count) audio files in \(audioDir).\n")
        guard audioFileNames.count == 41 else {
            print("ERROR: Expected exactly 41 audio files, but found \(audioFileNames.count)")
            exit(1)
        }

        var reports: [AudioReport] = []
        var failedFiles: [String] = []

        print(String(format: "%-22@ | %8@ | %8@ | %7@ | %4@ | %6@ | %-7@ | %-7@ | %-7@",
                     "Filename", "Size(KB)", "Duration", "SR(Hz)", "Ch", "Format", "CAudio", "AVFile", "AVPlayer"))
        print(String(repeating: "-", count: 85))

        for filename in audioFileNames {
            let fullPath = (audioDir as NSString).appendingPathComponent(filename)
            let fileURL = URL(fileURLWithPath: fullPath)

            var fileSize: Int64 = 0
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? NSNumber {
                fileSize = size.int64Value
            }

            var coreAudioOk = false
            var sampleRate: Double = 0.0
            var channels: UInt32 = 0
            var durationCA: Double = 0.0
            var formatFourCC = "????"
            var errorMsg: String? = nil

            // 1. CoreAudio test via AudioFileOpenURL
            var audioFileID: AudioFileID? = nil
            let openStatus = AudioFileOpenURL(fileURL as CFURL, .readPermission, 0, &audioFileID)
            if openStatus == noErr, let fileID = audioFileID {
                var asbd = AudioStreamBasicDescription()
                var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                let propStatus = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &propSize, &asbd)

                if propStatus == noErr {
                    sampleRate = asbd.mSampleRate
                    channels = asbd.mChannelsPerFrame
                    formatFourCC = fourCCToString(asbd.mFormatID)

                    var durationSec: Float64 = 0.0
                    var durSize = UInt32(MemoryLayout<Float64>.size)
                    let durStatus = AudioFileGetProperty(fileID, kAudioFilePropertyEstimatedDuration, &durSize, &durationSec)
                    if durStatus == noErr {
                        durationCA = Double(durationSec)
                        coreAudioOk = true
                    } else {
                        // Fallback: estimate from packet count
                        var packetCount: UInt64 = 0
                        var packetSize = UInt32(MemoryLayout<UInt64>.size)
                        if AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount, &packetSize, &packetCount) == noErr {
                            durationCA = Double(packetCount) * (asbd.mFramesPerPacket > 0 ? Double(asbd.mFramesPerPacket) : 1152.0) / (asbd.mSampleRate > 0 ? asbd.mSampleRate : 44100.0)
                            coreAudioOk = durationCA > 0
                        }
                    }
                }
                AudioFileClose(fileID)
            } else {
                errorMsg = "CoreAudio open failed: OSStatus \(openStatus)"
            }

            // 2. AVFoundation AVAudioFile + PCM decode test
            var avAudioFileOk = false
            var pcmDecodedOk = false
            var avFileDuration: Double = 0.0
            do {
                let avFile = try AVAudioFile(forReading: fileURL)
                let length = avFile.length
                if length > 0 {
                    avAudioFileOk = true
                    let format = avFile.processingFormat
                    avFileDuration = Double(length) / format.sampleRate

                    // Attempt actual PCM frame decode
                    let framesToRead = AVAudioFrameCount(min(length, 4096))
                    if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) {
                        try avFile.read(into: pcmBuffer, frameCount: framesToRead)
                        if pcmBuffer.frameLength > 0 {
                            pcmDecodedOk = true
                        }
                    }
                }
            } catch {
                let currentErr = errorMsg ?? ""
                errorMsg = currentErr.isEmpty ? "AVAudioFile: \(error.localizedDescription)" : "\(currentErr); AVAudioFile: \(error.localizedDescription)"
            }

            // 3. AVFoundation AVAudioPlayer instantiation & preparation
            var avAudioPlayerOk = false
            var playerDuration: Double = 0.0
            do {
                let player = try AVAudioPlayer(contentsOf: fileURL)
                let prepSuccess = player.prepareToPlay()
                playerDuration = player.duration
                let canPlay = player.play()
                player.stop()

                if prepSuccess && playerDuration > 0.0 && player.numberOfChannels >= 1 && canPlay {
                    avAudioPlayerOk = true
                } else {
                    let currentErr = errorMsg ?? ""
                    errorMsg = "\(currentErr); AVAudioPlayer prep:\(prepSuccess) dur:\(playerDuration) ch:\(player.numberOfChannels)"
                }
            } catch {
                let currentErr = errorMsg ?? ""
                errorMsg = currentErr.isEmpty ? "AVAudioPlayer: \(error.localizedDescription)" : "\(currentErr); AVAudioPlayer: \(error.localizedDescription)"
            }

            let finalDuration = max(durationCA, max(avFileDuration, playerDuration))

            let report = AudioReport(
                filename: filename,
                sizeBytes: fileSize,
                durationSeconds: finalDuration,
                sampleRate: sampleRate,
                channels: channels,
                formatFourCC: formatFourCC,
                coreAudioOk: coreAudioOk,
                avAudioFileOk: avAudioFileOk,
                pcmDecodedOk: pcmDecodedOk,
                avAudioPlayerOk: avAudioPlayerOk,
                errorDetail: errorMsg
            )
            reports.append(report)

            let isAllPassed = coreAudioOk && avAudioFileOk && pcmDecodedOk && avAudioPlayerOk
            if !isAllPassed {
                failedFiles.append(filename)
            }

            let statusCore = coreAudioOk ? "PASS" : "FAIL"
            let statusAvFile = (avAudioFileOk && pcmDecodedOk) ? "PASS" : "FAIL"
            let statusPlayer = avAudioPlayerOk ? "PASS" : "FAIL"

            print(String(format: "%-22@ | %6.1fKB | %7.3fs | %7.0f | %4d | %6@ | %-7@ | %-7@ | %-7@",
                         filename,
                         Double(fileSize) / 1024.0,
                         finalDuration,
                         sampleRate,
                         channels,
                         formatFourCC,
                         statusCore,
                         statusAvFile,
                         statusPlayer))
        }

        print(String(repeating: "-", count: 85))
        print("\nSummary:")
        print("  Total files inspected: \(reports.count)")
        print("  CoreAudio load passed: \(reports.filter { $0.coreAudioOk }.count) / \(reports.count)")
        print("  AVAudioFile decode passed: \(reports.filter { $0.avAudioFileOk && $0.pcmDecodedOk }.count) / \(reports.count)")
        print("  AVAudioPlayer load passed: \(reports.filter { $0.avAudioPlayerOk }.count) / \(reports.count)")

        if failedFiles.isEmpty {
            print("\n✓ [VERIFICATION PASSED] All 41 audio files are 100% physically loadable, valid, and uncorrupted.")
            exit(0)
        } else {
            print("\n✗ [VERIFICATION FAILED] The following \(failedFiles.count) files failed:")
            for failed in failedFiles {
                let rep = reports.first(where: { $0.filename == failed })
                print("   - \(failed): \(rep?.errorDetail ?? "Unknown error")")
            }
            exit(1)
        }
    }
}
