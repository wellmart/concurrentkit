//
//  ConcurrentKit
//
//  Copyright (c) 2020 Wellington Marthas
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
public final class ConcurrentDictionary<K: Hashable, V> {
    public final class Value {
        private var value: V
        private var lock = os_unfair_lock()
        
        init(_ value: V) {
            self.value = value
        }
        
        public func mutate(_ transform: (inout V) -> ()) {
            defer {
                os_unfair_lock_unlock(&lock)
            }
            
            os_unfair_lock_lock(&lock)
            transform(&value)
        }
    }
    
    public typealias Block = () -> V
    
    private var items: [K: Value]
    private let defaultBlock: Block
    
    private var lock = os_unfair_lock()
    
    public init(defaultValue defaultBlock: @autoclosure @escaping Block) {
        self.items = [:]
        self.defaultBlock = defaultBlock
    }
    
    public subscript(key: K) -> Value {
        get {
            var value = items[key]
            
            if value == nil {
                os_unfair_lock_lock(&lock)
                value = items[key]
                
                if value == nil {
                    value = Value(defaultBlock())
                    items[key] = value
                }
                
                os_unfair_lock_unlock(&lock)
            }
            
            return value!
        }
    }
}

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
public extension ConcurrentDictionary.Value where V == FloatLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: V) {
        lhs.mutate { $0 += rhs }
    }
}

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
public extension ConcurrentDictionary.Value where V == IntegerLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: V) {
        lhs.mutate { $0 += rhs }
    }
}
