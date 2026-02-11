//
//  HistoryConversationsListView.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 历史会话列表与管理界面
//
//


import SwiftUI

struct HistoryConversationsListView: View {
    @EnvironmentObject var viewModel: ChatViewModelSwiftUIAdapter
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let isEmbeddedInPager: Bool
    @State private var renameConversation: ConversationRecord?
    @State private var renameTitle: String = ""
    @State private var showRenameAlert: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [String: ConversationSearchMatch] = [:]
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching: Bool = false

    init(isEmbeddedInPager: Bool = false) {
        self.isEmbeddedInPager = isEmbeddedInPager
    }
    
    var body: some View {
        Group {
            if isEmbeddedInPager {
                content
            } else {
                NavigationView {
                    content
                        .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .principal) {
                        Text("会话")
                            .font(AppThemeSwift.titleFont)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.dispatch(.startNewConversation)
                            dismiss()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .id(themeManager.selection)
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            List {
                ForEach(filteredConversations, id: \.id) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        searchMatch: searchResults[conversation.id],
                        isSearching: isSearching
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(AppThemeSwift.surface)
                    .cornerRadius(14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !viewModel.isSwitchingConversation else { return }
                        Task {
                            await viewModel.selectConversationAfterLoaded(id: conversation.id)
                            await MainActor.run {
                                clearSearch()
                            }
                            viewModel.emitEvent(.switchToChat)
                        }
                    }
                    .allowsHitTesting(!viewModel.isSwitchingConversation)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            renameConversation = conversation
                            renameTitle = conversation.title
                            showRenameAlert = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button {
                            viewModel.dispatch(.setPinned(id: conversation.id, isPinned: !conversation.isPinned))
                        } label: {
                            Label(conversation.isPinned ? "取消置顶" : "置顶",
                                  systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                        Button(role: .destructive) {
                            viewModel.dispatch(.deleteConversation(conversation.id))
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
        }
        .overlay(emptyStateView)
        .scrollContentBackground(.hidden)
        .background(AppThemeSwift.backgroundGradient)
        .listRowSeparatorTint(AppThemeSwift.border)
        .tint(AppThemeSwift.accent)
        .onAppear {
            viewModel.dispatch(.loadConversations)
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
            isSearching = false
        }
        .onChange(of: searchText) { newValue in
            scheduleSearch(newValue)
        }
        .onReceive(viewModel.$conversations) { _ in
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                scheduleSearch(trimmed)
            }
        }
        .alert("重命名", isPresented: $showRenameAlert) {
            TextField("标题", text: $renameTitle)
            Button("取消", role: .cancel) {
                renameConversation = nil
                showRenameAlert = false
            }
            Button("保存") {
                if let conversation = renameConversation {
                    viewModel.dispatch(.renameConversation(id: conversation.id, title: renameTitle))
                }
                renameConversation = nil
                showRenameAlert = false
            }
        } message: {
            Text("输入新的会话名称")
        }
    }

    private var filteredConversations: [ConversationRecord] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.conversations }
        return viewModel.conversations.filter { searchResults[$0.id] != nil }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppThemeSwift.textTertiary)
            TextField("搜索会话或消息内容", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppThemeSwift.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppThemeSwift.border, lineWidth: 0.8)
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if isSearching && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredConversations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(AppThemeSwift.textSecondary)
                Text("没有匹配结果")
                    .font(.headline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Text("试试更短的关键词或更换搜索内容")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }
            .padding(.top, 40)
        } else if viewModel.conversations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "message")
                    .font(.system(size: 40))
                    .foregroundColor(AppThemeSwift.textSecondary)
                Text("暂无会话")
                    .font(.headline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Text("开始聊天后，会话会显示在这里")
                    .font(.subheadline)
                    .foregroundColor(AppThemeSwift.textSecondary)
            }
            .padding(.top, 40)
        }
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearSearch()
            return
        }
        isSearching = true
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    private func performSearch(query: String) async {
        guard !Task.isCancelled else { return }
        var results: [String: ConversationSearchMatch] = [:]

        let conversations = await MainActor.run { viewModel.conversations }
        for conversation in conversations {
            let titleRanges = findRanges(in: conversation.title, query: query)
            var snippet: String?
            var snippetRanges: [Range<String.Index>] = []

            if titleRanges.isEmpty {
                let conversationId = conversation.id
                let messages = await fetchRecentMessagesInBackground(conversationId: conversationId, limit: 200)
                if let messages {
                    for message in messages {
                        let ranges = findRanges(in: message.content, query: query)
                        if let first = ranges.first {
                            let snippetResult = makeSnippet(text: message.content, matchRange: first)
                            snippet = snippetResult.snippet
                            snippetRanges = snippetResult.ranges
                            break
                        }
                    }
                }
            }

            if !titleRanges.isEmpty || snippet != nil {
                results[conversation.id] = ConversationSearchMatch(
                    titleRanges: titleRanges,
                    snippet: snippet,
                    snippetRanges: snippetRanges
                )
            }

            if Task.isCancelled {
                return
            }
        }

        guard !Task.isCancelled else { return }
        await MainActor.run {
            searchResults = results
        }
    }

    private func findRanges(in text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
              ) {
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }

    private func makeSnippet(text: String, matchRange: Range<String.Index>) -> (snippet: String, ranges: [Range<String.Index>]) {
        let contextLength = 24
        let startOffset = text.distance(from: text.startIndex, to: matchRange.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: matchRange.upperBound)

        let snippetStartOffset = max(0, startOffset - contextLength)
        let snippetEndOffset = min(text.count, endOffset + contextLength)

        let snippetStart = text.index(text.startIndex, offsetBy: snippetStartOffset)
        let snippetEnd = text.index(text.startIndex, offsetBy: snippetEndOffset)
        let snippet = String(text[snippetStart..<snippetEnd])

        let highlightStart = snippet.index(snippet.startIndex, offsetBy: startOffset - snippetStartOffset)
        let highlightEnd = snippet.index(snippet.startIndex, offsetBy: endOffset - snippetStartOffset)
        let ranges = [highlightStart..<highlightEnd]

        return (snippet, ranges)
    }

    private func clearSearch() {
        searchText = ""
        searchResults = [:]
        isSearching = false
    }

    private func fetchRecentMessagesInBackground(conversationId: String, limit: Int) async -> [Message]? {
        await RuntimeTools.AsyncExecutor.run {
            try? MessageRepository.shared.fetchRecentMessages(
                conversationId: conversationId,
                limit: limit
            )
        }
    }
}

