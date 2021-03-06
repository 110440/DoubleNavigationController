//
//  UIViewController+DoubleNavigationController.m
//  DoubleNavigationController
//
//  Created by Yao Li on 2018/11/12.
//

#import "UIViewController+DoubleNavigationController.h"
#import <objc/runtime.h>
#import "DNBMethodSwizzle.h"
#import "DBNNavigationDecoration.h"

@interface UIViewController (DoubleNavigationController_Private)
@property (strong, nonatomic) UIView *dbn_fakeNavigationBar;
@property (assign, nonatomic) BOOL dbn_viewAppeared;
@property (assign, nonatomic) BOOL dbn_needsUpdateNavigation;

@property (strong, nonatomic) DBNNavigationDecoration *dbn_navigationDecoration;

- (void)setDbn_secondNavigationBarHidden:(BOOL)hidden;
@end

@interface UINavigationController (DoubleNavigationController_Private)
@property (assign, nonatomic) BOOL dbn_realNavigationBarHidden;

- (void)dbn_setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;
@end

@implementation UIViewController (DoubleNavigationController_Private) 
+ (void)load {
    static dispatch_once_t dbnOnceToken;
    dispatch_once(&dbnOnceToken, ^{
        Class clz = [self class];
        DBNSwizzleMethod(clz, @selector(viewWillAppear:), clz, @selector(dbn_viewWillAppear:));
        DBNSwizzleMethod(clz, @selector(viewDidAppear:), clz, @selector(dbn_viewDidAppear:));
        DBNSwizzleMethod(clz, @selector(viewWillDisappear:), clz, @selector(dbn_viewWillDisappear:));
    });
}

#pragma mark - Method Swizzling
- (void)dbn_viewWillAppear:(BOOL)animated {
    [self dbn_viewWillAppear:animated];
    if (!self.navigationController) {
        return;
    }
    
    if (!self.dbn_viewAppeared) {
        __weak typeof(self) _self = self;
        if ([self respondsToSelector:@selector(dbn_configNavigationController:)]) {
            [self performSelector:@selector(dbn_configNavigationController:) withObject:self.navigationController];
            [self.dbn_navigationDecoration addUpdates:^(UINavigationController * _Nullable navigationController) {
                __strong typeof(_self) self = _self;
                [self performSelector:@selector(dbn_configNavigationController:) withObject:navigationController];
            }];
        }
        if ([self respondsToSelector:@selector(dbn_configNavigationItem:)]) {
            [self performSelector:@selector(dbn_configNavigationItem:) withObject:self.navigationItem];
        }
        [self.navigationController dbn_setNavigationBarHidden:NO animated:NO];
        [self setDbn_secondNavigationBarHidden:NO];
        [self.navigationController dbn_setNavigationBarHidden:YES animated:NO];
    } else {
        [self.dbn_navigationDecoration doDecorate];
        [self setDbn_secondNavigationBarHidden:NO];
        [self.navigationController dbn_setNavigationBarHidden:YES animated:NO];
    }
}

- (void)dbn_viewDidAppear:(BOOL)animated {
    [self dbn_viewDidAppear:animated];
    
    if (!self.navigationController) {
        return;
    }
    
    UINavigationBar *bar = (UINavigationBar *)self.dbn_fakeNavigationBar;
    if (bar) {
        [self navigationBar:self.navigationController.navigationBar imitate:bar];
    }
    
    if (!self.dbn_viewAppeared) {
        self.dbn_viewAppeared = YES;
        [self setDbn_secondNavigationBarHidden:YES];
        [self.navigationController dbn_setNavigationBarHidden:self.navigationController.dbn_realNavigationBarHidden animated:NO];
    } else {
        [self setDbn_secondNavigationBarHidden:YES];
        [self.dbn_navigationDecoration doDecorate];
        [self.navigationController dbn_setNavigationBarHidden:self.navigationController.dbn_realNavigationBarHidden animated:NO];
    }
}

- (void)dbn_viewWillDisappear:(BOOL)animated {
    [self dbn_viewWillDisappear:animated];

    if (!self.navigationController
        && !self.dbn_fakeNavigationBar) { // self.navigationController will be nil when popToRootViewController
        return;
    }
    
    [self setDbn_secondNavigationBarHidden:NO];
    [self.navigationController dbn_setNavigationBarHidden:YES animated:NO];
}

- (void)setDbn_secondNavigationBarHidden:(BOOL)hidden {
    if (self.navigationController.dbn_realNavigationBarHidden) {
        self.dbn_fakeNavigationBar.hidden = YES;
        return;
    }
    
    UIView *fakeNavigationBar = self.dbn_fakeNavigationBar;
    if (!self.navigationController
        && !fakeNavigationBar) {
        return;
    }
    
    if (!objc_getAssociatedObject(self, @selector(dbn_fakeNavigationBar))
        || self.dbn_needsUpdateNavigation) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.navigationController.navigationBar];
        fakeNavigationBar = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (self.dbn_fakeNavigationBar.superview) {
            [self.dbn_fakeNavigationBar removeFromSuperview];
        }
        self.dbn_fakeNavigationBar = fakeNavigationBar;
        self.dbn_needsUpdateNavigation = NO;
        [self.view addSubview:fakeNavigationBar];
        [self navigationBar:(UINavigationBar *)fakeNavigationBar imitate:self.navigationController.navigationBar]; // UIAppearance will be setted after the navigationBar has been added to super view
    }
    
    [self.view bringSubviewToFront:fakeNavigationBar];
    fakeNavigationBar.hidden = hidden;
}

