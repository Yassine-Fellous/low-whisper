import Foundation
import AVFoundation

public protocol AudioEngineManagerDelegate: AnyObject {
    func audioEngineDidStartRecording()
    func audioEngineDidRecordSamples(_ samples: [Float])
    func audioEngineDidStopRecording(withFinalSamples samples: [Float])
    func audioEngineFailed(withError error: Error)
}

public class AudioEngineManager: NSObject {
    private let audioEngine = AVAudioEngine()
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private var audioConverter: AVAudioConverter?
    
    private var recordedSamples: [Float] = []
    private var isRecording = false
    
    public weak var delegate: AudioEngineManagerDelegate?
    
    public override init() {
        super.init()
        setupAudioFormat()
    }
    
    private func setupAudioFormat() {
        // Output format required by Whisper (16kHz, 1 channel, Float32 PCM)
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
    }
    
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    public func startRecording() {
        guard !isRecording else { return }
        
        requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.delegate?.audioEngineFailed(withError: NSError(domain: "LowWhisper.AudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]))
                return
            }
            
            self.performStartRecording()
        }
    }
    
    private func performStartRecording() {
        recordedSamples.removeAll()
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        self.inputFormat = inputFormat
        
        guard let outputFormat = self.outputFormat else {
            self.delegate?.audioEngineFailed(withError: NSError(domain: "LowWhisper.AudioEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize output format"]))
            return
        }
        
        // Initialize sample rate converter
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            self.delegate?.audioEngineFailed(withError: NSError(domain: "LowWhisper.AudioEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"]))
            return
        }
        self.audioConverter = converter
        
        // Reset and prepare engine
        audioEngine.reset()
        
        // Tap the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            delegate?.audioEngineDidStartRecording()
            print("AudioEngine successfully started recording.")
        } catch {
            inputNode.removeTap(onBus: 0)
            delegate?.audioEngineFailed(withError: error)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter, let outputFormat = outputFormat else { return }
        
        // Calculate the frame capacity needed for conversion
        let ratio = 16000.0 / buffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: targetCapacity) else {
            print("AudioEngine: Failed to allocate output buffer.")
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            print("AudioEngine: Conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        if let floatData = outputBuffer.floatChannelData {
            let frameLength = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
            
            recordedSamples.append(contentsOf: samples)
            delegate?.audioEngineDidRecordSamples(samples)
        }
    }
    
    public func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        
        delegate?.audioEngineDidStopRecording(withFinalSamples: recordedSamples)
        print("AudioEngine stopped. Captured \(recordedSamples.count) samples (~\(Double(recordedSamples.count)/16000.0) seconds).")
    }
    
    public func isRecordingAudio() -> Bool {
        return isRecording
    }
}
