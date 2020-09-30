//
//  MessageTableViewCell.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 03/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatClient
import StreamChatCore
import SnapKit
import Nuke
import RxSwift

/// A message table view cell.
open class MessageTableViewCell: UITableViewCell, Reusable {
    
    typealias ReactionAction = (_ cell: UITableViewCell, _ locationInView: CGPoint) -> Void
    typealias TapAction = (_ cell: MessageTableViewCell, _ message: Message) -> Void
    typealias AttachmentTapAction = (_ attachment: Attachment, _ at: Int, _ message: Message) -> Void
    typealias LongPressAction = (_ cell: MessageTableViewCell, _ message: Message) -> Void
    typealias AttachmentActionTapAction = (_ message: Message, _ button: UIButton) -> Void
    
    // MARK: - Properties
    
    /// A dispose bag for the cell.
    public private(set) var disposeBag = DisposeBag()
    /// A message view style.
    public private(set) var style: MessageViewStyle = MessageViewStyle()
    /// Checks if needds setup layout.
    public private(set) var needsToSetup = true
    
    /// An avatar.
    public private(set) lazy var avatarView = AvatarView(style: style.avatarViewStyle)
    
    let reactionsContainer: UIImageView = UIImageView(frame: .zero)
    let reactionsOverlayView = UIView(frame: .zero)
    let reactionsTailImage = UIImageView(frame: .zero)
    var reactionsTailImageLeftConstraint: Constraint?
    var reactionsTailImageRightConstraint: Constraint?
    
