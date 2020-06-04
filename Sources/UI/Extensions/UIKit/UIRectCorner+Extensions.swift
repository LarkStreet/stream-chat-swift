//
//  UIRectCorner+Extensions.swift
//  StreamChatClient
//
//  Created by Alexey Bukhtin on 08/05/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import UIKit

extension UIRectCorner: Hashable {
    public static let leftSide: UIRectCorner = [.allCorners]
    public static let rightSide: UIRectCorner = [.allCorners]
    public static let pointedLeftBottom: UIRectCorner = [.allCorners]
    public static let pointedRightBottom: UIRectCorner = [.allCorners]
}
