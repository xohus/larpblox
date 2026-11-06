#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static NSString *MoreTileKey(NSString *label) {
    if (![label isKindOfClass:NSString.class]) return @"";
    return [[[label lowercaseString] componentsSeparatedByCharactersInSet:
        NSCharacterSet.alphanumericCharacterSet.invertedSet] componentsJoinedByString:@""];
}

static void FindMoreTiles(id node, NSMutableDictionary<NSString *, NSValue *> *frames,
                          NSHashTable *visited, NSUInteger *remaining) {
    if (!node || !*remaining || [visited containsObject:node] || frames.count == 3) return;
    (*remaining)--;
    [visited addObject:node];

    if ([node isKindOfClass:UIView.class]) {
        UIView *view = node;
        if (view.hidden || view.alpha < 0.01) return;
    }
    NSString *key = MoreTileKey([node accessibilityLabel]);
    if ([key isEqualToString:@"quicklogin"]) key = @"quicksignin";
    if ([@[@"quicksignin", @"helpsafety", @"learn"] containsObject:key]) {
        CGRect frame = [node accessibilityFrame];
        if (!CGRectIsEmpty(frame) && !CGRectIsInfinite(frame)) {
            frames[key] = [NSValue valueWithCGRect:frame];
        }
    }
    for (id child in [node accessibilityElements]) {
        if (!*remaining || frames.count == 3) break;
        FindMoreTiles(child, frames, visited, remaining);
    }
    if ([node isKindOfClass:UIView.class]) {
        for (UIView *child in [(UIView *)node subviews]) {
            if (!*remaining || frames.count == 3) break;
            FindMoreTiles(child, frames, visited, remaining);
        }
    }
    if (![node accessibilityElements] && [node respondsToSelector:@selector(accessibilityElementCount)]) {
        NSInteger count = MIN([node accessibilityElementCount], 180);
        for (NSInteger index = 0; index < count && *remaining && frames.count < 3; index++) {
            FindMoreTiles([node accessibilityElementAtIndex:index], frames, visited, remaining);
        }
    }
}

static UIImage *MoreMascot(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [UIColor.blackColor setStroke];
        [UIColor.blackColor setFill];
        UIBezierPath *cube = [UIBezierPath bezierPath];
        [cube moveToPoint:CGPointMake(4, 12)];
        [cube addLineToPoint:CGPointMake(15, 5)];
        [cube addLineToPoint:CGPointMake(33, 9)];
        [cube addLineToPoint:CGPointMake(36, 29)];
        [cube addLineToPoint:CGPointMake(26, 36)];
        [cube addLineToPoint:CGPointMake(6, 32)];
        [cube closePath];
        [cube moveToPoint:CGPointMake(4, 12)];
        [cube addLineToPoint:CGPointMake(24, 16)];
        [cube addLineToPoint:CGPointMake(33, 9)];
        [cube moveToPoint:CGPointMake(24, 16)];
        [cube addLineToPoint:CGPointMake(26, 36)];
        cube.lineWidth = 2;
        cube.lineJoinStyle = kCGLineJoinRound;
        [cube stroke];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 18, 4, 6) cornerRadius:1] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(17, 20, 4, 6) cornerRadius:1] fill];
    }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface LarpOverlay : NSObject <UIGestureRecognizerDelegate>
- (void)addSettingsEntry:(UIViewController *)settings;
- (void)openFromWindow:(UIWindow *)window;
- (void)refreshMoreTileInWindow:(UIWindow *)window;
@end