    let reactionsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textAlignment = .center
        return label
    }()

    private func setSelected(_ selected: Bool) {
        var image: UIImage? = nil
        
        if let text = messageLabel.text, !text.messageContainsOnlyEmoji {
            image = messageBackgroundImage()
        }
        
        messageContainerView.image = selected ? nil : image
        messageLabel.backgroundColor = selected ? .clear : style.backgroundColor
    }
    
    var previewView: UIView? {
        setSelected(true)
        
        defer { DispatchQueue.main.async { self.setSelected(false) } }
        
        let isLeftAlignment = style.alignment == .left
        
        let contentMessageFrame = messageStackView.frame

        var extraHeight: CGFloat = 0
        var snapShotY: CGFloat = contentMessageFrame.origin.y + extraHeight
        
        let visibleSubviews = messageStackView.arrangedSubviews.filter { !$0.isHidden }
        
        if (visibleSubviews.first as? AttachmentPreview) == nil && visibleSubviews.first != messageContainerView {
            extraHeight = extraHeight + (visibleSubviews.first?.frame.height ?? 0)
            snapShotY = contentMessageFrame.origin.y + extraHeight
        }
        
        if (visibleSubviews.last as? AttachmentPreview) == nil && visibleSubviews.last != messageContainerView {
            extraHeight = extraHeight + (visibleSubviews.last?.frame.height ?? 0)
        }
            
        var height = contentMessageFrame.height - extraHeight
        
        if avatarView.bounds.height > height {
            height = avatarView.bounds.height
        }
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        
        backgroundView.layer.cornerRadius = 12
        backgroundView.layer.borderWidth = style.borderWidth
        backgroundView.layer.borderColor = style.borderColor.cgColor
        backgroundView.layer.masksToBounds = true
    
        let snapShotFrame = CGRect(x: contentMessageFrame.origin.x, y: snapShotY,
                                   width: contentMessageFrame.width,
                                   height: height)
        
        let avatarX = isLeftAlignment ? contentView.frame.origin.x : contentMessageFrame.origin.x + contentMessageFrame.width

        let avatarSnapShotFrame = CGRect(x: avatarX,
                                         y: avatarView.frame.origin.y,
                                         width: CGFloat.messageTextPaddingWithAvatar,
                                         height: height)
    
        guard let snapShotView = contentView.resizableSnapshotView(from: snapShotFrame,
                                                                   afterScreenUpdates: true, withCapInsets: .zero),
              let avatarSnapShotView = contentView.resizableSnapshotView(from: avatarSnapShotFrame,
                                                                         afterScreenUpdates: true, withCapInsets: .zero) else {
            return nil
        }
                
        let finalX = isLeftAlignment ? avatarSnapShotFrame.origin.x: snapShotFrame.origin.x
        
        let finalFrame = CGRect(x: finalX, y: snapShotFrame.origin.y, width: snapShotFrame.width + avatarSnapShotFrame.width, height: snapShotFrame.height)
        
        let finalView = UIView(frame: finalFrame)
        finalView.addSubview(backgroundView)
        backgroundView.addSubview(snapShotView)
        finalView.addSubview(avatarSnapShotView)

        finalView.clipsToBounds = true
        
        let backgroundViewX: CGFloat = isLeftAlignment ? avatarSnapShotView.frame.width : 0
        let avatarViewX: CGFloat = isLeftAlignment ? 0 : snapShotView.frame.width
        
        backgroundView.frame = CGRect(x: backgroundViewX, y: 0,
                                      width: snapShotView.frame.width, height: snapShotView.frame.height)
        avatarSnapShotView.frame = CGRect(x: avatarViewX, y: avatarSnapShotView.frame.height - avatarView.frame.height,
                                          width: avatarSnapShotView.frame.width, height: avatarSnapShotView.frame.height)
        
        return finalView
    }
    
    private(set) lazy var nameAndDateStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameLabel, dateLabel])
        stackView.axis = .horizontal
        stackView.spacing = style.spacing.vertical
        let messageNameAndDateHeight: CGFloat
        
        stackView.snp.makeConstraints {
            var height: CGFloat = 13
            
            if let avatarViewStyle = self.style.avatarViewStyle {
                height = max(height, avatarViewStyle.radius - self.style.spacing.vertical)
            }
            
            height = max(height, style.nameFont.lineHeight)
            $0.height.equalTo(height).priority(999)
        }
        
        stackView.isHidden = true
        return stackView
    }()
    
    /// A name label.
    public let nameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatSmallBold
        label.textColor = .chatGray
        return label
    }()
    
    /// A date label.
    public let dateLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatSmall
        label.textColor = .chatGray
        return label
    }()
    
    /// An additional date label.
    public let additionalDateLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatSmall
        label.textColor = .chatGray
        return label
    }()
    
    var additionalDateLabelSideConstraint: Constraint?
    var additionalDateLabelBottomConstraint: Constraint?
    
    /// An info label.
    public let infoLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.chatMedium.withTraits([.traitItalic])
        label.textColor = .chatGray
        label.isHidden = true
        return label
    }()
    
    /// A reply count button.
    public let replyCountButton = UIButton(type: .custom)
    
    /// A reply in channel button.
    public let replyInChannelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(" replied to a thread ", for: .normal)
        return button
    }()
    
    private(set) var readUsersView: ReadUsersView?
    var readUsersRightConstraint: Constraint?
    var readUsersBottomConstraint: Constraint?
    
    private(set) lazy var messageStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [nameAndDateStackView,
                                                       messageContainerView,
                                                       infoLabel,
                                                       replyCountButton,
                                                       replyInChannelButton])
        stackView.axis = .vertical
        stackView.spacing = style.spacing.vertical
        return stackView
    }()
    
    var messageStackViewTopConstraint: Constraint?
    
    // A bottom edge inset constraint for `messageStackView` and `avatarView`.
    var bottomEdgeInsetConstraint: Constraint?
    
    let messageContainerView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.isHidden = true
        return imageView
    }()
    
    /// A message label.
    public private(set) lazy var messageLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.numberOfLines = 0
        return label
    }()
    
    var messageTextEnrichment: MessageTextEnrichment?
    var attachmentPreviews: [AttachmentPreview] = []
    var isContinueMessage = false
    
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let messageBackgroundImage = messageBackgroundImage() {
            messageContainerView.image = messageBackgroundImage
        }
        
        attachmentPreviews.forEach { attachmentPreview in
            if let filePreview = attachmentPreview as? FileAttachmentPreview {
                filePreview.apply(imageMask: backgroundImageForAttachment(at: filePreview.index))
            }
        }
    }
    
    override open func prepareForReuse() {
        reset()
        super.prepareForReuse()
    }
    
    // MARK: - Setup Style
    
    /// Setup style and layouts.
    /// - Parameter style: a message view style.
    public func setupIfNeeded(style: MessageViewStyle) {
        guard needsToSetup else { return }
        
        needsToSetup = false
        self.style = style
        selectionStyle = .none
        backgroundColor = style.chatBackgroundColor
        
        // Setup a bottom view with the bottom edge inset.
        let bottomLayoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(bottomLayoutGuide)
        
        bottomLayoutGuide.snp.makeConstraints {
            bottomEdgeInsetConstraint = $0.height.equalTo(style.edgeInsets.bottom).priority(999).constraint
            $0.bottom.equalToSuperview().priority(999)
            $0.left.right.equalToSuperview()
        }
        
        // MARK: Date
        
        dateLabel.font = style.infoFont
        dateLabel.textColor = style.infoColor
        dateLabel.backgroundColor = backgroundColor
        
        additionalDateLabel.isHidden = true
        additionalDateLabel.font = style.infoFont
        additionalDateLabel.textColor = style.infoColor
        additionalDateLabel.backgroundColor = backgroundColor
        contentView.addSubview(additionalDateLabel)
        
        // MARK: Reply Buttons
        
        setupReplyButton(replyCountButton)
        setupReplyButton(replyInChannelButton)
        
        // MARK: Name
        
        if style.alignment == .left {
            nameLabel.font = style.nameFont
            nameLabel.textColor = style.infoColor
            nameLabel.backgroundColor = backgroundColor
        } else {
            nameLabel.isHidden = true
        }
        
        // MARK: Avatar
        
        if style.avatarViewStyle != nil {
            avatarView.backgroundColor = style.chatBackgroundColor
            contentView.addSubview(avatarView)
            
            avatarView.snp.makeConstraints { make in
                make.bottom.equalTo(bottomLayoutGuide.snp.top).priority(999)
                
                if style.alignment == .left {
                    make.left.equalToSuperview().offset(style.edgeInsets.left)
                } else {
                    make.right.equalToSuperview().offset(-style.edgeInsets.right)
                }
            }
        }
        
        // MARK: Message Stack View
        
        messageLabel.attributedText = nil
        messageLabel.numberOfLines = 0
        messageLabel.font = style.font
        messageLabel.textColor = style.textColor
        messageLabel.backgroundColor = style.backgroundColor
        messageContainerView.addSubview(messageLabel)
        
        messageLabel.snp.makeConstraints { make in
            if style.alignment == .left {
                make.left.equalTo(style.messageInsetSpacing.horizontal)
                make.right.lessThanOrEqualTo(-style.messageInsetSpacing.horizontal)
            } else {
                make.left.greaterThanOrEqualTo(style.messageInsetSpacing.horizontal)
                make.right.equalTo(-style.messageInsetSpacing.horizontal)
            }
           
            make.top.equalTo(style.messageInsetSpacing.vertical).priority(999)
            make.bottom.equalTo(-style.messageInsetSpacing.vertical).priority(999)
        }
        
        contentView.addSubview(messageStackView)
        messageStackView.alignment = style.alignment == .left ? .leading : .trailing
        
        messageStackView.snp.makeConstraints { make in
            messageStackViewTopConstraint = make.top.equalToSuperview().offset(style.spacing.vertical).priority(999).constraint
            make.bottom.equalTo(bottomLayoutGuide.snp.top).priority(999)
            
            if style.alignment == .left {
                make.left.equalToSuperview().offset(style.marginWithAvatarOffset).priority(999)
                make.right.lessThanOrEqualToSuperview().offset(-CGFloat.messageTextPaddingWithAvatar).priority(999)
            } else {
                make.left.greaterThanOrEqualToSuperview().offset(CGFloat.messageTextPaddingWithAvatar).priority(999)
                make.right.equalToSuperview().offset(-style.marginWithAvatarOffset).priority(999)
            }
        }
        
        if style.alignment == .left {
            nameAndDateStackView.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(messageContainerView.snp.width)
            }
        }
        
        infoLabel.backgroundColor = backgroundColor
        
        // MARK: Read Users
        
        if style.alignment == .right {
            let readUsersView = ReadUsersView()
            readUsersView.isHidden = true
            readUsersView.backgroundColor = backgroundColor
            readUsersView.countLabel.textColor = style.infoColor
            readUsersView.countLabel.font = style.infoFont
            contentView.addSubview(readUsersView)
            readUsersView.snp.makeConstraints { $0.height.equalTo(CGFloat.messageReadUsersSize) }
            self.readUsersView = readUsersView
        }
        
        // MARK: Reactions
        
        contentView.addSubview(reactionsContainer)
        contentView.addSubview(reactionsOverlayView)
        reactionsOverlayView.isHidden = true
        reactionsContainer.isHidden = true
        reactionsContainer.addSubview(reactionsTailImage)
        reactionsContainer.addSubview(reactionsLabel)
        reactionsContainer.backgroundColor = style.reactionViewStyle.backgroundColor
        reactionsContainer.layer.cornerRadius = style.reactionViewStyle.cornerRadius
        reactionsTailImage.image = style.reactionViewStyle.tailImage
        reactionsTailImage.tintColor = style.reactionViewStyle.backgroundColor
        let reactionsHeight = style.reactionViewStyle.cornerRadius * 2
        let tailAdditionalOffset: CGFloat = 2
        
        reactionsContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(self.style.spacing.vertical)
            make.height.equalTo(reactionsHeight).priority(999)
            let minWidth = style.reactionViewStyle.tailImage.size.width + reactionsHeight - 2 * tailAdditionalOffset
            make.width.greaterThanOrEqualTo(minWidth)
            
            if style.reactionViewStyle.alignment == .left {
                make.left.greaterThanOrEqualToSuperview().offset(style.marginWithAvatarOffset).priority(999)
                make.right.greaterThanOrEqualTo(reactionsTailImage.snp.right)
                    .offset(style.reactionViewStyle.cornerRadius - tailAdditionalOffset)
                    .priority(998)
            } else {
                make.right.lessThanOrEqualToSuperview().offset(-style.marginWithAvatarOffset).priority(999)
                make.left.lessThanOrEqualTo(reactionsTailImage.snp.left)
                    .offset(tailAdditionalOffset - style.reactionViewStyle.cornerRadius)
                    .priority(998)
            }
        }
        
        reactionsTailImage.snp.makeConstraints { make in
            make.top.equalTo(reactionsContainer.snp.bottom)
            make.size.equalTo(style.reactionViewStyle.tailImage.size)
        }
        
        reactionsLabel.font = style.reactionViewStyle.font
        reactionsLabel.textColor = style.reactionViewStyle.textColor
        
        reactionsLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(CGFloat.reactionsTextPadding)
            make.right.equalToSuperview().offset(-CGFloat.reactionsTextPadding)
        }
        
        reactionsOverlayView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalTo(reactionsContainer).offset(-self.style.spacing.vertical)
            make.right.equalTo(reactionsContainer).offset(self.style.spacing.vertical)
            make.bottom.equalTo(reactionsTailImage)
        }
    }
    
    private func setupReplyButton(_ button: UIButton) {
        button.isHidden = true
        button.titleLabel?.font = style.replyFont
        button.titleLabel?.backgroundColor = backgroundColor
        button.setTitleColor(style.replyColor, for: .normal)
        button.setTitleColor(style.infoColor, for: .disabled)
        button.backgroundColor = backgroundColor
        
        if style.alignment == .left {
            button.setImage(UIImage.Icons.path, for: .normal)
        } else {
            button.setImage(UIImage.Icons.path.flip(orientation: .upMirrored)?.template, for: .normal)
            button.semanticContentAttribute = .forceRightToLeft
        }
        
        button.tintColor = style.borderWidth > 0
            ? style.borderColor
            : (style.backgroundColor == style.chatBackgroundColor ? .chatGray : style.backgroundColor)
    }
    
    // MARK: Reset
    
    /// Reset views.
    open func reset() {
        if style.avatarViewStyle != nil {
            avatarView.reset()
            avatarView.isHidden = true
            avatarView.backgroundColor = backgroundColor
        }
        bottomEdgeInsetConstraint?.update(offset: style.edgeInsets.bottom)
        
        replyCountButton.isHidden = true
        replyInChannelButton.isHidden = true
        nameAndDateStackView.isHidden = true
        nameLabel.text = nil
        dateLabel.text = nil
        infoLabel.isHidden = true
        infoLabel.text = nil
        
        additionalDateLabel.text = nil
        additionalDateLabel.isHidden = true
        additionalDateLabelSideConstraint?.deactivate()
        additionalDateLabelSideConstraint = nil
        additionalDateLabelBottomConstraint?.deactivate()
        additionalDateLabelBottomConstraint = nil
        
        messageStackViewTopConstraint?.update(offset: style.spacing.vertical)
        
        messageContainerView.isHidden = true
        messageContainerView.image = nil
        messageContainerView.layer.borderWidth = 0
        messageContainerView.backgroundColor = style.chatBackgroundColor
        messageContainerView.mask = nil
        
        messageLabel.attributedText = nil
        messageLabel.font = style.font
        messageLabel.textColor = style.textColor
        messageLabel.backgroundColor = style.backgroundColor
        messageTextEnrichment = nil
        
        readUsersView?.reset()
        readUsersRightConstraint?.deactivate()
        readUsersRightConstraint = nil
        readUsersBottomConstraint?.deactivate()
        readUsersBottomConstraint = nil
        
        reactionsContainer.isHidden = true
        reactionsOverlayView.isHidden = true
        reactionsLabel.text = nil
        reactionsTailImageLeftConstraint?.deactivate()
        reactionsTailImageLeftConstraint = nil
        reactionsTailImageRightConstraint?.deactivate()
        reactionsTailImageRightConstraint = nil
        
        free()
    }
    
    /// Free resources (attachments, rx.subscriptions).
    open func free() {
        disposeBag = DisposeBag()
        attachmentPreviews.forEach { $0.removeFromSuperview() }
        attachmentPreviews = []
    }
}

