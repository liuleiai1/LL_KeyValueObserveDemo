//
//  ViewController.m
//  LL_KeyValueObserveDemo
//
//  Created by 迦南 on 2018/3/22.
//  Copyright © 2018年 迦南. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+LL_KVO.h"
#import "ObservedObject.h"

@interface ViewController ()

@property (nonatomic, strong) ObservedObject *object;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    ObservedObject *object = [[ObservedObject alloc] init];
    [object ll_addObserver:self forKey:@"observedNum" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@--%@--%@--%@", observedObject, observedKey, oldValue, newValue);
    }];
    
    object.observedNum = @(5);
    object.observedNum = @(8);
    _object = object;
}

- (void)dealloc {
    [_object ll_removeObserver:self forKey:@"observedNum"];
}
@end
