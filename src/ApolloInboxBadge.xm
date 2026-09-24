// Inbox-only presentation. Apollo remains the sole owner of unread state.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "ApolloThemeRuntime.h"
#import "UserDefaultConstants.h"

static char kInboxBadgeDotViewKey;
static NSHashTable<UITabBarController *> *sInboxBadgeControllers;

static void ApolloInboxBadgeCollectViews(UIView *root, Class cls, NSMutableArray<UIView *> *result) {
    if (!cls) return;
    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:cls]) {
            [result addObject:view];
        } else {
            ApolloInboxBadgeCollectViews(view, cls, result);
        }
    }
}

static UIImageView *ApolloInboxBadgeIconView(UIView *root) {
    UIImageView *fallback = nil;

    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:UIImageView.class]) {
            UIImageView *imageView = (UIImageView *)view;
            if (imageView.image) return imageView;
            fallback = imageView;
        }

        UIImageView *nested = ApolloInboxBadgeIconView(view);
        if (nested) return nested;
    }

    return fallback;
}

static void ApolloInboxBadgeSetCustomDot(UIView *button,
                                         UIView *icon,
                                         BOOL visible,
                                         UIColor *color) {
    UIView *dot = objc_getAssociatedObject(button, &kInboxBadgeDotViewKey);

    if (!visible || !icon) {
        dot.hidden = YES;
        return;
    }

    if (!dot) {
        dot = [[UIView alloc] initWithFrame:CGRectZero];
        dot.userInteractionEnabled = NO;
        dot.layer.cornerRadius = 4.0;
        objc_setAssociatedObject(button,
                                 &kInboxBadgeDotViewKey,
                                 dot,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addSubview:dot];
    }

    CGRect iconFrame = [button convertRect:icon.bounds fromView:icon];

    // Keep the dot anchored to the icon as the tab layout changes.
    dot.frame = CGRectMake(CGRectGetMaxX(iconFrame) + 4.0,
                           CGRectGetMinY(iconFrame) + 20.0,
                           8.0,
                           8.0);
    dot.backgroundColor = color;
    dot.hidden = NO;
    [button bringSubviewToFront:dot];
}

static void ApolloInboxBadgeApply(UITabBarController *controller) {
    UITabBar *tabBar = controller.tabBar;
    if (tabBar.items.count < 2) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    UITabBarItem *inbox = tabBar.items[1];
    // nil selects UIKit's native red. Use the public item API so number mode
    // keeps its native background rendering, geometry, and label untouched.
    UIColor *color = [defaults boolForKey:UDKeyInboxBadgeUseThemeAccent]
        ? [(ApolloThemeAccentColor() ?: tabBar.tintColor) resolvedColorWithTraitCollection:tabBar.traitCollection]
        : nil;
    if (inbox.badgeColor != color && ![inbox.badgeColor isEqual:color]) inbox.badgeColor = color;

    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    ApolloInboxBadgeCollectViews(tabBar, NSClassFromString(@"UITabBarButton"), buttons);
    // Fail closed if UIKit presents a different hierarchy (e.g. an iPad sidebar).
    if (buttons.count != tabBar.items.count) return;
    BOOL rtl = tabBar.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    [buttons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMidX([a convertRect:a.bounds toView:tabBar]);
        CGFloat bx = CGRectGetMidX([b convertRect:b.bounds toView:tabBar]);
        if (ax == bx) return NSOrderedSame;
        return (ax < bx) != rtl ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray<UIView *> *badges = [NSMutableArray array];
    ApolloInboxBadgeCollectViews(buttons[1], NSClassFromString(@"_UIBadgeView"), badges);
    BOOL dotMode = ![defaults boolForKey:UDKeyInboxBadgeShowUnreadCount];
    UIColor *renderedColor =
        color ?: [UIColor colorWithRed:1.0
                                green:0.231
                                blue:0.188
                                alpha:1.0];

    for (UIView *badge in badges) {
        // Number mode keeps UIKit's native badge geometry and label.
        badge.backgroundColor = renderedColor;
        badge.hidden = dotMode;
    }

    UIImageView *icon = ApolloInboxBadgeIconView(buttons[1]);
    BOOL hasUnreadBadge = badges.count > 0;

    ApolloInboxBadgeSetCustomDot(buttons[1],
                                icon,
                                dotMode && hasUnreadBadge,
                                renderedColor);
}

// ApolloTabBarController is Swift, so its runtime name is the mangled class
// name below. Hooking the unmangled spelling silently matches nothing.
%hook _TtC6Apollo22ApolloTabBarController

- (void)viewDidLoad {
    %orig;
    [sInboxBadgeControllers addObject:(UITabBarController *)self];
}

- (void)viewDidLayoutSubviews {
    %orig;
    ApolloInboxBadgeApply((UITabBarController *)self);
}

%end

%ctor {
    sInboxBadgeControllers = [NSHashTable weakObjectsHashTable];
    for (NSString *name in @[ApolloInboxBadgeChangedNotification,
                             @"com.christianselig.ApolloSpecificThemeChanged"]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil
            queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
            // Let Apollo finish any native theme updates before refreshing.
            dispatch_async(dispatch_get_main_queue(), ^{
                for (UITabBarController *controller in sInboxBadgeControllers) {
                    [controller.tabBar layoutIfNeeded];
                    ApolloInboxBadgeApply(controller);
                }
            });
        }];
    }
}
