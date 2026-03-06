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

private enum ConversationSearchState: Equatable {
    case idle
    case searching(generation: Int, matches: [String: ConversationSearchMatch])
    case completed(generation: Int, matches: [String: ConversationSearchMatch])

    var generation: Int? {
        switch self {
        case .idle:
            return nil
        case .searching(let generation, _), .completed(let generation, _):
            return generation
        }
    }

    var matches: [String: ConversationSearchMatch] {
        switch self {
        case .idle:
            return [:]
        case .searching(_, let matches), .completed(_, let matches):
            return matches
        }
    }

    var showsSearchDetails: Bool {
        if case .idle = self {
            return false
        }
        return true
    }

    var shouldShowEmptyResults: Bool {
        if case .completed(_, let matches) = self {
            return matches.isEmpty
        }
        return false
    }
}

struct HistoryConversationsListView: View {
    @EnvironmentObject var viewModel: ChatViewModelSwiftUIAdapter
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let isEmbeddedInPager: Bool
    @State private var renameConversation: ConversationRecord?
    @State private var renameTitle: String = ""
    @State private var showRenameAlert: Bool = false
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var searchState: ConversationSearchState = .idle

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
                        searchMatch: searchState.matches[conversation.id],
                        showsSearchDetails: searchState.showsSearchDetails
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
            resetSearchState()
        }
        .onChange(of: searchText) { newValue in
            scheduleSearch(newValue)
        }
        .onReceive(viewModel.$conversations) { _ in
            if !trimmedSearchText.isEmpty {
                scheduleSearch(trimmedSearchText)
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
        guard !trimmedSearchText.isEmpty else { return viewModel.conversations }

        let matchedConversations = ConversationSearchRanking.sort(
            conversations: viewModel.conversations,
            matches: searchState.matches
        )
        if !matchedConversations.isEmpty {
            return matchedConversations
        }

        return searchState.shouldShowEmptyResults ? [] : viewModel.conversations
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
        if searchState.shouldShowEmptyResults && !trimmedSearchText.isEmpty && filteredConversations.isEmpty {
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

    private var trimmedSearchText: String {
        ConversationSearchKit.trimmedQuery(searchText)
    }

    private var nextSearchGeneration: Int {
        (searchState.generation ?? 0) + 1
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = ConversationSearchKit.trimmedQuery(query)
        if trimmed.isEmpty {
            clearSearch()
            return
        }

        let currentGeneration = nextSearchGeneration
        let titleMatches = viewModel.searchConversationTitles(query: trimmed)
        searchState = .searching(generation: currentGeneration, matches: titleMatches)

        searchTask = Task {
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed, generation: currentGeneration)
        }
    }

    private func performSearch(query: String, generation: Int) async {
        guard !Task.isCancelled else { return }
        let results = await viewModel.searchConversations(query: query)

        guard !Task.isCancelled else { return }
        await MainActor.run {
            guard let activeGeneration = searchState.generation,
                  activeGeneration == generation,
                  query == trimmedSearchText else {
                return
            }
            searchState = .completed(generation: generation, matches: results)
        }
    }

    private func clearSearch() {
        resetSearchState()
        searchText = ""
    }

    private func resetSearchState() {
        searchTask?.cancel()
        searchTask = nil
        searchState = .idle
    }
}

private struct ConversationRow: View {
    let conversation: ConversationRecord
    let searchMatch: ConversationSearchMatch?
    let showsSearchDetails: Bool

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

                if showsSearchDetails, let searchMatch, let snippet = searchMatch.snippet {
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

    private func highlightedText(_ text: String, ranges: [TextHighlightRange], baseFont: Font) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            guard let stringRange = makeRange(in: text, from: range),
                  let attrRange = Range(stringRange, in: attributed) else {
                continue
            }
            attributed[attrRange].foregroundColor = AppThemeSwift.accent
            attributed[attrRange].font = baseFont.weight(.semibold)
        }
        return attributed
    }

    private func makeRange(in text: String, from highlight: TextHighlightRange) -> Range<String.Index>? {
        guard highlight.start >= 0,
              highlight.length > 0,
              highlight.end <= text.count,
              let start = text.index(text.startIndex, offsetBy: highlight.start, limitedBy: text.endIndex),
              let end = text.index(start, offsetBy: highlight.length, limitedBy: text.endIndex) else {
            return nil
        }
        return start..<end
    }
}
