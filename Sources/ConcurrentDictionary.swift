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
        public private(set) var value: V
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

    private let defaultBlock: Block

    private var items = [K: Value]()
    private var lock = pthread_rwlock_t()
    
    public var isEmpty: Bool {
        return items.isEmpty
    }
    
    public init(defaultValue defaultBlock: @autoclosure @escaping Block) {
        self.defaultBlock = defaultBlock
        pthread_rwlock_init(&lock, nil)
    }
    
    public subscript(key: K) -> V? {
        get {
            defer {
                pthread_rwlock_unlock(&lock)
            }

            pthread_rwlock_rdlock(&lock)
            return items[key]?.value
        }
        set {
            defer {
               pthread_rwlock_unlock(&lock)
            }
            
            pthread_rwlock_wrlock(&lock)
            
            guard let newValue = newValue else {
                items.removeValue(forKey: key)
                return
            }
            
            items[key] = Value(newValue)
        }
    }
    
    public subscript(key: K) -> Value {
        pthread_rwlock_rdlock(&lock)

        var value = items[key]
        pthread_rwlock_unlock(&lock)
        
        if value == nil {
            pthread_rwlock_wrlock(&lock)
            value = items[key]
            
            if value == nil {
                value = Value(defaultBlock())
                items[key] = value
            }

            pthread_rwlock_unlock(&lock)
        }
        
        return value!
    }

    deinit {
        pthread_rwlock_destroy(&lock)
    }
}

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
public extension ConcurrentDictionary {
    func sorted(by areInIncreasingOrder: ((key: K, value: Value), (key: K, value: Value)) -> Bool) -> [Dictionary<K, Value>.Element] {
        return items.sorted(by: areInIncreasingOrder)
    }
}

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
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

@available(macOS 10.12, iOS 10, tvOS 12, watchOS 3, *)
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
