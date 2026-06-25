import SwiftUI
import AppKit

public enum DictationState: Equatable {
    case idle
    case listening(amplitude: CGFloat)
    case transcribing
    case completed
    case error(String)
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct FloatingOverlayView: View {
    let state: DictationState
    
    public var body: some View {
        HStack(spacing: 16) {
            statusIcon
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                
                Text(statusSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .listening(let amplitude):
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .scaleEffect(1.0 + amplitude * 1.5)
                    .animation(.easeOut(duration: 0.1), value: amplitude)
                
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14, weight: .bold))
            }
        case .transcribing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20, weight: .semibold))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20, weight: .semibold))
        case .idle:
            Image(systemName: "waveform")
                .foregroundColor(.gray)
                .font(.system(size: 16))
        }
    }
    
    private var statusTitle: String {
        switch state {
        case .listening:
            return "Dictée en cours"
        case .transcribing:
            return "Transcription"
        case .completed:
            return "Inséré"
        case .error:
            return "Erreur"
        case .idle:
            return "Prêt"
        }
    }
    
    private var statusSubtitle: String {
        switch state {
        case .listening:
            return "Parlez maintenant..."
        case .transcribing:
            return "Génération du texte..."
        case .completed:
            return "Texte injecté avec succès"
        case .error(let message):
            return message
        case .idle:
            return "En attente du raccourci"
        }
    }
}

public class FloatingOverlayWindow: NSWindow {
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating
        self.ignoresMouseEvents = true // Pass mouse clicks through the window
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        positionWindowAtBottomCenter()
    }
    
    public func updateState(_ state: DictationState) {
        // Run on main thread to update SwiftUI hosting view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let contentView = NSHostingView(rootView: FloatingOverlayView(state: state))
            contentView.frame = self.contentRect(forFrameRect: self.frame)
            self.contentView = contentView
            
            // Adjust size to fit contents automatically
            let fittingSize = contentView.fittingSize
            var newFrame = self.frame
            newFrame.size = fittingSize
            self.setFrame(newFrame, display: true)
            self.positionWindowAtBottomCenter()
        }
    }
    
    private func positionWindowAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.size.width - self.frame.size.width) / 2
        let y = screenFrame.origin.y + 120 // 120px above the dock / bottom screen boundary
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    public func show() {
        DispatchQueue.main.async {
            self.orderFrontRegardless()
        }
    }
    
    public func hide() {
        DispatchQueue.main.async {
            self.orderOut(nil)
        }
    }
}

// Preview provider for design review
struct FloatingOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FloatingOverlayView(state: .idle)
            FloatingOverlayView(state: .listening(amplitude: 0.3))
            FloatingOverlayView(state: .transcribing)
            FloatingOverlayView(state: .completed)
            FloatingOverlayView(state: .error("Pas de micro trouvé"))
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
