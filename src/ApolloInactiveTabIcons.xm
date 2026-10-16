#import "ApolloCommon.h"

// Keep inactive tab icons consistently tinted in the Classic interface.

%hook UITabBarButton

- (void)_updateToMatchCurrentState {
    %orig;

    if (IsLiquidGlass()) return;

    UITabBar *bar = nil;
    for (UIView *ancestor = (UIView *)self;
         ancestor;
         ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:UITabBar.class]) {
            bar = (UITabBar *)ancestor;
            break;
        }
    }

    if (!bar) return;

    NSMutableArray<UIView *> *pending =
        [NSMutableArray arrayWithObject:(UIView *)self];

    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];

        if ([NSStringFromClass(view.class)
                containsString:@"UITabBarSwappableImageView"]) {

            for (UIView *ancestor = view.superview;
                 ancestor && ancestor != (UIView *)self;
                 ancestor = ancestor.superview) {
                if ([ancestor isKindOfClass:UIVisualEffectView.class]) {
                    ((UIVisualEffectView *)ancestor).effect = nil;
                    break;
                }
            }

            view.tintColor = UIColor.magentaColor;


        }

        [pending addObjectsFromArray:view.subviews];
    }
}

%end

%hook UITabBarSwappableImageView

- (void)layoutSubviews {
    %orig;

    if (IsLiquidGlass()) return;

    UIView *button = ((UIView *)self).superview;
    if (![button isKindOfClass:NSClassFromString(@"UITabBarButton")]) return;
    if (((UIControl *)button).selected) return;

    UIImageView *icon = (UIImageView *)self;
    if (icon.image &&
        icon.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
        icon.image = [icon.image imageWithRenderingMode:
                      UIImageRenderingModeAlwaysTemplate];
        icon.tintColor = UIColor.magentaColor;
    }
}

- (void)setImage:(UIImage *)image {
    if (IsLiquidGlass()) {
        %orig;
        return;
    }

    %orig;

    UIImage *result = ((UIImageView *)self).image;
    UIView *button = ((UIView *)self).superview;

    if (result &&
        [button isKindOfClass:UIControl.class] &&
        !((UIControl *)button).selected) {

        // Pre-coloured pixels survive UIKit's rendering-mode changes.
        UIImage *coloured =
            [result imageWithTintColor:UIColor.magentaColor
                         renderingMode:UIImageRenderingModeAlwaysOriginal];

        %orig(coloured);
    }
}

%end
