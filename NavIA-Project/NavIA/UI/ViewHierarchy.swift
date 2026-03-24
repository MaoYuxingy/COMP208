//
//  ViewHierarchy.swift
//  NavIA
//

import UIKit

extension UIView {
    func descendants<T: UIView>(of type: T.Type) -> [T] {
        subviews.reduce(into: []) { partialResult, subview in
            if let matchingSubview = subview as? T {
                partialResult.append(matchingSubview)
            }

            partialResult.append(contentsOf: subview.descendants(of: type))
        }
    }
}
