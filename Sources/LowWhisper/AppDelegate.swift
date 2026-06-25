import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, AudioEngineManagerDelegate, EventTapManagerDelegate, MenuBarManagerDelegate, URLSessionDownloadDelegate {
    
    private var whisperWrapper = WhisperWrapper()
    private var audioEngine = AudioEngineManager()
    private var eventTap = EventTapManager()
    private var textInjector = TextInjector()
    
    private var menuBar: MenuBarManager?
    private var overlayWindow: FloatingOverlayWindow?
    
    private var selectedLanguage = "fr"
    private var modelName = "ggml-base.bin"
    private var isModelLoaded = false
    
    // Model download task
    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("LowWhisper: Application launched.")
        
        // 1. Initialize UI Elements
        menuBar = MenuBarManager()
        menuBar?.delegate = self
        
        overlayWindow = FloatingOverlayWindow()
        
        // 2. Setup delegates
        audioEngine.delegate = self
        eventTap.delegate = self
        
        // 3. Verify Accessibility Permissions & Start Event Tap
        checkPermissionsAndStartTap()
        
        // 4. Setup Model Directory & Load Model
        setupModelAndLoad()
    }
    
    private func checkPermissionsAndStartTap() {
        let trusted = eventTap.isTrusted()
        menuBar?.updateState(isModelLoaded: isModelLoaded, modelName: modelName, isAccessibilityTrusted: trusted)
        
        if trusted {
            _ = eventTap.start()
        } else {
            // Keep window hidden, wait for user to enable it from menu bar
            print("LowWhisper: Accessibility permissions not trusted yet.")
        }
    }
    
    // MARK: - Model Setup & Download
    
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let lowWhisperFolder = appSupport.appendingPathComponent("LowWhisper", isDirectory: true)
        let modelsFolder = lowWhisperFolder.appendingPathComponent("models", isDirectory: true)
        
        // Ensure folders exist
        try? FileManager.default.createDirectory(at: modelsFolder, withIntermediateDirectories: true, attributes: nil)
        return modelsFolder
    }
    
    private var modelURL: URL {
        return modelsDirectory.appendingPathComponent(modelName)
    }
    
    private func setupModelAndLoad() {
        if FileManager.default.fileExists(atPath: modelURL.path) {
            loadModelAsync()
        } else {
            // Prompt download via the Floating Overlay Window
            overlayWindow?.show()
            overlayWindow?.updateState(.error("Installation du modèle (140 Mo)... 0%"))
            downloadModel()
        }
    }
    
    private func downloadModel() {
        // Hugging Face direct download link for ggml-base.bin
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelName)") else { return }
        
        let config = URLSessionConfiguration.default
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadTask = downloadSession?.downloadTask(with: url)
        downloadTask?.resume()
        print("LowWhisper: Starting model download from \(url.absoluteString)")
    }
    
    private func loadModelAsync() {
        let path = modelURL.path
        Task {
            do {
                try await whisperWrapper.loadModel(atPath: path)
                self.isModelLoaded = true
                self.menuBar?.updateState(isModelLoaded: true, modelName: self.modelName, isAccessibilityTrusted: self.eventTap.isTrusted())
                print("LowWhisper: Model loaded successfully.")
            } catch {
                print("LowWhisper: Failed to load model: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.overlayWindow?.show()
                    self.overlayWindow?.updateState(.error("Échec de chargement du modèle"))
                }
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let percent = Int(progress * 100)
        
        print("LowWhisper: Download progress: \(percent)%")
        overlayWindow?.updateState(.error("Téléchargement du modèle... \(percent)%"))
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destinationURL = modelURL
        
        do {
            // Remove item if it somehow exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            print("LowWhisper: Model downloaded to \(destinationURL.path)")
            
            DispatchQueue.main.async {
                self.overlayWindow?.updateState(.completed)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.overlayWindow?.hide()
                }
                self.loadModelAsync()
            }
        } catch {
            print("LowWhisper: Failed to save model: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.overlayWindow?.updateState(.error("Erreur de sauvegarde"))
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("LowWhisper: Download task failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.overlayWindow?.updateState(.error("Erreur de téléchargement"))
            }
        }
    }
    
    // MARK: - AudioEngineManagerDelegate
    
    func audioEngineDidStartRecording() {
        overlayWindow?.updateState(.listening(amplitude: 0.0))
        overlayWindow?.show()
    }
    
    func audioEngineDidRecordSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        
        // Calculate root-mean-square (RMS) for amplitude visualization
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sum / Float(samples.count))
        
        // Normalize and scale (whisper samples are Float32, typical speech ranges from 0.01 to 0.15 RMS)
        let normalized = CGFloat(max(0.0, min(1.0, rms * 8.0)))
        
        overlayWindow?.updateState(.listening(amplitude: normalized))
    }
    
    func audioEngineDidStopRecording(withFinalSamples samples: [Float]) {
        eventTap.setRecordingState(isRecording: false, mode: .none)
        overlayWindow?.updateState(.transcribing)
        
        Task { @MainActor in
            do {
                let transcription = try await whisperWrapper.transcribe(samples: samples, language: selectedLanguage)
                let cleaned = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("LowWhisper: Transcribed text: \"\(cleaned)\"")
                
                if !cleaned.isEmpty {
                    self.textInjector.injectText(cleaned)
                }
                
                overlayWindow?.updateState(.completed)
            } catch {
                print("LowWhisper: Transcription failed: \(error.localizedDescription)")
                overlayWindow?.updateState(.error("Échec de transcription"))
            }
            
            // Hide overlay after 1.2 seconds of displaying success/failure state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if !self.audioEngine.isRecordingAudio() {
                    self.overlayWindow?.hide()
                }
            }
        }
    }
    
    func audioEngineFailed(withError error: Error) {
        print("LowWhisper: Audio Engine error: \(error.localizedDescription)")
        overlayWindow?.updateState(.error("Erreur Micro"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.overlayWindow?.hide()
        }
    }
    
    // MARK: - EventTapManagerDelegate

    func eventTapGlobeKeyDidPressDown() {
        guard isModelLoaded else { return }
        audioEngine.startRecording()
    }
    
    func eventTapGlobeKeyDidReleaseUp() {
        audioEngine.stopRecording()
    }
    
    func eventTapGlobeKeyDidDoublePress() {
        guard isModelLoaded else { return }
        eventTap.setRecordingState(isRecording: true, mode: .toggle)
        if !audioEngine.isRecordingAudio() {
            audioEngine.startRecording()
        }
        // If PTT was already active, recording continues — we just locked it in toggle mode
    }
    
    func eventTapGlobeKeyDidTriggerStop() {
        audioEngine.stopRecording()
    }
    
    // MARK: - MenuBarManagerDelegate
    
    func menuBarDidChangeLanguage(_ languageCode: String) {
        self.selectedLanguage = languageCode
        print("LowWhisper: Dictation language changed to \(languageCode).")
    }
    
    func menuBarDidRequestPermissionCheck() {
        checkPermissionsAndStartTap()
        if !eventTap.isTrusted() {
            eventTap.requestAccessibilityPermission()
        }
    }
    
    func menuBarDidRequestQuit() {
        print("LowWhisper: Quitting...")
        NSApplication.shared.terminate(nil)
    }
}
