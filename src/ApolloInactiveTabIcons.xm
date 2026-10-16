#import "ApolloCommon.h"
#import "ApolloThemeRuntime.h"
#import <math.h>

static CGFloat ApolloTabIconLinearComponent(CGFloat value) {
    return value <= 0.04045
        ? value / 12.92
        : pow((value + 0.055) / 1.055, 2.4);
}

static CGFloat ApolloTabIconLuminance(UIColor *color) {
    CGFloat red, green, blue, alpha;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha])
        return 0.0;

    return 0.2126 * ApolloTabIconLinearComponent(red)
         + 0.7152 * ApolloTabIconLinearComponent(green)
         + 0.0722 * ApolloTabIconLinearComponent(blue);
}

static UIColor *ApolloInactiveTabIconColor(UITraitCollection *traits) {
    UIColor *accent = ApolloThemeAccentColor();
    if (!accent) return nil;
    if (traits) accent = [accent resolvedColorWithTraitCollection:traits];

    CGFloat hue, saturation, brightness, alpha;
    if (![accent getHue:&hue
              saturation:&saturation
              brightness:&brightness
                   alpha:&alpha]) {
        return accent;
    }

    // Preserve a consistent luminance relationship with the selected accent.
    const CGFloat targetRatio = 0.287441 / 0.248283;
    BOOL darkMode = traits.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat target = MIN(ApolloTabIconLuminance(accent) * targetRatio * (darkMode ? 0.85 : 1.05), 1.0);
    // Apply extra desaturation around green, fading smoothly towards other hues.
    CGFloat greenDistance = fabs(hue - 120.0 / 360.0);
    greenDistance = MIN(greenDistance, 1.0 - greenDistance);
    CGFloat greenWeight = MAX(0.0, 1.0 - greenDistance / (60.0 / 360.0));
    greenWeight = greenWeight * greenWeight * (3.0 - 2.0 * greenWeight);

    CGFloat saturationFactor = (darkMode ? 0.30 : 0.35) - 0.10 * greenWeight;
    CGFloat mutedSaturation = saturation * saturationFactor;
    CGFloat mutedHue = fmod(hue - 10.0 / 360.0 + 1.0, 1.0);

    CGFloat low = 0.0;
    CGFloat high = 1.0;

    for (NSInteger i = 0; i < 16; i++) {
        CGFloat mid = (low + high) / 2.0;
        UIColor *candidate = [UIColor colorWithHue:mutedHue
                                        saturation:mutedSaturation
                                        brightness:mid
                                             alpha:alpha];

        if (ApolloTabIconLuminance(candidate) < target)
            low = mid;
        else
            high = mid;
    }

    return [UIColor colorWithHue:mutedHue
                     saturation:mutedSaturation
                     brightness:(low + high) / 2.0
                          alpha:alpha];
}

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

            view.tintColor = ApolloInactiveTabIconColor(view.traitCollection);
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
        icon.tintColor = ApolloInactiveTabIconColor(icon.traitCollection);
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
            [result imageWithTintColor:ApolloInactiveTabIconColor(((UIView *)self).traitCollection)
                         renderingMode:UIImageRenderingModeAlwaysOriginal];

        %orig(coloured);
    }
}

%end
