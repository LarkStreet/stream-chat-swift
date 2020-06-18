//
//  ComposerView+TextView.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 04/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit

// MARK: - Text View Height

extension ComposerView {
    
    func setupTextView() -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.delegate = self
        textView.attributedText = attributedText()
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.isScrollEnabled = false
        return textView
    }
    
    var textViewPadding: CGFloat {
        baseTextHeight == .greatestFiniteMagnitude ? 0 : ((style?.height ?? .composerHeight) - baseTextHeight) / 2
    }
    
    private var textViewContentSize: CGSize {
        textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
    }
    
    /// Update the height of the text view for a big text length.
    func updateTextHeightIfNeeded() {
        if baseTextHeight == .greatestFiniteMagnitude {
            let text = textView.attributedText
            textView.attributedText = attributedText(text: "Stream")
            baseTextHeight = textViewContentSize.height.rounded()
            textView.attributedText = text
        }
        
        updateTextHeight(textView.attributedText.length > 0 ? textViewContentSize.height.rounded() : baseTextHeight)
    }
    
    private func updateTextHeight(_ textHeight: CGFloat) {
        guard let style = style else {
            return
        }
        var maxHeight = CGFloat.composerMaxHeight
        let filesHeight = CGFloat.composerFileHeight * CGFloat(filesStackView.arrangedSubviews.count)

        if !imagesCollectionView.isHidden {
            maxHeight -= .composerAttachmentsHeight
        }
        
        if !filesStackView.isHidden {
            maxHeight -= filesHeight
        }
        
        if let uploadManager = uploadManager {
            imagesCollectionView.isHidden = uploadManager.images.isEmpty
            filesStackView.isHidden = uploadManager.files.isEmpty
        }
        var height = min(max(textHeight + 2 * textViewPadding, style.height), maxHeight)
        var textViewTopOffset: CGFloat = 8.0
        
        let isImagesHidden = imagesCollectionView.isHidden
        
        if !isImagesHidden {
            height += .composerAttachmentsHeight
            textViewTopOffset += .composerAttachmentsHeight
        }
        
        let constant: CGFloat = isImagesHidden ? 0 : .composerAttachmentsHeight
        
        if let constraint = imagesHeightConstraint, constraint.layoutConstraints.first?.constant != constant {
            constraint.update(offset: constant)
            setNeedsLayout()
            layoutIfNeeded()
        }
        
        if !filesStackView.isHidden {
            let filesHeight = CGFloat.composerFileHeight * CGFloat(filesStackView.arrangedSubviews.count)
            height += filesHeight
            textViewTopOffset += filesHeight
        }
        
        var shouldEnableScroll = height >= CGFloat.composerMaxHeight

        if shouldEnableScroll {
            /// we should calculate it manually because user can "paste" a large amount of text
            var textViewHeight = height - textViewTopOffset - safeAreaInsets.bottom
            if textView.frame.size.height > textViewHeight {
                textViewHeight = textView.frame.size.height
            }
            
            if textViewHeightConstraint == nil {
                textView.snp.makeConstraints { make in
                    textViewHeightConstraint = make.height.equalTo(textViewHeight).constraint
                }
                textView.isScrollEnabled = shouldEnableScroll

                setNeedsLayout()
                layoutIfNeeded()
            }
            if textViewHeightConstraint?.layoutConstraints.first?.constant != textViewHeight {
                textViewHeightConstraint?.update(offset: textViewHeight)
                textViewHeightConstraint?.isActive = true
                textView.isScrollEnabled = shouldEnableScroll

                setNeedsLayout()
                layoutIfNeeded()
            }
        } else {
            if let constraint = textViewHeightConstraint {
                constraint.isActive = false
                textViewHeightConstraint = nil
                textView.isScrollEnabled = shouldEnableScroll
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
        
        if textViewTopConstraint?.layoutConstraints.first?.constant != textViewTopOffset {
            textViewTopConstraint?.update(offset: textViewTopOffset)
            setNeedsLayout()
            layoutIfNeeded()
        }
        
        updateToolbarIfNeeded()
    }
    
    func updateToolbarIfNeeded() {
        guard let style = style else {
            return
        }

        let height = self.frame.height + style.edgeInsets.top + style.edgeInsets.bottom

        guard toolBar.frame.height != height else {
            return
        }
        
        /// toolbar is needed for smooth composer animation within the keyboard  :)
        toolBar = UIToolbar(frame: CGRect(width: UIScreen.main.bounds.width, height: height))
        toolBar.isHidden = true
        textView.inputAccessoryView = toolBar
        textView.reloadInputViews()
    }
}

// MARK: - Text View Delegate

extension ComposerView: UITextViewDelegate {
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        updateTextHeightIfNeeded()
        updateSendButton()
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        updateTextHeightIfNeeded()
        updatePlaceholder()
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        updateTextHeightIfNeeded()
    }
}
