import SwiftUI
import AppKit
import MasterDockCore
import MasterDockServices
import MasterDockAI

/// Official Apple Intelligence Colorful Gradient Icon
public struct AppleIntelligenceGlyph: View {
    public var size: CGFloat = 16
    
    public static let gradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.42, blue: 0.28), // Coral / Orange
            Color(red: 0.96, green: 0.22, blue: 0.60), // Rose / Magenta
            Color(red: 0.68, green: 0.32, blue: 0.96), // Indigo / Purple
            Color(red: 0.22, green: 0.62, blue: 1.00)  // Sky / Cyan Blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public var body: some View {
        Image(systemName: "apple.intelligence")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Self.gradient)
    }
}

public struct AIChatSectionView: View {
    @Binding public var promptText: String
    @Binding public var conversation: [AIMessage]
    @Binding public var isStreaming: Bool
    public var onSendMessage: (String) -> Void
    public var onClear: () -> Void
    
    @State private var attachedFileURL: URL? = nil
    @FocusState private var isInputFocused: Bool
    
    public init(
        promptText: Binding<String>,
        conversation: Binding<[AIMessage]>,
        isStreaming: Binding<Bool>,
        onSendMessage: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) {
        self._promptText = promptText
        self._conversation = conversation
        self._isStreaming = isStreaming
        self.onSendMessage = onSendMessage
        self.onClear = onClear
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Apple Intelligence Header (Clean Title without duplicate icon)
            HStack {
                Text("Apple Intelligence")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !conversation.isEmpty {
                    Button(action: onClear) {
                        Text("Clear")
                            .font(AppTypography.captionBold)
                            .foregroundColor(GlassTheme.accentCyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Conversation preview area if messages exist
            if !conversation.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(conversation) { msg in
                                ChatMessageBubble(msg: msg)
                                    .id(msg.id)
                            }
                            
                            if isStreaming {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Apple Intelligence is thinking...")
                                        .font(AppTypography.caption)
                                        .foregroundColor(.white.opacity(0.65))
                                    Spacer()
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .background(
                            ScrollEdgeFadeObserver(fadeLength: 20.0, fadeThreshold: 14.0)
                        )
                    }
                    .frame(maxHeight: 180)
                    .onChange(of: conversation.count) { _, _ in
                        if let last = conversation.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Attached File Pill (if present)
            if let fileURL = attachedFileURL {
                HStack(spacing: 6) {
                    Image(systemName: iconForFile(url: fileURL))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GlassTheme.accentCyan)
                    
                    Text(fileURL.lastPathComponent)
                        .font(AppTypography.captionBold)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { attachedFileURL = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Text Input Box with Apple Intelligence Icon on Left & Plus Button on Right
            HStack(spacing: 8) {
                AppleIntelligenceGlyph(size: 15)
                
                TextField("Ask anything or attach a file...", text: $promptText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitPrompt()
                    }
                
                // Plus button to attach any file
                Button(action: chooseFileToAttach) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .help("Attach a file to chat (PDF, code, images, docs)")
                
                // Send button
                if !promptText.isEmpty || attachedFileURL != nil {
                    Button(action: submitPrompt) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(GlassTheme.accentBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .liquidPillStyle(cornerRadius: GlassTheme.pillRadius)
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func chooseFileToAttach() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select File to Attach to Apple Intelligence"
        
        if panel.runModal() == .OK, let url = panel.url {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.attachedFileURL = url
            }
        }
    }
    
    private func submitPrompt() {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || attachedFileURL != nil) && !isStreaming else { return }
        
        var finalMessage = text
        if let fileURL = attachedFileURL {
            let fileName = fileURL.lastPathComponent
            if let content = try? String(contentsOf: fileURL, encoding: .utf8), !content.isEmpty {
                let preview = content.count > 4000 ? String(content.prefix(4000)) + "\n...[truncated]" : content
                let promptIntro = text.isEmpty ? "Please analyze this attached file: \(fileName)" : text
                finalMessage = "\(promptIntro)\n\n📄 **Attached File (`\(fileName)`):**\n```\n\(preview)\n```"
            } else {
                let promptIntro = text.isEmpty ? "Please analyze this attached file: \(fileName)" : text
                finalMessage = "\(promptIntro)\n\n📄 **Attached File:** `\(fileName)` (Path: \(fileURL.path))"
            }
            self.attachedFileURL = nil
        }
        
        promptText = ""
        onSendMessage(finalMessage)
    }
    
    private func iconForFile(url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "json", "c", "cpp", "h", "html", "css":
            return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "heic", "webp", "gif":
            return "photo.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "txt", "md":
            return "doc.plaintext.fill"
        case "zip", "tar", "gz":
            return "archivebox.fill"
        default:
            return "doc.fill"
        }
    }
}

private struct ChatMessageBubble: View {
    let msg: AIMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == .user {
                Spacer()
                Text(msg.content)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(GlassTheme.accentBlue.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        AppleIntelligenceGlyph(size: 13)
                        Text("Apple Intelligence")
                            .font(AppTypography.captionBold)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Text(msg.content)
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.95))
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidPillStyle(cornerRadius: 14)
                Spacer()
            }
        }
    }
}

public struct AIVoiceOverlayView: View {
    @ObservedObject public var audioPipeline: AudioRecordingPipeline
    public var liveTranscript: String
    public var userPrompt: String
    public var aiResponseText: String
    public var isAIStreaming: Bool
    public var onClose: () -> Void
    public var onStopAndSend: () -> Void
    public var onStartRecording: () -> Void
    
    public init(
        audioPipeline: AudioRecordingPipeline,
        liveTranscript: String,
        userPrompt: String = "",
        aiResponseText: String,
        isAIStreaming: Bool = false,
        onClose: @escaping () -> Void,
        onStopAndSend: @escaping () -> Void,
        onStartRecording: @escaping () -> Void = {}
    ) {
        self.audioPipeline = audioPipeline
        self.liveTranscript = liveTranscript
        self.userPrompt = userPrompt
        self.aiResponseText = aiResponseText
        self.isAIStreaming = isAIStreaming
        self.onClose = onClose
        self.onStopAndSend = onStopAndSend
        self.onStartRecording = onStartRecording
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    AppleIntelligenceGlyph(size: 18)
                    Text("Apple Intelligence Voice")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            if audioPipeline.isRecording {
                // 1. ACTIVE LISTENING & RECORDING STATE
                Spacer()
                
                // Glowing Apple Intelligence Voice Indicator
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.42, blue: 0.28).opacity(Double(audioPipeline.averagePower) * 0.7 + 0.25),
                                    Color(red: 0.96, green: 0.22, blue: 0.60).opacity(0.35),
                                    Color(red: 0.68, green: 0.32, blue: 0.96).opacity(0.20),
                                    Color(red: 0.22, green: 0.62, blue: 1.00).opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 90
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(1.0 + CGFloat(audioPipeline.averagePower) * 0.3)
                        .animation(.easeInOut(duration: 0.12), value: audioPipeline.averagePower)
                    
                    Circle()
                        .fill(GlassTheme.pillGlassFill)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().strokeBorder(GlassTheme.liquidSpecularBorder, lineWidth: 1.2))
                    
                    AppleIntelligenceGlyph(size: 32)
                }
                
                // Live Dynamic Audio Waveform
                LiquidWaveformView(
                    levels: audioPipeline.audioLevels,
                    averagePower: audioPipeline.averagePower,
                    isRecording: true
                )
                .padding(.horizontal, 10)
                
                // Spoken Transcript Preview
                Text(liveTranscript.isEmpty ? "Listening... Speak your prompt naturally" : liveTranscript)
                    .font(AppTypography.titleMedium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .lineLimit(4)
                
                Spacer()
                
                // Recording Action Buttons
                HStack(spacing: 14) {
                    GlassButton(
                        title: "Done Speaking",
                        iconSystemName: "checkmark.circle.fill",
                        accentColor: GlassTheme.accentEmerald,
                        action: onStopAndSend
                    )
                    
                    GlassButton(
                        title: "Switch to Text",
                        iconSystemName: "keyboard",
                        action: onClose
                    )
                }
                .padding(.bottom, 6)
            } else {
                // 2. ANSWER PRESENTATION STATE (Audio engine stopped, displaying full response)
                VStack(spacing: 12) {
                    // User Question Card
                    if !userPrompt.isEmpty {
                        HStack {
                            Spacer()
                            Text(userPrompt)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(GlassTheme.accentBlue.opacity(0.85))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                                )
                        }
                    }
                    
                    // Full Apple Intelligence Response (Uncut, Scrollable)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            AppleIntelligenceGlyph(size: 14)
                            Text("Apple Intelligence")
                                .font(AppTypography.captionBold)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            if isAIStreaming {
                                HStack(spacing: 4) {
                                    ProgressView().scaleEffect(0.5)
                                    Text("Generating...")
                                        .font(AppTypography.micro)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(aiResponseText.isEmpty ? (isAIStreaming ? "Thinking..." : "No response generated.") : aiResponseText)
                                .font(AppTypography.body)
                                .foregroundColor(.white.opacity(0.95))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(.vertical, 4)
                                .background(
                                    ScrollEdgeFadeObserver(fadeLength: 18.0, fadeThreshold: 15.0)
                                )
                        }
                        .frame(maxHeight: 280)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                }
                
                Spacer()
                
                // Answered Action Buttons
                HStack(spacing: 14) {
                    GlassButton(
                        title: "Ask Another",
                        iconSystemName: "mic.fill",
                        accentColor: GlassTheme.accentBlue,
                        action: onStartRecording
                    )
                    
                    GlassButton(
                        title: "Done",
                        iconSystemName: "checkmark",
                        action: onClose
                    )
                }
                .padding(.bottom, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