@implementation LarpOverlay
- (void)attachToWindow:(NSNotification *)notification {
    UIWindow *window = notification.object;
    if (![window isKindOfClass:UIWindow.class]) return;
    for (UIGestureRecognizer *gesture in window.gestureRecognizers) {
        if ([gesture.name isEqualToString:@"LarpOverlay"]) return;
    }
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(open:)];
    swipe.name = @"LarpOverlay";
    swipe.direction = UISwipeGestureRecognizerDirectionDown;
    swipe.numberOfTouchesRequired = 3;
    swipe.cancelsTouchesInView = NO;
    swipe.delegate = self;
    [window addGestureRecognizer:swipe];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (void)close:(UIButton *)sender {
    UIViewController *menu = sender.window.rootViewController;
    while (menu.presentedViewController) menu = menu.presentedViewController;
    if ([menu.view.accessibilityIdentifier isEqualToString:@"LarpOverlay"]) {
        [menu dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)open:(UISwipeGestureRecognizer *)gesture {
    [self openFromWindow:gesture.view.window];
}

- (void)openFromSettings:(UIButton *)button {
    [self openFromWindow:button.window];
}

- (void)refreshMoreTiles:(NSTimer *)timer {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) [self refreshMoreTileInWindow:window];
        }
    }
}

