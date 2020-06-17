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
    
    private func updateTextHeight(_ height: CGFloat) {
        guard let style = style else {
            return
        }
        
        var maxHeight = CGFloat.composerMaxHeight
        
        if !imagesCollectionView.isHidden {
            maxHeight -= .composerAttachmentsHeight
        }
        
        if !filesStackView.isHidden {
            let filesHeight = CGFloat.composerFileHeight * CGFloat(filesStackView.arrangedSubviews.count)
            maxHeight -= filesHeight
        }
        
        if let uploadManager = uploadManager {
            imagesCollectionView.isHidden = uploadManager.images.isEmpty
            filesStackView.isHidden = uploadManager.files.isEmpty
        }
        
        var height = min(max(height + 2 * textViewPadding, style.height), maxHeight)
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
            let bottomSpace = frame.size.height - textView.frame.origin.y - textView.frame.size.height
            var value = maxHeight - 8.0 - bottomSpace /// we should calculate it manually because user can "paste" a large amount of text
            if textView.frame.size.height > value {
                value = textView.frame.size.height
            }
            if textViewHeightConstraint == nil {
                textView.snp.makeConstraints { make in
                    textViewHeightConstraint = make.height.equalTo(value).constraint
                }
                textView.isScrollEnabled = shouldEnableScroll

                setNeedsLayout()
                layoutIfNeeded()
            }
            if textViewHeightConstraint?.layoutConstraints.first?.constant != value {
                textViewHeightConstraint?.update(offset: value)
                textViewHeightConstraint?.isActive = true
                textView.isScrollEnabled = shouldEnableScroll

                setNeedsLayout()
                layoutIfNeeded()
            }
        } else {
            textViewHeightConstraint?.isActive = false
            textView.isScrollEnabled = shouldEnableScroll

            setNeedsLayout()
            layoutIfNeeded()
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
