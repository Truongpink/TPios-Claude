#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL TPIOSIsGADAdController(UIViewController *viewController)
{
    if (!viewController) {
        return NO;
    }

    NSString *name = NSStringFromClass(viewController.class).lowercaseString;

    // Chặn đúng nhóm controller fullscreen của Google Mobile Ads.
    // Không dùng "gad" chung để tránh chặn nhầm controller không phải quảng cáo.
    return [name containsString:@"gadfullscreenadviewcontroller"] ||
           [name containsString:@"gadinterstitialadviewcontroller"] ||
           [name containsString:@"gadrewardedadviewcontroller"] ||
           [name containsString:@"gadrewardedinterstitialadviewcontroller"] ||
           [name containsString:@"gadappopenadviewcontroller"];
}

void TPIOSGADInstallPresentationHook(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL originalSEL = @selector(presentViewController:animated:completion:);
        SEL replacementSEL = @selector(tpios_gad_presentViewController:animated:completion:);

        Method original = class_getInstanceMethod(UIViewController.class, originalSEL);
        Method replacement = class_getInstanceMethod(UIViewController.class, replacementSEL);

        if (!original || !replacement) {
            NSLog(@"TPIOSGAD: không cài được presentation hook");
            return;
        }

        method_exchangeImplementations(original, replacement);
        NSLog(@"TPIOSGAD: presentation hook đã cài");
    });
}

@interface UIViewController (TPIOSGADPresentationBlocker)
- (void)tpios_gad_presentViewController:(UIViewController *)viewControllerToPresent
                              animated:(BOOL)flag
                            completion:(void (^ __nullable)(void))completion;
@end

@implementation UIViewController (TPIOSGADPresentationBlocker)

- (void)tpios_gad_presentViewController:(UIViewController *)viewControllerToPresent
                              animated:(BOOL)flag
                            completion:(void (^ __nullable)(void))completion
{
    if (TPIOSIsGADAdController(viewControllerToPresent)) {
        NSLog(@"TPIOSGAD: BLOCK PRESENT %@", NSStringFromClass(viewControllerToPresent.class));
        completion ? completion() : (void)0;
        return;
    }

    [self tpios_gad_presentViewController:viewControllerToPresent
                                 animated:flag
                               completion:completion];
}

@end