private struct ConversationSearchMatch {
    let titleRanges: [Range<String.Index>]
    let snippet: String?
    let snippetRanges: [Range<String.Index>]
}

private struct ConversationRow: View {
    let conversation: ConversationRecord
    let searchMatch: ConversationSearchMatch?
    let isSearching: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: conversation.isPinned ? "pin.fill" : "message")
                .foregroundColor(conversation.isPinned ? AppThemeSwift.accent : AppThemeSwift.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                if let searchMatch {
                    Text(highlightedText(conversation.title, ranges: searchMatch.titleRanges, baseFont: .headline))
                        .foregroundColor(AppThemeSwift.textPrimary)
                } else {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(AppThemeSwift.textPrimary)
                }

                if isSearching, let searchMatch, let snippet = searchMatch.snippet {
                    Text(highlightedText(snippet, ranges: searchMatch.snippetRanges, baseFont: .caption))
                        .font(.caption)
                        .foregroundColor(AppThemeSwift.textSecondary)
                        .lineLimit(2)
                } else {
                    Text(conversation.updatedAt, style: .time)
                        .font(.caption)
                        .foregroundColor(AppThemeSwift.textTertiary)
                }
            }
            Spacer()
        }
    }

    private func highlightedText(_ text: String, ranges: [Range<String.Index>], baseFont: Font) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = AppThemeSwift.accent
                attributed[attrRange].font = baseFont.weight(.semibold)
            }
        }
        return attributed
    }
}
