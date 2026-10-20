#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#include <string.h>

// Probe only factory-created static layout trees, never text input or candidate lists.
static id (*OriginalFactory)(id, SEL, id);
static NSMutableSet<NSString *> *Captured;
static NSObject *Lock;

static id ObjectProperty(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 ||
        signature.methodReturnType[0] != '@') return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
    @catch (__unused NSException *exception) { return nil; }
}

static NSString *RectProperty(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 ||
        strcmp(signature.methodReturnType, @encode(CGRect)) != 0) return nil;
    @try {
        CGRect rect = ((CGRect (*)(id, SEL))objc_msgSend)(object, selector);
        return NSStringFromCGRect(rect);
    } @catch (__unused NSException *exception) { return nil; }
}

static NSDictionary *Snapshot(id node, NSUInteger depth, NSUInteger *remaining,
                              NSHashTable *seen) {
    if (!node || depth > 24 || *remaining == 0 || [seen containsObject:node]) return @{};
    (*remaining)--;
    [seen addObject:node];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"class"] = NSStringFromClass([node class]);
    for (NSString *key in @[@"name", @"displayString", @"representedString"]) {
        id value = ObjectProperty(node, key);
        if ([value isKindOfClass:NSString.class]) result[key] = value;
    }
    for (NSString *key in @[@"frame", @"paddedFrame"]) {
        NSString *value = RectProperty(node, key);
        if (value) result[key] = value;
    }
    id children = ObjectProperty(node, @"subtrees");
    if ([children isKindOfClass:NSArray.class]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id child in children) {
            if (*remaining == 0) break;
            [items addObject:Snapshot(child, depth + 1, remaining, seen)];
        }
        result[@"children"] = items;
    }
    return result;
}

static id Factory(id self, SEL command, id name) {
    id tree = OriginalFactory(self, command, name);
    if (!tree || ![name isKindOfClass:NSString.class]) return tree;
    @synchronized (Lock) {
        if (Captured.count >= 24 || [Captured containsObject:name]) return tree;
        [Captured addObject:name];
    }
    @try {
        NSUInteger remaining = 2000;
        NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
        NSDictionary *report = @{
            @"schema": @1, @"keyboardName": name,
            @"systemVersion": UIDevice.currentDevice.systemVersion,
            @"process": NSProcessInfo.processInfo.processName,
            @"tree": Snapshot(tree, 0, &remaining, seen)
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        if (!data || data.length > 2 * 1024 * 1024) return tree;
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"StrokeLayoutDiagnostic"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *path = [directory stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"json"]];
        NSError *error = nil;
        BOOL written = [data writeToFile:path options:NSDataWritingAtomic error:&error];
        NSLog(@"[StrokeLayoutDiagnostic] keyboard=%@ report=%@ status=%@", name, path,
              written ? @"OK" : error.localizedDescription);
    } @catch (NSException *exception) {
        NSLog(@"[StrokeLayoutDiagnostic] snapshot failed: %@", exception.name);
    }
    return tree;
}

__attribute__((constructor)) static void Start(void) {
    @autoreleasepool {
        // Initial experiment is limited to Notes, avoiding broad system injection.
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobilenotes"]) return;
        Lock = [NSObject new];
        Captured = [NSMutableSet set];
        Class cls = NSClassFromString(@"TUIKBGraphSerialization");
        SEL selector = NSSelectorFromString(@"keyboardForName:");
        Class target = cls;
        Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
        if (!method && cls) {
            target = object_getClass(cls);
            method = class_getInstanceMethod(target, selector);
        }
        if (!method) {
            NSLog(@"[StrokeLayoutDiagnostic] factory unavailable; no hook installed");
            return;
        }
        char resultType[128] = {0}, argumentType[128] = {0};
        method_getReturnType(method, resultType, sizeof(resultType));
        method_getArgumentType(method, 2, argumentType, sizeof(argumentType));
        if (method_getNumberOfArguments(method) != 3 || resultType[0] != '@' || argumentType[0] != '@') {
            NSLog(@"[StrokeLayoutDiagnostic] unexpected factory signature; no hook installed");
            return;
        }
        MSHookMessageEx(target, selector, (IMP)Factory, (IMP *)&OriginalFactory);
        NSLog(@"[StrokeLayoutDiagnostic] static layout probe installed in Notes");
    }
}
