//
//  Sequence.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import Foundation

extension Sequence {
    /// Computes the sum of elements in a sequence based on a given predicate.
    func sum<T: AdditiveArithmetic>(_ predicate: (Element) -> T) -> T {
        reduce(.zero) { $0 + predicate($1) }
    }
}
