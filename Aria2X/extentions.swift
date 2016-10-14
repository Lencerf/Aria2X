//
//  extentions.swift
//  Aria2X
//
//  Created by Lencerf on 16/6/25.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

import Foundation

extension Optional where Wrapped: Any {
    subscript(index:Int) -> Any? {
        if let unwrapped = self {
            if let array = unwrapped as? Array<Any> {
                if index < array.count {
                    return array[index]
                }
            }
        }
        return nil
    }
    
    subscript(key:String) -> Any? {
        if let unwrapped = self {
            if let dict = unwrapped as? Dictionary<String, Any> {
                return dict[key]
            }
        }
        return nil
    }
}
