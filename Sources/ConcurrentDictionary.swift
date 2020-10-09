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

public final class ConcurrentDictionary<T: Hashable, T2> {
    public final class Value {
        public private(set) var value: T2
        private var lock = SpinLock()
        
        init(_ value: T2) {
            self.value = value
        }
        
        public func mutate(_ transform: (inout T2) -> ()) {
            lock.lock { transform(&value) }
        }
    }
    
    public typealias Block = () -> T2
    public private(set) var dictionary: [T: Value]
    
    public var isEmpty: Bool {
        return dictionary.isEmpty
    }
    
    public var keys: [T] {
        return Array(dictionary.keys)
    }
    
    private var lock = ReadWriteLock()
    private let defaultBlock: Block
    
    public init(defaultValue defaultBlock: @autoclosure @escaping Block) {
        self.dictionary = [:]
        self.defaultBlock = defaultBlock
    }
    
    public subscript(key: T) -> T2? {
        get {
            return lock.read { dictionary[key]?.value }
        }
        set {
            lock.write {
                guard let value = newValue else {
                    dictionary.removeValue(forKey: key)
                    return
                }
                
                dictionary[key] = Value(value)
            }
        }
    }
    
    public subscript(key: T) -> Value {
        var value = lock.read { dictionary[key] }
        
        if value == nil {
            lock.write {
                value = dictionary[key]
                
                guard value == nil else {
                    return
                }
                
                value = Value(defaultBlock())
                dictionary[key] = value
            }
        }
        
        return value.unsafelyUnwrapped
    }
}

public extension ConcurrentDictionary where T2 == FloatLiteralType {
    static func += (lhs: ConcurrentDictionary, rhs: ConcurrentDictionary) {
        rhs.keys.concurrentForEach { key in
            guard let value = rhs[key] else {
                return
            }
            
            lhs[key].mutate { $0 += value }
        }
    }
}

public extension ConcurrentDictionary where T2 == IntegerLiteralType {
    static func += (lhs: ConcurrentDictionary, rhs: ConcurrentDictionary) {
        rhs.keys.concurrentForEach { key in
            guard let value = rhs[key] else {
                return
            }
            
            lhs[key].mutate { $0 += value }
        }
    }
}

public extension ConcurrentDictionary.Value where T2 == FloatLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: T2) {
        lhs.mutate { $0 += rhs }
    }
}

public extension ConcurrentDictionary.Value where T2 == IntegerLiteralType {
    @inlinable
    static func += (lhs: ConcurrentDictionary.Value, rhs: T2) {
        lhs.mutate { $0 += rhs }
    }
}
