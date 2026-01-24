import SwiftUI

/// Transcription history window
/// Shows past transcriptions with copy functionality
struct HistoryView: View {
    @ObservedObject var historyManager: TranscriptionHistoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var copiedId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Search
            searchSection
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // List
            if filteredItems.isEmpty {
                emptyState
            } else {
                listSection
            }
            
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
            
            // Footer
            footerSection
        }
        .frame(width: 480, height: 520)
        .background(Theme.Colors.background)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcription History")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(historyManager.items.count) transcriptions")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.secondaryBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
    }
    
    // MARK: - Search
    
    private var searchSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
            
            TextField("Search transcriptions...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textPrimary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
    }
    
    // MARK: - List
    
    private var filteredItems: [TranscriptionHistoryItem] {
        if searchText.isEmpty {
            return historyManager.items
        }
        return historyManager.items.filter { 
            $0.text.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    HistoryItemRow(
                        item: item,
                        isCopied: copiedId == item.id,
                        onCopy: { copyItem(item) },
                        onDelete: { historyManager.remove(item) }
                    )
                    
                    Rectangle().fill(Theme.Colors.border).frame(height: 1)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            ZStack {
                Rectangle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 64, height: 64)
                
                Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            VStack(spacing: Theme.Spacing.xs) {
                Text(searchText.isEmpty ? "No History Yet" : "No Results")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(searchText.isEmpty 
                     ? "Your transcriptions will appear here" 
                     : "Try a different search term")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        HStack {
            if !historyManager.items.isEmpty {
                Button("Clear All") {
                    historyManager.clearAll()
                }
                .buttonStyle(.sharpDanger)
            }
            
            Spacer()
            
            Text("History is stored locally")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
    }
    
    // MARK: - Actions
    
    private func copyItem(_ item: TranscriptionHistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        
        copiedId = item.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == item.id {
                copiedId = nil
            }
        }
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: TranscriptionHistoryItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Timestamp indicator
            Rectangle()
                .fill(Theme.Colors.sharpGreen)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Timestamp
                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                // Text
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Duration
                if let duration = item.audioDuration {
                    Text(String(format: "%.1fs audio", duration))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            
            Spacer()
            
            // Actions
            if isHovering || isCopied {
                HStack(spacing: 4) {
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                            Text(isCopied ? "COPIED" : "COPY")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(isCopied ? Theme.Colors.sharpGreen : Theme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isCopied ? Theme.Colors.lightGreen : Theme.Colors.secondaryBackground)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.error)
                            .padding(6)
                            .background(Theme.Colors.secondaryBackground)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, Theme.Spacing.md)
            }
        }
        .frame(minHeight: 60)
        .background(isHovering ? Theme.Colors.secondaryBackground : Theme.Colors.background)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    let manager = TranscriptionHistoryManager()
    manager.add(text: "Hello, this is a test transcription.", duration: 2.5)
    manager.add(text: "Another transcription that is a bit longer and might wrap to multiple lines.", duration: 4.2)
    manager.add(text: "Short one.", duration: 0.8)
    
    return HistoryView(historyManager: manager)
}
