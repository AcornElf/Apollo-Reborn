#import "ApolloCommon.h"

// Experiment: tint inactive icons immediately after UIKit updates them.

%hook UITabBarButton

- (void)_updateToMatchCurrentState {
    %orig;
    NSLog(@"[InactiveTabs] Button update");


    UITabBar *bar = nil;
    UIView *ancestor = (UIView *)self;

    while (ancestor) {
        if ([ancestor isKindOfClass:UITabBar.class]) {
            bar = (UITabBar *)ancestor;
            break;
        }
        ancestor = ancestor.superview;
    }

    NSLog(@"[InactiveTabs] State: bar=%@ glass=%d subviews=%lu",
          bar, IsLiquidGlass(), (unsigned long)((UIView *)self).subviews.count);
    if (!bar || IsLiquidGlass()) return;

    NSMutableArray<UIView *> *pending =
        [NSMutableArray arrayWithObject:self];

    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];

        if ([NSStringFromClass(view.class)
                containsString:@"UITabBarSwappableImageView"]) {

            UIView *ancestor = view.superview;

            while (ancestor && ancestor != (UIView *)self) {
                if ([ancestor isKindOfClass:UIVisualEffectView.class]) {
                    ((UIVisualEffectView *)ancestor).effect = nil;
                    NSLog(@"[InactiveTabs] Vibrancy removed: %@", ancestor);
                    break;
                }
                ancestor = ancestor.superview;
            }

            view.tintColor = UIColor.magentaColor;
            static BOOL loggedHierarchy = NO;
            if (!loggedHierarchy) {
                loggedHierarchy = YES;
                UIView *icon = view;

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                              (int64_t)(0.3 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    for (UIView *v = icon; v; v = v.superview) {
                        id effect = [v isKindOfClass:UIVisualEffectView.class]
                            ? ((UIVisualEffectView *)v).effect : nil;

                        NSLog(@"[InactiveTabs] Delayed %@ tint=%@ effect=%@ multiply=%@ filters=%@",
                              NSStringFromClass(v.class),
                              v.tintColor,
                              effect,
                              [v.layer valueForKey:@"contentsMultiplyColor"],
                              v.layer.filters);

                        if ([v isKindOfClass:UITabBar.class]) break;
                    }

                    NSLog(@"[InactiveTabs] Original icon=%p parent=%@ window=%@",
                          icon, icon.superview, icon.window);

                    NSMutableArray<UIView *> *queue =
                        [NSMutableArray arrayWithObject:bar];

                    while (queue.count) {
                        UIView *candidate = queue.lastObject;
                        [queue removeLastObject];

                        if ([NSStringFromClass(candidate.class)
                                containsString:@"UITabBarSwappableImageView"]) {
                            UIImageView *liveImage = (UIImageView *)candidate;
                            if (!IsLiquidGlass() &&
                                !((UIControl *)candidate.superview).selected &&
                                liveImage.image) {
                                liveImage.image = [liveImage.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                                NSLog(@"[InactiveTabs] TEST template icon=%p mode=%ld",
                                      candidate, (long)liveImage.image.renderingMode);
                            }
                            NSLog(@"[InactiveTabs] LIVE IMAGE=%p mode=%ld image=%@ contents=%@ alpha=%.2f hidden=%d window=%@",
                                  candidate,
                                  (long)liveImage.image.renderingMode,
                                  liveImage.image,
                                  candidate.layer.contents,
                                  candidate.alpha,
                                  candidate.hidden,
                                  candidate.window);

                            NSLog(@"[InactiveTabs] LIVE icon=%p parent=%@ tint=%@ multiply=%@",
                                  candidate,
                                  candidate.superview,
                                  candidate.tintColor,
                                  [candidate.layer valueForKey:@"contentsMultiplyColor"]);
                        }

                        [queue addObjectsFromArray:candidate.subviews];
                    }
                });
            }


            NSLog(@"[InactiveTabs] Layer: multiply=%@ matrix=%@",
                  [view.layer valueForKey:@"contentsMultiplyColor"],
                  [view.layer valueForKey:@"vibrantColorMatrix"]);
            static NSMutableSet *seen;
            if (!seen) seen = [NSMutableSet new];
            NSString *key = [NSString stringWithFormat:@"%p", view];
            if (![seen containsObject:key]) {
                [seen addObject:key];
                UIView *parent = view;
                while (parent) {
                    NSLog(@"[InactiveTabs] Hierarchy: %@ effect=%@",
                          NSStringFromClass(parent.class),
                          [parent isKindOfClass:UIVisualEffectView.class]
                              ? ((UIVisualEffectView *)parent).effect : nil);
                    if (parent == (UIView *)self) break;
                    parent = parent.superview;
                }
            }

        }

        [pending addObjectsFromArray:view.subviews];
    }
}

%end


// Experiment: preserve template rendering after tab selection changes.
%hook UITabBarSwappableImageView

- (void)layoutSubviews {
    %orig;

    if (IsLiquidGlass()) return;

    UIView *button = ((UIView *)self).superview;
    if (![button isKindOfClass:NSClassFromString(@"UITabBarButton")]) return;
    if ([(UIControl *)button isSelected]) return;

    UIImageView *icon = (UIImageView *)self;
    if (icon.image &&
        icon.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {

        NSLog(@"[InactiveTabs] Restoring template after transition: %p", self);

        icon.image = [icon.image imageWithRenderingMode:
                      UIImageRenderingModeAlwaysTemplate];
        icon.tintColor = UIColor.magentaColor;

        NSLog(@"[InactiveTabs] Restored tint=%@ mode=%ld multiply=%@",
              icon.tintColor,
              (long)icon.image.renderingMode,
              [icon.layer valueForKey:@"contentsMultiplyColor"]);
    }
}

%end

// Diagnostic: identify who restores original-rendering tab images.
%hook UITabBarSwappableImageView

- (void)setImage:(UIImage *)image {
    if (IsLiquidGlass()) {
        %orig;
        return;
    }

    NSLog(@"[InactiveTabs] setImage ENTER view=%p image=%p mode=%ld caller=%@",
          self,
          image,
          (long)image.renderingMode,
          NSThread.callStackSymbols.count > 2
              ? NSThread.callStackSymbols[2] : @"unknown");

    %orig;

    UIImage *result = [(UIImageView *)self image];

    // Diagnostic: bypass template tinting with pre-coloured image pixels.
    if (result &&
        [((UIView *)self).superview isKindOfClass:UIControl.class] &&
        !((UIControl *)((UIView *)self).superview).selected) {
        UIImage *coloured =
            [result imageWithTintColor:UIColor.magentaColor
                         renderingMode:UIImageRenderingModeAlwaysOriginal];

        %orig(coloured);
        result = [(UIImageView *)self image];

        NSLog(@"[InactiveTabs] BITMAP TEST view=%p mode=%ld",
              self, (long)result.renderingMode);
    }

    NSLog(@"[InactiveTabs] setImage EXIT view=%p image=%p mode=%ld tint=%@",
          self,
          result,
          (long)result.renderingMode,
          ((UIView *)self).tintColor);
}

%end
