#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface LarpOverlay : NSObject <UIGestureRecognizerDelegate>
- (void)addSettingsEntry:(UIViewController *)settings;
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



