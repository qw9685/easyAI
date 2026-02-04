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
    @EnvironmentObject var viewModel: ChatViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var renameConversation: ConversationRecord?
    @State private var renameTitle: String = ""
    @State private var showRenameAlert: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.conversations, id: \.id) { conversation in
                    Button {
                        guard !viewModel.isSwitchingConversation else { return }
                        Task {
                            await viewModel.selectConversationAfterLoaded(id: conversation.id)
                            dismiss()
                        }
                    } label: {
                        ConversationRow(conversation: conversation,
                                        isCurrent: conversation.id == viewModel.currentConversationId)
                    }
                    .disabled(viewModel.isSwitchingConversation)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            renameConversation = conversation
                            renameTitle = conversation.title
                            showRenameAlert = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button {
                            viewModel.setPinned(id: conversation.id, isPinned: !conversation.isPinned)
                        } label: {
                            Label(conversation.isPinned ? "取消置顶" : "置顶",
                                  systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                        Button(role: .destructive) {
                            viewModel.deleteConversation(id: conversation.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .listRowBackground(AppThemeSwift.surface)
                }
            }
            .overlay(emptyStateView)
            .scrollContentBackground(.hidden)
            .background(AppThemeSwift.backgroundGradient)
            .listRowSeparatorTint(AppThemeSwift.border)
            .tint(AppThemeSwift.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("会话")
                        .font(AppThemeSwift.titleFont)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.startNewConversation()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadConversations()
            }
            .alert("重命名", isPresented: $showRenameAlert) {
                TextField("标题", text: $renameTitle)
                Button("取消", role: .cancel) {
                    renameConversation = nil
                    showRenameAlert = false
                }
                Button("保存") {
                    if let conversation = renameConversation {
                        viewModel.renameConversation(id: conversation.id, title: renameTitle)
                    }
                    renameConversation = nil
                    showRenameAlert = false
                }
            } message: {
                Text("输入新的会话名称")
            }
        }
        .id(themeManager.selection)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.conversations.isEmpty {
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
}

private struct ConversationRow: View {
    let conversation: ConversationRecord
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: conversation.isPinned ? "pin.fill" : "message")
                .foregroundColor(conversation.isPinned ? AppThemeSwift.accent : AppThemeSwift.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.headline)
                    .foregroundColor(AppThemeSwift.textPrimary)
                Text(conversation.updatedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(AppThemeSwift.textTertiary)
            }
            Spacer()

            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppThemeSwift.accent)
            }
        }
    }
}
