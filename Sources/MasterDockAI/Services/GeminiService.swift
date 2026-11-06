import Foundation

public final class GeminiService: AIServiceProtocol, @unchecked Sendable {
    public let provider: AIProvider = .gemini
    private let apiKey: String
    private let model: String
    
    public init(apiKey: String, model: String = "gemini-1.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse") else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                // Send the key in a header, not the web address, so it never shows up in logs.
                request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                
                var contents: [[String: Any]] = []
                for msg in conversationHistory {
                    contents.append([
                        "role": msg.role == .user ? "user" : "model",
                        "parts": [["text": msg.content]]
                    ])
                }
                contents.append([
                    "role": "user",
                    "parts": [["text": prompt]]
                ])
                
                let body: [String: Any] = ["contents": contents]
                guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: URLError(.cannotDecodeContentData))
                    return
                }
                request.httpBody = httpBody
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.yield("⚠️ Google Gemini API Error: Check API key.")
                        continuation.finish()
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let candidates = json["candidates"] as? [[String: Any]],
                               let content = candidates.first?["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let text = parts.first?["text"] as? String {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

public final class LocalOllamaService: AIServiceProtocol, @unchecked Sendable {
    public let provider: AIProvider = .ollama
    private let hostURL: URL
    private let model: String
    
    public init(host: String = "http://localhost:11434", model: String = "llama3") {
        self.hostURL = URL(string: host) ?? URL(string: "http://localhost:11434")!
        self.model = model
    }
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let url = hostURL.appendingPathComponent("api/generate")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "model": model,
                    "prompt": prompt,
                    "stream": true
                ]
                
                guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: URLError(.cannotDecodeContentData))
                    return
                }
                request.httpBody = httpBody
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.yield("⚠️ Local Ollama is not responding at localhost:11434.")
                        continuation.finish()
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let chunk = json["response"] as? String {
                            continuation.yield(chunk)
                            if let done = json["done"] as? Bool, done {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
