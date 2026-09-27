#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *gInstalledClassName = nil;
static NSString *gInstalledPredicateName = nil;
static BOOL gInstalled = NO;

static BOOL TPIOSMethodReturnsBOOL(Method method)
{
    if (!method) return NO;

    char type[8] = {0};
    method_getReturnType(method, type, sizeof(type));

    return type[0] == 'B' || type[0] == 'c';
}

static BOOL TPIOSInstallInitHook(Class cls, SEL initSEL, SEL predicateSEL)
{
    Method method = class_getInstanceMethod(cls, initSEL);
    if (!method) return NO;

    // Only support the exact object-returning signatures we can call type-safely.
    if (initSEL == @selector(init)) {
        if (method_getNumberOfArguments(method) != 2) return NO;

        char returnType[8] = {0};
        method_getReturnType(method, returnType, sizeof(returnType));
        if (returnType[0] != '@') return NO;

        typedef id (*InitIMP)(id, SEL);
        InitIMP original = (InitIMP)method_getImplementation(method);

        id block = ^id(id object) {
            id result = original(object, initSEL);
            if (!result) return nil;

            BOOL (*PredicateIMP)(id, SEL) =
                (BOOL (*)(id, SEL))objc_msgSend;

            if (PredicateIMP(result, predicateSEL)) {
                return nil;
            }

            return result;
        };

        IMP replacement = imp_implementationWithBlock(block);
        method_setImplementation(method, replacement);
        return YES;
    }

    if (initSEL == @selector(initWithDictionary:error:)) {
        if (method_getNumberOfArguments(method) != 4) return NO;

        char returnType[8] = {0};
        char dictionaryType[8] = {0};
        char errorType[8] = {0};

        method_getReturnType(method, returnType, sizeof(returnType));
        method_getArgumentType(method, 2, dictionaryType, sizeof(dictionaryType));
        method_getArgumentType(method, 3, errorType, sizeof(errorType));

        if (returnType[0] != '@' ||
            dictionaryType[0] != '@' ||
            errorType[0] != '^') {
            return NO;
        }

        typedef id (*InitDictionaryIMP)(id, SEL, NSDictionary *, NSError **);
        InitDictionaryIMP original =
            (InitDictionaryIMP)method_getImplementation(method);

        id block = ^id(id object, NSDictionary *dictionary, NSError **error) {
            id result = original(object, initSEL, dictionary, error);
            if (!result) return nil;

            BOOL (*PredicateIMP)(id, SEL) =
                (BOOL (*)(id, SEL))objc_msgSend;

            if (PredicateIMP(result, predicateSEL)) {
                return nil;
            }

            return result;
        };

        IMP replacement = imp_implementationWithBlock(block);
        method_setImplementation(method, replacement);
        return YES;
    }

    return NO;
}

BOOL TPIOSModelFilterInstall(
    NSString *className,
    NSString *predicateName,
    NSString *initializer1,
    NSString *initializer2
)
{
    if (gInstalled) {
        return [gInstalledClassName isEqualToString:className] &&
               [gInstalledPredicateName isEqualToString:predicateName];
    }

    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    SEL predicateSEL = NSSelectorFromString(predicateName);
    Method predicateMethod = class_getInstanceMethod(cls, predicateSEL);

    if (!predicateMethod || !TPIOSMethodReturnsBOOL(predicateMethod)) {
        return NO;
    }

    BOOL installedAny = NO;

    if (initializer1.length > 0) {
        SEL initSEL = NSSelectorFromString(initializer1);
        installedAny = TPIOSInstallInitHook(cls, initSEL, predicateSEL) || installedAny;
    }

    if (initializer2.length > 0) {
        SEL initSEL = NSSelectorFromString(initializer2);
        installedAny = TPIOSInstallInitHook(cls, initSEL, predicateSEL) || installedAny;
    }

    if (!installedAny) return NO;

    gInstalledClassName = [className copy];
    gInstalledPredicateName = [predicateName copy];
    gInstalled = YES;

    NSLog(@"[TPIOS] ModelFilter installed: %@ %@ -> %@/%@",
          className, predicateName, initializer1, initializer2);

    return YES;
}

BOOL TPIOSModelFilterIsInstalled(void)
{
    return gInstalled;
}
