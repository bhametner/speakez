import Foundation

// MARK: - Transcription History Item

struct TranscriptionHistoryItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let audioDuration: Double?
    
    init(text: String, duration: Double? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.audioDuration = duration
    }
}

// MARK: - Transcription History Manager

class TranscriptionHistoryManager: ObservableObject {
    @Published private(set) var items: [TranscriptionHistoryItem] = []
    
    private let maxItems = 100
    private let storageKey = "transcriptionHistory"
    
    init() {
        load()
    }
    
    // MARK: - Public Methods
    
    /// Add a new transcription to history
    func add(text: String, duration: Double? = nil) {
        let item = TranscriptionHistoryItem(text: text, duration: duration)
        items.insert(item, at: 0)
        
        // Trim to max items
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        
        save()
    }
    
    /// Remove a specific item
    func remove(_ item: TranscriptionHistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }
    
    /// Clear all history
    func clearAll() {
        items.removeAll()
        save()
    }
    
    /// Get the most recent transcription
    var lastTranscription: TranscriptionHistoryItem? {
        items.first
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("TranscriptionHistory: Failed to save - \(error)")
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            items = try JSONDecoder().decode([TranscriptionHistoryItem].self, from: data)
        } catch {
            print("TranscriptionHistory: Failed to load - \(error)")
        }
    }
}
