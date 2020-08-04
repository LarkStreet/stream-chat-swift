//
//  StatusTableViewCell.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 12/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import SnapKit

final class StatusTableViewCell: UITableViewCell, Reusable {
    
    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .chatGray
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatXSmall
        label.textColor = .chatGray
        titleLabel.addSubview(label)
        
        label.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
        }
        
        return label
    }()
    
    private lazy var lineView1 = createLineView()
    private lazy var lineView2 = createLineView()
    var title: String? { titleLabel.text }
    
    override func prepareForReuse() {
        reset()
        super.prepareForReuse()
    }
    
    func reset() {
        titleLabel.text = nil
        subtitleLabel.text = nil
    }
    
    func setup() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel])
        stackView.axis = .horizontal
        stackView.spacing = .messageStatusSpacing
        stackView.alignment = .center
        
        contentView.addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().priority(999)
            make.height.equalTo(60).priority(999)
        }
    }
    
    private func createLineView() -> UIView {
        let view = UIView(frame: .zero)
        view.snp.makeConstraints { $0.height.equalTo(CGFloat.messageStatusLineWidth).priority(999) }
        return view
    }
    
    func update(title: String, subtitle: String? = nil, textColor: UIColor) {
        if titleLabel.superview == nil {
            setup()
        }
        
        titleLabel.text = title
        titleLabel.textColor = textColor
        
        if let subtitle = subtitle {
            subtitleLabel.text = subtitle.uppercased()
        }
    }
}