- (void)refreshMoreTileInWindow:(UIWindow *)window {
    static const NSInteger tileTag = 0x4C425854;
    UIButton *tile = (UIButton *)[window viewWithTag:tileTag];
    UIViewController *root = window.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    if (!root || [root.view.accessibilityIdentifier isEqualToString:@"LarpOverlay"]) {
        tile.hidden = YES;
        return;
    }

    NSMutableDictionary<NSString *, NSValue *> *frames = [NSMutableDictionary dictionary];
    NSUInteger remaining = 2400;
    NSHashTable *visited = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    FindMoreTiles(root.view, frames, visited, &remaining);
    if (frames.count != 3) { tile.hidden = YES; return; }

    CGRect quick = [window convertRect:frames[@"quicksignin"].CGRectValue
                   fromCoordinateSpace:window.screen.coordinateSpace];
    CGRect help = [window convertRect:frames[@"helpsafety"].CGRectValue
                  fromCoordinateSpace:window.screen.coordinateSpace];
    CGRect learn = [window convertRect:frames[@"learn"].CGRectValue
                   fromCoordinateSpace:window.screen.coordinateSpace];
    CGFloat pitch = CGRectGetMidX(quick) - CGRectGetMidX(help);
    CGFloat rowPitch = CGRectGetMidY(quick) - CGRectGetMidY(learn);
    if (pitch < 65 || rowPitch < 65 ||
        fabs(CGRectGetMidY(quick) - CGRectGetMidY(help)) > 12 ||
        fabs(CGRectGetMidX(learn) - CGRectGetMidX(quick) - pitch) > 20) {
        tile.hidden = YES;
        return;
    }

    CGFloat side = MIN(pitch, rowPitch) * 0.875;
    CGFloat centerY = CGRectGetMidY(quick);
    if (CGRectGetHeight(quick) < side * 0.6) centerY -= side * 0.18;
    CGRect frame = CGRectMake(CGRectGetMidX(learn) - side / 2, centerY - side / 2, side, side);
    if (!CGRectContainsRect(UIEdgeInsetsInsetRect(window.bounds, window.safeAreaInsets), frame)) {
        tile.hidden = YES;
        return;
    }

    if (!tile) {
        tile = [UIButton buttonWithType:UIButtonTypeSystem];
        tile.tag = tileTag;
        tile.accessibilityLabel = @"LarpBlox";
        tile.layer.cornerRadius = 9;
        [tile addTarget:self action:@selector(openFromSettings:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *icon = [[UIImageView alloc] initWithImage:MoreMascot()];
        icon.tag = 1;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        UILabel *label = [UILabel new];
        label.tag = 2;
        label.text = @"LarpBlox";
        label.textAlignment = NSTextAlignmentCenter;
        [tile addSubview:icon];
        [tile addSubview:label];
        [window addSubview:tile];
    }
    BOOL dark = window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    tile.frame = frame;
    tile.backgroundColor = dark ? [UIColor colorWithWhite:0.14 alpha:1] : [UIColor colorWithWhite:0.96 alpha:1];
    UIImageView *icon = (UIImageView *)[tile viewWithTag:1];
    CGFloat iconSize = side * 0.28;
    icon.frame = CGRectMake((side - iconSize) / 2, side * 0.25, iconSize, iconSize);
    icon.tintColor = dark ? UIColor.whiteColor : UIColor.blackColor;
    UILabel *label = (UILabel *)[tile viewWithTag:2];
    label.frame = CGRectMake(0, side * 0.60, side, side * 0.16);
    label.font = [UIFont systemFontOfSize:MIN(18, side * 0.10) weight:UIFontWeightSemibold];
    label.textColor = dark ? UIColor.whiteColor : UIColor.blackColor;
    tile.hidden = NO;
    [window bringSubviewToFront:tile];
}

- (void)addSettingsEntry:(UIViewController *)settings {
    static const NSInteger entryTag = 0x4C42584D;
    UIView *view = settings.view;
    if ([view viewWithTag:entryTag]) return;

    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];
    entry.tag = entryTag;
    entry.translatesAutoresizingMaskIntoConstraints = NO;
    entry.backgroundColor = UIColor.blackColor;
    entry.layer.cornerRadius = 8;
    [entry setTitle:@"LarpBlox" forState:UIControlStateNormal];
    [entry setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [entry addTarget:self action:@selector(openFromSettings:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:entry];
    UILayoutGuide *safe = view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [entry.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [entry.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [entry.heightAnchor constraintEqualToConstant:44],
        [entry.widthAnchor constraintEqualToConstant:104]
    ]];
}

- (void)openFromWindow:(UIWindow *)window {
    UIViewController *presenter = window.rootViewController;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if (!presenter || [presenter.view.accessibilityIdentifier isEqualToString:@"LarpOverlay"]) return;

    NSURL *file = [NSBundle.mainBundle URLForResource:@"LarpConsole" withExtension:@"html"];
    if (!file) return;

    UIViewController *menu = [UIViewController new];
    menu.modalPresentationStyle = UIModalPresentationFullScreen;
    menu.view.accessibilityIdentifier = @"LarpOverlay";
    menu.view.backgroundColor = UIColor.blackColor;
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"Close" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [close addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];

    WKWebView *web = [[WKWebView alloc] initWithFrame:CGRectZero];
    UIStackView *layout = [[UIStackView alloc] initWithArrangedSubviews:@[close, web]];
    layout.axis = UILayoutConstraintAxisVertical;
    layout.translatesAutoresizingMaskIntoConstraints = NO;
    [menu.view addSubview:layout];
    UILayoutGuide *safe = menu.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [layout.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [layout.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [layout.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [layout.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [close.heightAnchor constraintEqualToConstant:44]
    ]];
    [web loadFileURL:file allowingReadAccessToURL:file];
    [presenter presentViewController:menu animated:YES completion:nil];
}
@end

static void InstallSettingsEntry(LarpOverlay *overlay) {
    Class settingsClass = NSClassFromString(@"RBWebSettingsViewController");
    SEL selector = @selector(viewDidAppear:);
    Method method = settingsClass ? class_getInstanceMethod(settingsClass, selector) : NULL;
    if (!method) return;

    IMP original = method_getImplementation(method);
    IMP hook = imp_implementationWithBlock(^(UIViewController *settings, BOOL animated) {
        ((void (*)(id, SEL, BOOL))original)(settings, selector, animated);
        if (object_getClass(settings) == settingsClass) {
            [overlay addSettingsEntry:settings];
        }
    });
    // Replace only the Settings implementation, even when it inherits this method.
    class_replaceMethod(settingsClass, selector, hook, method_getTypeEncoding(method));
}

__attribute__((constructor)) static void InstallLarpOverlay(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static LarpOverlay *overlay;
        overlay = [LarpOverlay new];
        InstallSettingsEntry(overlay);
        [NSTimer scheduledTimerWithTimeInterval:0.35 target:overlay
            selector:@selector(refreshMoreTiles:) userInfo:nil repeats:YES];
        [NSNotificationCenter.defaultCenter addObserver:overlay
            selector:@selector(attachToWindow:) name:UIWindowDidBecomeKeyNotification object:nil];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) {
                    [overlay attachToWindow:[NSNotification
                        notificationWithName:UIWindowDidBecomeKeyNotification object:window]];
                }
            }
        }
    });
}