// MARK: - Helpers to make correct cell layout updates

extension MessageTableViewCell {
    
    func lastVisibleViewFromMessageStackView() -> UIView? {
        var visibleViews = messageStackView.arrangedSubviews.filter { $0.isHidden == false }
        
        if visibleViews.isEmpty {
            return nil
        }
        
        if visibleViews.last == nameAndDateStackView {
            visibleViews.removeLast()
        }
        
        if visibleViews.last == replyCountButton {
            visibleViews.removeLast()
        }
        
        if visibleViews.last == replyInChannelButton {
            visibleViews.removeLast()
        }
        
        return visibleViews.last
    }
    
    func updateReadUsersViewConstraints(relatedTo view: UIView) {
        guard let readUsersView = readUsersView, !readUsersView.isHidden else {
            return
        }
        
        readUsersView.snp.makeConstraints { make in
            self.readUsersRightConstraint = make.right.equalTo(view.snp.left).offset(-self.style.spacing.vertical).constraint
            self.readUsersBottomConstraint = make.bottom.equalTo(view).constraint
        }
    }
    
    func updateAdditionalLabelViewConstraints(relatedTo view: UIView) {
        guard !additionalDateLabel.isHidden else {
            return
        }
        
        additionalDateLabel.snp.makeConstraints { make in
            if style.alignment == .right {
                self.additionalDateLabelSideConstraint = make.right
                    .equalTo(view.snp.left)
                    .offset(-self.style.spacing.vertical)
                    .constraint
            } else {
                self.additionalDateLabelSideConstraint = make.left
                    .equalTo(view.snp.right)
                    .offset(self.style.spacing.vertical)
                    .constraint
            }
            
            self.additionalDateLabelBottomConstraint = make.bottom.equalTo(view)
                .offset(-(self.style.spacing.vertical + 2))
                .constraint
        }
    }
}