- (void)navigationBar:(UINavigationBar *)navigationBar imitate:(UINavigationBar *)navigationBarImitated {
    navigationBar.barStyle = navigationBarImitated.barStyle;
    navigationBar.translucent = navigationBarImitated.isTranslucent;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        navigationBar.prefersLargeTitles = navigationBarImitated.prefersLargeTitles;
        navigationBar.largeTitleTextAttributes = navigationBarImitated.largeTitleTextAttributes;
    }
#endif
    navigationBar.tintColor = navigationBarImitated.tintColor;
    navigationBar.barTintColor = navigationBarImitated.barTintColor;
    navigationBar.shadowImage = navigationBarImitated.shadowImage;
    navigationBar.titleTextAttributes = navigationBarImitated.titleTextAttributes;
    navigationBar.backIndicatorImage = navigationBarImitated.backIndicatorImage;
    navigationBar.backIndicatorTransitionMaskImage = navigationBarImitated.backIndicatorTransitionMaskImage;
}

#pragma mark - setter & getter
- (UIView *)dbn_fakeNavigationBar {
    return objc_getAssociatedObject(self, @selector(dbn_fakeNavigationBar));
}

- (void)setDbn_fakeNavigationBar:(UIView *)dbn_fakeNavigationBar {
    objc_setAssociatedObject(self, @selector(dbn_fakeNavigationBar), dbn_fakeNavigationBar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)dbn_viewAppeared {
    return [objc_getAssociatedObject(self, @selector(dbn_viewAppeared)) boolValue];
}

- (void)setDbn_viewAppeared:(BOOL)dbn_viewAppeared {
    objc_setAssociatedObject(self, @selector(dbn_viewAppeared), [NSNumber numberWithBool:dbn_viewAppeared], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)dbn_needsUpdateNavigation {
    return [objc_getAssociatedObject(self, @selector(dbn_needsUpdateNavigation)) boolValue];
}

- (void)setDbn_needsUpdateNavigation:(BOOL)dbn_needsUpdateNavigation {
    objc_setAssociatedObject(self, @selector(dbn_needsUpdateNavigation), [NSNumber numberWithBool:dbn_needsUpdateNavigation], OBJC_ASSOCIATION_RETAIN);
}

- (DBNNavigationDecoration *)dbn_navigationDecoration {
    if (!objc_getAssociatedObject(self, @selector(dbn_navigationDecoration))) {
        DBNNavigationDecoration *decoration = [[DBNNavigationDecoration alloc] initWithNavigationController:self.navigationController];
        objc_setAssociatedObject(self, @selector(dbn_navigationDecoration), decoration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return objc_getAssociatedObject(self, @selector(dbn_navigationDecoration));
}

- (void)setDbn_navigationDecoration:(DBNNavigationDecoration *)dbn_navigationDecoration {
    objc_setAssociatedObject(self, @selector(dbn_navigationDecoration), dbn_navigationDecoration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end


@implementation UINavigationController (DoubleNavigationController_Private)
+ (void)load {
    static dispatch_once_t dbnOnceToken;
    dispatch_once(&dbnOnceToken, ^{
        Class clz = [self class];
        DBNSwizzleMethod(clz, @selector(setNavigationBarHidden:animated:), clz, @selector(dbn_setNavigationBarHidden:animated:));
    });
}

- (void)dbn_setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated {
    self.dbn_realNavigationBarHidden = hidden;
    [self dbn_setNavigationBarHidden:hidden animated:animated];
}

- (BOOL)dbn_realNavigationBarHidden {
    return [objc_getAssociatedObject(self, @selector(dbn_realNavigationBarHidden)) boolValue];
}

- (void)setDbn_realNavigationBarHidden:(BOOL)dbn_realNavigationBarHidden {
    objc_setAssociatedObject(self, @selector(dbn_realNavigationBarHidden), [NSNumber numberWithBool:dbn_realNavigationBarHidden], OBJC_ASSOCIATION_RETAIN);
}
@end


@implementation UIViewController (DoubleNavigationController)
- (void)dbn_setNeedsUpdateNavigation {
    self.dbn_needsUpdateNavigation = YES;
}

- (void)dbn_performBatchUpdates:(void (^)(UINavigationController * _Nonnull))updates {
    if (updates) {
        updates(self.navigationController);
        [self.dbn_navigationDecoration addUpdates:updates];
        self.dbn_needsUpdateNavigation = YES;
    }
    NSArray<UIViewController *> *viewControllers = self.navigationController.viewControllers;
    for (NSUInteger i=[viewControllers indexOfObject:self] + 1; i<[viewControllers indexOfObject:self.navigationController.topViewController] + 1; i++) {
        [viewControllers[i].dbn_navigationDecoration addUpdates:updates];
        viewControllers[i].dbn_needsUpdateNavigation = YES;
    }
}
@end
