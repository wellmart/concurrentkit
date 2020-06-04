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

public final class ConcurrentDictionary<K: Hashable, V> {
    public final class Value {
        public private(set) var value: V
        private var lock = SpinLock()
        
        init(_ value: V) {
            self.value = value
        }
        
        public func mutate(_ transform: (inout V) -> ()) {
            lock.lock { transform(&value) }
        }
    }
    
    public typealias Block = () -> V
    
    private var lock = ReadWriteLock()
    
    private var items: [K: Value]
    private let defaultBlock: Block
    
    public var isEmpty: Bool {
        return items.isEmpty
    }
    
    public init(defaultValue defaultBlock: @autoclosure @escaping Block) {
        self.items = [:]
        self.defaultBlock = defaultBlock
    }
    
    public subscript(key: K) -> V? {
        get {
            return lock.read { items[key]?.value }
        }
        set {
            lock.write {
                guard let value = newValue else {
                    items.removeValue(forKey: key)
                    return
                }
                
                items[key] = Value(value)
            }
        }
    }
    
    public subscript(key: K) -> Value {
        var value = lock.read { items[key] }
        
        if value === nil {
            lock.write {
                value = items[key]
                
                guard value === nil else {
                    return
                }
                
                value = Value(defaultBlock())
                items[key] = value
            }
        }
        
        return value!
    }
}

public extension ConcurrentDictionary {
    func sorted(by areInIncreasingOrder: ((key: K, value: Value), (key: K, value: Value)) -> Bool) -> [Dictionary<K, Value>.Element] {
        return items.sorted(by: areInIncreasingOrder)
    }
}

public extension ConcurrentDictionary where V == FloatLiteralType {
    static func += (lhs: ConcurrentDictionary, rhs: ConcurrentDictionary) {
        let keys = Array(rhs.items.keys)
        
        keys.concurrentForEach { key in
            guard let value = rhs[key] else {
                return
            }
            
            lhs[key].mutate { $0 += value }
        }
    }
}

public extension ConcurrentDictionary where V == IntegerLiteralType {
    static func += (lhs: ConcurrentDictionary, rhs: ConcurrentDictionary) {
        let keys = Array(rhs.items.keys)
        
        keys.concurrentForEach { key in
            guard let value = rhs[key] else {
                return
            }
            
            lhs[key].mutate { $0 += value }
        }
    }
}

public extension ConcurrentDictionary.Value where V == FloatLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: V) {
        lhs.mutate { $0 += rhs }
    }
}

public extension ConcurrentDictionary.Value where V == IntegerLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: V) {
        lhs.mutate { $0 += rhs }
    }
}
