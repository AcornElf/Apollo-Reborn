// Inbox-only presentation. Apollo remains the sole owner of unread state.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "ApolloThemeRuntime.h"
#import "UserDefaultConstants.h"

static char kInboxBadgeDotStateKey;
static NSHashTable<UITabBarController *> *sInboxBadgeControllers;

@interface ApolloInboxBadgeDotState : NSObject
@property (nonatomic, strong) CALayer *originalMask;
@property (nonatomic, strong) CAShapeLayer *dotMask;
@property (nonatomic, strong) NSMapTable<UILabel *, NSNumber *> *labelVisibility;
@end
@implementation ApolloInboxBadgeDotState
@end

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

static void ApolloInboxBadgeSetDot(UIView *badge, BOOL dot) {
    ApolloInboxBadgeDotState *state = objc_getAssociatedObject(badge, &kInboxBadgeDotStateKey);
    if (!dot) {
        if (!state) return;
        if (badge.layer.mask == state.dotMask) badge.layer.mask = state.originalMask;
        for (UILabel *label in state.labelVisibility) {
            label.hidden = [[state.labelVisibility objectForKey:label] boolValue];
        }
        objc_setAssociatedObject(badge, &kInboxBadgeDotStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!state) {
        state = [ApolloInboxBadgeDotState new];
        state.originalMask = badge.layer.mask;
        state.dotMask = [CAShapeLayer layer];
        state.dotMask.fillColor = UIColor.blackColor.CGColor;
        state.labelVisibility = [NSMapTable weakToStrongObjectsMapTable];
        objc_setAssociatedObject(badge, &kInboxBadgeDotStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSMutableArray<UIView *> *labels = [NSMutableArray array];
    ApolloInboxBadgeCollectViews(badge, UILabel.class, labels);
    for (UILabel *label in labels) {
        if (![state.labelVisibility objectForKey:label]) {
            [state.labelVisibility setObject:@(label.hidden) forKey:label];
        }
        if (!label.hidden) label.hidden = YES;
    }

    // Crop the native fill to an 8pt circle instead of changing private UIKit
    // frames from a layout callback. This avoids layout feedback and preserves
    // the current count's natural geometry through count changes and rotation.
    // Neither badgeValue nor the badge's own hidden/alpha state is changed.
    CGRect bounds = badge.bounds;
    CGRect circle = CGRectMake(CGRectGetMidX(bounds) - 4.0, CGRectGetMidY(bounds) - 4.0, 8.0, 8.0);
    CGPathRef path = [UIBezierPath bezierPathWithOvalInRect:circle].CGPath;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!state.dotMask.path || !CGPathEqualToPath(state.dotMask.path, path)) state.dotMask.path = path;
    if (badge.layer.mask != state.dotMask) badge.layer.mask = state.dotMask;
    [CATransaction commit];
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
    BOOL dot = ![defaults boolForKey:UDKeyInboxBadgeShowUnreadCount];
    for (UIView *badge in badges) ApolloInboxBadgeSetDot(badge, dot);
}

%hook ApolloTabBarController

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
