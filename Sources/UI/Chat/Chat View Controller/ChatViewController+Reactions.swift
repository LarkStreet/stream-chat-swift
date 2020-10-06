//
//  ChatViewController+Reactions.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 06/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatClient
import StreamChatCore
import SnapKit

/// A type for emoji reactions by reaction types.
public typealias EmojiReaction = (emoji: String, maxScore: Int)
public typealias EmojiReactionTypes = [String: EmojiReaction]

extension EmojiReactionTypes {
    func sorted(with preferredEmojiOrder: [String]) -> [Element] {
        sorted(by: {
            let lhsIndex = preferredEmojiOrder.firstIndex(of: $0.value.emoji)
            let rhsIndex = preferredEmojiOrder.firstIndex(of: $1.value.emoji)
            
            switch (lhsIndex, rhsIndex) {
            case (.some(let lhs), .some(let rhs)):
                return lhs < rhs
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return $0.value.emoji < $1.value.emoji
            }
        })
    }
}

extension ChatViewController {
    
    func update(cell: MessageTableViewCell, forReactionsIn message: Message) {
        cell.update(reactionsString: reactionsString(for: message)) { [weak self] cell, locationInView in
            self?.showReactions(from: cell, in: message, locationInView: locationInView)
        }
    }
    
    func reactionsString(for message: Message) -> String {
        guard !message.reactionScores.isEmpty else {
            return ""
        }
        
        let score = message.reactionScores
            .filter({ type, _ in self.emojiReactionTypes.keys.contains(type) })
            .values
            .reduce(0, { $0 + $1 })
        
        let reactionTypes = message.reactionScores.keys
        var emojies = ""
        
        emojiReactionTypes.forEach { type, emoji in
            if reactionTypes.contains(type) {
                emojies += emoji.emoji
            }
        }
        
        return emojies.appending(score.shortString())
    }
    
    func showReactions(from cell: UITableViewCell, in message: Message, locationInView: CGPoint) {
        if reactionsView != nil {
            reactionsView?.removeFromSuperview()
        }
        
        let messageId = message.id
        let reactionsView = ReactionsView(frame: .zero)
        reactionsView.onDismissAction = { [weak self] in
            self?.hideBackground()
        }
        reactionsView.backgroundColor = style.incomingMessage.reactionViewStyle.chatBackgroundColor
        reactionsView.reactionsView.backgroundColor = style.incomingMessage.reactionViewStyle.backgroundColor
  
        self.reactionsView = reactionsView
        
        guard let messageCell = cell as? MessageTableViewCell,
              let snapshot = messageCell.generatePreview() else { return }
        
        var statusBarHeight: CGFloat = 0
        
        if #available(iOS 13.0, *) {
            statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        }
        
        var convertedFrameinCell = messageCell.contentView.convert(snapshot.frame, to: tableView)
        var convertedFrame = tableView.convert(convertedFrameinCell, to: backgroundViewController.view)
    
        let position = CGPoint(x: convertedFrame.origin.x + locationInView.x, y: convertedFrame.origin.y + convertedFrame.size.height)
                
        snapshot.frame = convertedFrame
        reactionsView.addSubview(snapshot)
        
        showBackground()

        var frame = backgroundViewController.view.frame
                
        frame = CGRect(x: frame.origin.x, y: statusBarHeight, width: frame.width, height: frame.height - statusBarHeight)
        
        reactionsView.show(emojiReactionTypes: emojiReactionTypes,
                           at: position,
                           for: message,
                           with: preferredEmojiOrder, from: snapshot, in: frame) { [weak self] type, score in
            guard let self = self,
                let emojiReactionsType = self.emojiReactionTypes[type],
                let presenter = self.presenter,
                let messageIndex = self.presenter?.items.lastIndex(whereMessageId: messageId),
                let message = self.presenter?.items[messageIndex].message else {
                    return nil
            }
            
            let isRegular = emojiReactionsType.maxScore < 2
            self.reactionsView = nil
            let needsToDelete = isRegular && message.hasOwnReaction(type: type)
            let extraData = needsToDelete ? nil : presenter.reactionExtraDataCallback?(type, score, message.id)
            
            let actionReaction = needsToDelete
                ? message.rx.deleteReaction(type: type)
                : message.rx.addReaction(type: type, score: score, extraData: extraData)
            
            actionReaction
                .subscribe(onError: { [weak self] in self?.show(error: $0) })
                .disposed(by: self.disposeBag)
            
            return isRegular || !needsToDelete
        }
    }
    
    private func showBackground() {
        guard self.backgroundWindow == nil, let reactionsView = self.reactionsView  else { return }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .clear
        window.windowLevel = UIWindow.Level.alert + 1
        
        self.backgroundWindow = window
        self.backgroundWindow?.makeKeyAndVisible()
        
        backgroundViewController.view.addSubview(reactionsView)
        
        reactionsView.makeEdgesEqualToSuperview()

        self.backgroundWindow?.rootViewController = backgroundViewController
        
        let view = UIView(frame: .zero)
        reactionsView.insertSubview(view, at: 0)
        view.makeEdgesEqualToSuperview()
        
        view.rx.tapGesture()
            .when(.recognized)
            .subscribe(onNext: { [weak self] _ in
                self?.reactionsView?.dismiss()
            })
            .disposed(by: disposeBag)
    }
    
    private func hideBackground() {
        self.backgroundWindow?.resignKey()
        self.backgroundWindow = nil
    }
}
