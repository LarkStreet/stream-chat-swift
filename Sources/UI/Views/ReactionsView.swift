//
//  ReactionsView.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 06/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatClient
import StreamChatCore
import SnapKit
import RxSwift
import RxCocoa
import RxGesture

final class ReactionsView: UIView {
    typealias Completion = (_ selectedType: String, _ score: Int) -> Bool?
    
    var onDismissAction: (() -> Void)?
    
    private let disposeBag = DisposeBag()
    
    private lazy var avatarsStackView = createAvatarsStackView()
    private lazy var emojiesStackView = cerateEmojiesStackView()
    private lazy var labelsStackView = createLabelsStackView()
    private var emojiReactionTypes: EmojiReactionTypes = [:]
    private var reactionScores: [String: Int] = [:]

    private var selectedView: UIView?
    
    private(set) lazy var reactionsView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = true
        view.layer.cornerRadius = .reactionsPickerCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: .reactionsPickerShadowOffsetY)
        view.layer.shadowRadius = .reactionsPickerShadowRadius
        view.layer.shadowOpacity = Float(CGFloat.reactionsPickerShdowOpacity)
        return view
    }()
    
    func show(emojiReactionTypes: EmojiReactionTypes,
              at point: CGPoint,
              for message: Message,
              with preferredEmojiOrder: [String],
              from selectedView: UIView,
              in frame: CGRect,
              completion: @escaping Completion) {
        
        self.selectedView = selectedView
        addSubview(reactionsView)
        
        self.emojiReactionTypes = emojiReactionTypes
        reactionScores = message.reactionScores
        
        let itemsCount = CGFloat(emojiReactionTypes.count)
        
        let calculatedWidth: CGFloat = itemsCount > 1
            ? itemsCount * (.reactionsPickerButtonWidth + .messageInnerPadding) + .reactionsPickerCornerRadius
            : .reactionsPickerCornerHeight
        
        let width = min(calculatedWidth, .attachmentPreviewMaxWidth)
        
        let x = min(max(point.x - width / 2, .messageTextPaddingWithAvatar),
                    .minScreenWidth - width - .messageTextPaddingWithAvatar)
        
        var yPozition = selectedView.frame.maxY + .messageVerticalInset
        
        let y = max(safeAreaTopOffset + .reactionsPickerAvatarRadius + .messageEdgePadding,
                    point.y - .reactionsPickerCornerRadius)
        
        reactionsView.frame = CGRect(x: x, y: yPozition, width: width, height: .reactionsPickerCornerHeight)
        
        reactionsView.transform = .init(scaleX: 0.5, y: 0.5)
        alpha = 0
        
        emojiReactionTypes.sorted(with: preferredEmojiOrder).forEach { (reactionType, emoji) in
            let users = message.latestReactions.filter({ $0.type == reactionType }).compactMap({ $0.user })
            let reaction: Reaction
            let score = message.reactionScores[reactionType] ?? 0
            
            if let ownReaction = message.ownReactions.first(where: { $0.type == reactionType }) {
                reaction = ownReaction
            } else {
                reaction = Reaction(type: reactionType, score: score, messageId: message.id)
            }
            
            let emojiView = createEmojiView(emoji: emoji.emoji,
                                            maxScore: emoji.maxScore,
                                            reaction: reaction,
                                            completion: completion)
            
            avatarsStackView.addArrangedSubview(createAvatarView(users))
            emojiesStackView.addArrangedSubview(emojiView)
            labelsStackView.addArrangedSubview(createLabel(score))
        }
        
        let translationX: CGFloat = message.isOwn ? -.messageVerticalInset : .messageVerticalInset
        
        var translationY: CGFloat = 0
        
        if reactionsView.frame.maxY > frame.height {
            translationY = -(reactionsView.frame.maxY - frame.height + .messageVerticalInset)
        }
        
        if selectedView.frame.minY < frame.minY {
            translationY = abs(frame.minY - selectedView.frame.minY + .messageVerticalInset)
        }
                
        UIView.animateSmoothly(withDuration: 0.3, usingSpringWithDamping: 0.65) {
            self.alpha = 1
            self.reactionsView.transform = .identity
            selectedView.transform = .init(scaleX: 1.1, y: 1.1)
            selectedView.transform = .init(translationX: translationX, y: translationY)
            self.reactionsView.transform = .init(translationX: translationX, y: translationY)
        }
    }
    
    func update(with message: Message) {
        avatarsStackView.removeAllArrangedSubviews()
        labelsStackView.removeAllArrangedSubviews()
        
        emojiReactionTypes.forEach { reactionType, _ in
            let users = message.latestReactions.filter({ $0.type == reactionType }).compactMap({ $0.user })
            avatarsStackView.addArrangedSubview(createAvatarView(users))
            labelsStackView.addArrangedSubview(createLabel(message.reactionScores[reactionType] ?? 0))
        }
    }
    
    private func updateLabel(reactionType: String, increment: Int) {
        guard let emoji = emojiReactionTypes[reactionType] else {
            return
        }
        
        var reactionIndex = -1
        
        for (index, subview) in emojiesStackView.subviews.enumerated() {
            if let emojiLabel = subview as? UILabel, emojiLabel.text == emoji.emoji {
                reactionIndex = index
                break
            }
        }
        
        guard reactionIndex != -1, let label = labelsStackView.subviews[reactionIndex].subviews.first as? UILabel else {
            return
        }
        
        let count = (reactionScores[reactionType] ?? 0) + increment
        label.text = count > 0 ? count.shortString() : nil // swiftlint:disable:this empty_count
        
        if increment > 0 {
            if let avatarView = avatarsStackView.subviews[reactionIndex].subviews.first as? AvatarView {
                avatarView.update(with: User.current.avatarURL, name: User.current.name)
            }
        } else {
            avatarsStackView.subviews[reactionIndex].subviews.first?.removeFromSuperview()
        }
    }
    
    func dismiss() {
        UIView.animateSmoothly(withDuration: 0.25, animations: {
            self.alpha = 0
            self.reactionsView.transform = .init(scaleX: 0.2, y: 0.2)
            self.selectedView?.transform = .identity
        }) { [weak self] _ in
            self?.onDismissAction?()
            self?.removeFromSuperview()
        }
    }
    
    private func createStackView() -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [])
        stackView.axis = .horizontal
        stackView.distribution = .equalCentering
        reactionsView.addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(CGFloat.reactionsPickerCornerRadius / 2)
            make.right.equalToSuperview().offset(CGFloat.reactionsPickerCornerRadius / -2)
        }
        
        return stackView
    }
    
    // MARK: - Emojies
    
    private func cerateEmojiesStackView() -> UIStackView {
        let stackView = createStackView()
        stackView.snp.makeConstraints { $0.centerY.equalToSuperview() }
        return stackView
    }
    
    private func createEmojiView(emoji: String, maxScore: Int, reaction: Reaction, completion: @escaping Completion) -> UIView {
        let label = UILabel()
        label.text = emoji
        label.textAlignment = .center
        label.font = .reactionsEmoji
        label.snp.makeConstraints { $0.width.height.equalTo(CGFloat.reactionsPickerButtonWidth).priority(999) }
                
        label.layer.cornerRadius = CGFloat.reactionsPickerButtonWidth / 2
        label.layer.borderColor = #colorLiteral(red: 0.2392156863, green: 0.2745098039, blue: 0.2745098039, alpha: 1).withAlphaComponent(0.03).cgColor
        label.layer.borderWidth = 1
        
        var reactionScore = reaction.score
        var wasSend = false
        let isRegular = maxScore < 2
        
        var tap = label.rx.tapGesture()
            .when(.recognized)
            .do(onNext: { [weak label] _ in
                reactionScore += 1
                reactionScore = min(reactionScore, maxScore)
                label?.removeAllAnimations()
                label?.transform = .init(scaleX: 0.3, y: 0.3)
                
                UIView.animateSmoothly(withDuration: 0.3,
                                       usingSpringWithDamping: 0.4,
                                       initialSpringVelocity: 10,
                                       animations: { label?.transform = .identity })
            })
        
        if isRegular {
            tap = tap.take(1).delay(.milliseconds(300), scheduler: MainScheduler.instance)
        } else {
            tap = tap.debounce(.milliseconds(1500), scheduler: MainScheduler.instance)
        }
        
        tap
            .subscribe(
                onNext: { [weak self] _ in
                    self?.isUserInteractionEnabled = false
                    wasSend = true
                    
                    if (isRegular || reactionScore > reaction.score),
                        let add = completion(reaction.type, reactionScore) {
                        self?.updateLabel(reactionType: reaction.type, increment: add ? reactionScore : -1)
                    }
                    
                    self?.dismiss()
                    
                },
                onDisposed: {
                    if !wasSend, reactionScore > reaction.score {
                        _ = completion(reaction.type, reactionScore)
                    }
            })
            .disposed(by: disposeBag)
        
        return label
    }
    
    // MARK: - Avatars
    
    private func createAvatarsStackView() -> UIStackView {
        let stackView = createStackView()
        stackView.isUserInteractionEnabled = false
        stackView.snp.makeConstraints { $0.centerY.equalTo(reactionsView.snp.top) }
        return stackView
    }
    
    private func createAvatarView(_ users: [User]?) -> UIView {
        let viewContainer = UIView(frame: .zero)
        viewContainer.snp.makeConstraints { $0.width.height.equalTo(CGFloat.reactionsPickerButtonWidth).priority(999) }
        
        let avatarView = AvatarView(style: .init(radius: .reactionsPickerAvatarRadius))
        avatarView.makeCenterEqualToSuperview(superview: viewContainer)
        
        if let user = users?.first {
            avatarView.update(with: user.avatarURL, name: user.name)
        } else {
            avatarView.isHidden = true
        }
        
        return viewContainer
    }
    
    // MARK: - Labels
    
    private func createLabelsStackView() -> UIStackView {
        let stackView = createStackView()
        stackView.isUserInteractionEnabled = false
        stackView.snp.makeConstraints { $0.top.equalTo(reactionsView.snp.centerY).offset(2) }
        return stackView
    }
    
    private func createLabel(_ count: Int) -> UIView {
        let viewContainer = UIView(frame: .zero)
        viewContainer.snp.makeConstraints { $0.width.height.equalTo(CGFloat.reactionsPickerButtonWidth).priority(999) }
        
        let label = UILabel(frame: .zero)
        label.text = count > 0 ? count.shortString() : nil // swiftlint:disable:this empty_count
        label.font = .chatSmall
        label.textColor = reactionsView.backgroundColor?.oppositeBlackAndWhite
        label.makeCenterEqualToSuperview(superview: viewContainer)
        
        return viewContainer
    }
}
