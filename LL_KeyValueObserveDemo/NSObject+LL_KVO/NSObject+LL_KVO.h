//
//  NSObject+LL_KVO.h
//  LL_KeyValueObserveDemo
//
//  Created by 迦南 on 2018/3/22.
//  Copyright © 2018年 迦南. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^LL_ObservingHandler) (id observedObject, NSString * observedKey, id oldValue, id newValue);

@interface NSObject (LL_KVO)

- (void)ll_addObserver:(NSObject *)object forKey:(NSString *)key withBlock:(LL_ObservingHandler)observedHandler;
- (void)ll_removeObserver:(NSObject *)object forKey:(NSString *)key;
@end
