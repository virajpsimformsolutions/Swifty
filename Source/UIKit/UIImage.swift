//
//  UIImage.swift
//  Swifty
//
//  Created by Vadym Pavlov on 10.03.18.
//  Copyright © 2018 Vadym Pavlov. All rights reserved.
//

import UIKit

public extension UIImage {

    // MARK: - Colors
    static func from(color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    func image(with color: UIColor) -> UIImage {
        let image = withRenderingMode(.alwaysTemplate)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        color.set()

        image.draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return result.withRenderingMode(.alwaysOriginal)
    }
}

