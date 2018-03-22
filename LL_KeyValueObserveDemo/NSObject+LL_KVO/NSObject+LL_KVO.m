//
//  NSObject+LL_KVO.m
//  LL_KeyValueObserveDemo
//
//  Created by 迦南 on 2018/3/22.
//  Copyright © 2018年 迦南. All rights reserved.
//

#import "NSObject+LL_KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kLLkvoClassPrefix = @"LLObserver_";
static NSString *const kLLkvoAssiociateObserver = @"LLAssiociateObserver";

@interface LL_ObserverInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) LL_ObservingHandler handler;
@end

@implementation LL_ObserverInfo

- (instancetype)initWithObserver:(NSObject *)observer forKey:(NSString *)key observeHandler:(LL_ObservingHandler)handler {
    if (self = [super init]) {
        _observer = observer;
        _key = key;
        _handler = handler;
    }
    return self;
}
@end

@implementation NSObject (LL_KVO)

- (void)ll_addObserver:(NSObject *)object forKey:(NSString *)key withBlock:(LL_ObservingHandler)observedHandler {
    // 获取setter
    SEL setterSel =NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSel);
    
     // 判断是否有该方法，没有抛出异常
    if (!setterMethod) {
        @throw [NSException exceptionWithName: NSInvalidArgumentException reason: [NSString stringWithFormat: @"unrecognized selector sent to instance %@", self] userInfo: nil];
        return;
    }
    
    // 拿到当前类
    Class observedClass = object_getClass(self);
    NSString *className = NSStringFromClass(observedClass);
    
    
    //如果被监听者没有前缀，那么判断是否需要创建新类
    if (![className hasPrefix:kLLkvoClassPrefix]) {
        observedClass = [self createKVOClassWithOriginalClassName: className];
        // 修改 isa 指针指向新类
        object_setClass(self, observedClass);
    }
    
    // 判断是否有setter方法
    if (![self hasSelector:setterSel]) {
        // 如果没有给新类添加该方法
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(observedClass, setterSel, (IMP)KVO_setter, types);
    }
    
    // 创建一个类用来保存观察者
    LL_ObserverInfo *newInfo = [[LL_ObserverInfo alloc] initWithObserver:object forKey:key observeHandler:observedHandler];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge void *)kLLkvoAssiociateObserver);
    
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge void *)kLLkvoAssiociateObserver, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject: newInfo];
}

- (void)ll_removeObserver:(NSObject *)object forKey:(NSString *)key {
    
    // 获取保存被观察者的属性
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge void *)kLLkvoAssiociateObserver);
    
    // 遍历所有的观察者并移除
    LL_ObserverInfo *observerRemoved = nil;
    for (LL_ObserverInfo *observerInfo in observers) {
        
        if (observerInfo.observer == object && [observerInfo.key isEqualToString:key]) {
            observerRemoved = observerInfo;
            break;
        }
    }
    [observers removeObject:observerRemoved];
}

#pragma mark - 自定义方法
// getter转setter
static NSString *setterForGetter(NSString *getter) {
    // 如果没有该方法返回nil
    if (getter.length <= 0)  return nil;
    
    // 把第一个字符变大写
    NSString *firstString = [[getter substringToIndex: 1] uppercaseString];
    // 从第二个字符开始截取
    NSString *leaveString = [getter substringFromIndex: 1];
    
    // 返回拼接的setter字符串
    return [NSString stringWithFormat: @"set%@%@:", firstString, leaveString];
}

// setter转setter
static NSString *getterForSetter(NSString *setter) {
    
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) return nil;
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *getter = [setter substringWithRange:range];
    
    NSString *firstString = [[getter substringToIndex: 1] lowercaseString];
    getter = [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
    
    return getter;
}

// 创建子类
- (Class)createKVOClassWithOriginalClassName:(NSString *)className {
    // 拼接前缀字符串
    NSString *kvoClassName = [kLLkvoClassPrefix stringByAppendingString:className];
    // 获取新的类
    Class observedClass = NSClassFromString(kvoClassName);
    
    // 如果有当前这个类，则返回
    if (observedClass) return observedClass;
    
    //创建新类，并且添加LXDObserver_为类名新前缀
    Class originalClass = object_getClass(self);
     // 添加新类
    Class kvoClass = objc_allocateClassPair(originalClass, kvoClassName.UTF8String, 0);
    
    //获取监听对象的class方法实现代码，然后替换新建类的class实现
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    const char *types = method_getTypeEncoding(classMethod);
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_Class, types);
    
    // 注册新类
    objc_registerClassPair(kvoClass);
    return kvoClass;
}

static Class kvo_Class(id self) {
    return class_getSuperclass(object_getClass(self));
}

// 是否有该方法
- (BOOL)hasSelector: (SEL)selector {
    
    // isa指针已经指向了新的类
    Class observedClass = object_getClass(self);
    
    unsigned int methodCount = 0;
    // 获取新类的所有方法
    Method *methodList = class_copyMethodList(observedClass, &methodCount);
    
    for (int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        // 判断新类是否有传进来的方法
        if (thisSelector == selector) {
            
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}

// setter方法的实现
// 重写 setter 方法。新的 setter 在调用原 setter 方法后，通知每个观察者（调用之前传入的 block ）
static void KVO_setter(id self, SEL _cmd, id newValue) {
    
    NSString * setterName = NSStringFromSelector(_cmd);
    NSString * getterName = getterForSetter(setterName);
    if (!getterName) {
        @throw [NSException exceptionWithName: NSInvalidArgumentException reason: [NSString stringWithFormat: @"unrecognized selector sent to instance %p", self] userInfo: nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    struct objc_super superClass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // 进行类型转换
    // 新的 LLVM 会对 objc_msgSendSuper 以及 objc_msgSend 做严格的类型检查，如果不做类型转换。Xcode 会抱怨有 too many arguments 的错误
    // 赋新值
    [self willChangeValueForKey:getterName];
    void (*objc_msgSendSuperKVO)(void *, SEL, id) = (void *)objc_msgSendSuper;
    objc_msgSendSuperKVO(&superClass, _cmd, newValue);
    [self didChangeValueForKey: getterName];
    
    //获取所有监听回调对象进行回调
    NSMutableArray * observers = objc_getAssociatedObject(self, (__bridge const void *)kLLkvoAssiociateObserver);
    for (LL_ObserverInfo *info in observers) {
        if ([info.key isEqualToString: getterName]) {
            dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (info.handler) {
                     info.handler(self, getterName, oldValue, newValue);
                }
            });
        }
    }
}

@end
