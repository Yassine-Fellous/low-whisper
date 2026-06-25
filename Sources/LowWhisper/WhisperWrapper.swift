import Foundation
import whisper

public enum WhisperError: Error {
    case couldNotInitializeContext
    case inferenceFailed
    case modelFileNotFound
}

public actor WhisperWrapper {
    private var context: OpaquePointer?
    private var isLoaded = false

    public init() {}

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    /// Loads the Whisper model from a given file path.
    /// Enables Metal GPU acceleration.
    public func loadModel(atPath path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw WhisperError.modelFileNotFound
        }

        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true

        guard let context = whisper_init_from_file_with_params(path, params) else {
            throw WhisperError.couldNotInitializeContext
        }

        self.context = context
        self.isLoaded = true
        print("Whisper model successfully loaded from \(path) with GPU acceleration.")
    }

    public func isModelLoaded() -> Bool {
        return isLoaded
    }

    /// Transcribes 16kHz mono PCM Float32 audio samples.
    public func transcribe(samples: [Float], language: String = "fr") throws -> String {
        guard let context = self.context, isLoaded else {
            throw WhisperError.couldNotInitializeContext
        }

        let cpuCount = ProcessInfo.processInfo.processorCount
        // Leave 2 cores free for macOS system processes
        let threads = max(1, min(8, cpuCount - 2))
        
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(threads)
        params.no_context = true
        params.single_segment = false

        // Pass language code as C string
        let langCode = language.lowercased()
        let cLanguage = (langCode as NSString).utf8String

        params.language = cLanguage

        let status = samples.withUnsafeBufferPointer { buffer -> Int32 in
            return whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }

        guard status == 0 else {
            throw WhisperError.inferenceFailed
        }

        var transcription = ""
        let segmentCount = whisper_full_n_segments(context)
        for i in 0..<segmentCount {
            if let text = whisper_full_get_segment_text(context, i) {
                transcription += String(cString: text)
            }
        }

        return transcription
    }
}
