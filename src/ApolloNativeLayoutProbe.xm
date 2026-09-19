#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const NSInteger kNativeProbeOutlineTag = 0xA991;
static const NSInteger kNativeProbeHUDTag = 0xA992;

static UIColor *NativeProbeOutlineColor(void) {
    return [UIColor colorWithRed:1.0
                           green:0.15
                            blue:0.15
                           alpha:1.0];
}

static UIColor *NativeProbePanelColor(void) {
    return [UIColor colorWithWhite:0.05 alpha:0.94];
}

static NSString *NativeProbeClassName(id object) {
    if (!object) {
        return @"(nil)";
    }

    return NSStringFromClass([object class]);
}

static NSString *NativeProbeShortText(NSString *text) {
    if (!text.length) {
        return nil;
    }

    NSString *oneLine =
        [[text componentsSeparatedByCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]]
            componentsJoinedByString:@" "];

    if (oneLine.length <= 70) {
        return oneLine;
    }

    return [[oneLine substringToIndex:69]
        stringByAppendingString:@"…"];
}

static NSString *NativeProbeFontWeight(UIFont *font) {
    if (!font) {
        return @"none";
    }

    NSNumber *weight = font.fontDescriptor.fontAttributes[UIFontWeightTrait];
    if (!weight) {
        return @"unknown";
    }

    return [NSString stringWithFormat:@"%.2f", weight.doubleValue];
}

static CGFloat NativeProbeTracking(NSAttributedString *string) {
    if (!string.length) {
        return 0.0;
    }

    __block CGFloat result = 0.0;

    [string enumerateAttribute:NSKernAttributeName
                       inRange:NSMakeRange(0, string.length)
                       options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value) {
            result = [value doubleValue];
            *stop = YES;
        }
    }];

    return result;
}

static NSString *NativeProbeParagraphInfo(NSAttributedString *string) {
    if (!string.length) {
        return @"default";
    }

    __block NSParagraphStyle *paragraph = nil;

    [string enumerateAttribute:NSParagraphStyleAttributeName
                       inRange:NSMakeRange(0, string.length)
                       options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value) {
            paragraph = value;
            *stop = YES;
        }
    }];

    if (!paragraph) {
        return @"default";
    }

    return [NSString stringWithFormat:
        @"min %.1f max %.1f spacing %.1f",
        paragraph.minimumLineHeight,
        paragraph.maximumLineHeight,
        paragraph.lineSpacing];
}

static NSString *NativeProbeTextForView(UIView *view,
                                         UIFont **fontOut,
                                         CGFloat *trackingOut,
                                         NSString **paragraphOut) {
    NSString *text = nil;
    UIFont *font = nil;
    CGFloat tracking = 0.0;
    NSString *paragraph = @"default";

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;

        text = label.text;
        font = label.font;

        if (label.attributedText.length) {
            tracking = NativeProbeTracking(label.attributedText);
            paragraph =
                NativeProbeParagraphInfo(label.attributedText);
        }
    }
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;

        text = button.currentTitle;
        font = button.titleLabel.font;

        if (button.currentAttributedTitle.length) {
            tracking =
                NativeProbeTracking(button.currentAttributedTitle);

            paragraph =
                NativeProbeParagraphInfo(
                    button.currentAttributedTitle
                );
        }
    }

    if (fontOut) {
        *fontOut = font;
    }

    if (trackingOut) {
        *trackingOut = tracking;
    }

    if (paragraphOut) {
        *paragraphOut = paragraph;
    }

    return text;
}

static void NativeProbeCollectTextViews(
    UIView *view,
    NSMutableArray<NSDictionary *> *results,
    UIView *cell
) {
    if (!view) {
        return;
    }

    UIFont *font = nil;
    CGFloat tracking = 0.0;
    NSString *paragraph = nil;

    NSString *text =
        NativeProbeTextForView(
            view,
            &font,
            &tracking,
            &paragraph
        );

    if (text.length && font) {
        CGRect frame =
            [view convertRect:view.bounds toView:cell];

        [results addObject:@{
            @"view": view,
            @"class": NativeProbeClassName(view),
            @"text": NativeProbeShortText(text),
            @"font": font,
            @"weight": NativeProbeFontWeight(font),
            @"tracking": @(tracking),
            @"paragraph": paragraph ?: @"default",
            @"frame": [NSValue valueWithCGRect:frame]
        }];

        /*
         * UILabels and UIButtons can contain their own text-bearing
         * subviews. Once we've captured the control itself, don't
         * recurse into it.
         */
        return;
    }

    for (UIView *subview in view.subviews) {
        NativeProbeCollectTextViews(
            subview,
            results,
            cell
        );
    }
}

static BOOL NativeProbeLooksLikePostCell(
    UITableViewCell *cell,
    NSArray<NSDictionary *> *textViews
) {
    return [NSStringFromClass(cell.class)
        isEqualToString:@"_ASTableViewCell"];
}

static UITableViewCell *NativeProbeFindPostCell(
    UITableView *tableView
) {
    for (UITableViewCell *cell in tableView.visibleCells) {
        NSMutableArray *textViews =
            [NSMutableArray array];

        NativeProbeCollectTextViews(
            cell.contentView,
            textViews,
            cell
        );

        if (NativeProbeLooksLikePostCell(
                cell,
                textViews
            )) {
            return cell;
        }
    }

    return nil;
}

static void NativeProbeOutlineCell(
    UITableViewCell *cell
) {
    UIView *outline =
        [cell.contentView viewWithTag:
            kNativeProbeOutlineTag];

    if (!outline) {
        outline =
            [[UIView alloc]
                initWithFrame:cell.contentView.bounds];

        outline.tag =
            kNativeProbeOutlineTag;

        outline.userInteractionEnabled = NO;
        outline.backgroundColor =
            UIColor.clearColor;

        outline.layer.borderWidth = 2.0;
        outline.layer.borderColor =
            NativeProbeOutlineColor().CGColor;

        [cell.contentView addSubview:outline];
    }

    outline.frame =
        cell.contentView.bounds;

    [cell.contentView
        bringSubviewToFront:outline];
}

static UILabel *NativeProbeHUD(
    UIWindow *window
) {
    UILabel *hud =
        [window viewWithTag:kNativeProbeHUDTag];

    if (!hud) {
        hud =
            [[UILabel alloc]
                initWithFrame:CGRectZero];

        hud.tag = kNativeProbeHUDTag;

        hud.numberOfLines = 0;

        hud.font =
            [UIFont monospacedSystemFontOfSize:9.0
                                        weight:UIFontWeightRegular];

        hud.textColor =
            UIColor.whiteColor;

        hud.backgroundColor =
            NativeProbePanelColor();

        hud.layer.cornerRadius = 8.0;
        hud.layer.masksToBounds = YES;

        hud.userInteractionEnabled = NO;

        [window addSubview:hud];
    }

    return hud;
}

static void NativeProbeUpdateHUD(
    UITableViewCell *cell,
    NSArray<NSDictionary *> *textViews
) {
    UIWindow *window = cell.window;

    if (!window) {
        return;
    }

    NSMutableString *report =
        [NSMutableString string];

    [report appendFormat:
        @"Native cell: %@\n",
        NativeProbeClassName(cell)];

    [report appendFormat:
        @"Text size: %@\n\n",
        UIApplication.sharedApplication
            .preferredContentSizeCategory];

    NSArray *sorted =
        [textViews sortedArrayUsingComparator:
            ^NSComparisonResult(
                NSDictionary *a,
                NSDictionary *b
            ) {
                CGRect aFrame =
                    [a[@"frame"] CGRectValue];

                CGRect bFrame =
                    [b[@"frame"] CGRectValue];

                if (aFrame.origin.y <
                    bFrame.origin.y) {
                    return NSOrderedAscending;
                }

                if (aFrame.origin.y >
                    bFrame.origin.y) {
                    return NSOrderedDescending;
                }

                return NSOrderedSame;
            }];

    CGFloat previousBottom = 0.0;
    BOOL havePrevious = NO;

    for (NSDictionary *entry in sorted) {
        CGRect frame =
            [entry[@"frame"] CGRectValue];

        UIFont *font =
            entry[@"font"];

        if (havePrevious) {
            CGFloat gap =
                frame.origin.y -
                previousBottom;

            [report appendFormat:
                @"GAP %.1f\n",
                gap];
        }

        [report appendFormat:
            @"%@\n"
             @"  %@\n"
             @"  %.1fpt %@\n"
             @"  line %.1f asc %.1f desc %.1f\n"
             @"  kern %.2f  %@\n"
             @"  frame %.1f, %.1f, %.1f, %.1f\n\n",
            entry[@"class"],
            entry[@"text"] ?: @"",
            font.pointSize,
            entry[@"weight"],
            font.lineHeight,
            font.ascender,
            font.descender,
            [entry[@"tracking"] doubleValue],
            entry[@"paragraph"],
            frame.origin.x,
            frame.origin.y,
            frame.size.width,
            frame.size.height];

        previousBottom =
            CGRectGetMaxY(frame);

        havePrevious = YES;
    }

    UILabel *hud =
        NativeProbeHUD(window);

    hud.text = report;

    UIEdgeInsets safeInsets =
        window.safeAreaInsets;

    CGFloat width =
        MIN(
            CGRectGetWidth(window.bounds) - 20.0,
            360.0
        );

    CGSize size =
        [hud sizeThatFits:
            CGSizeMake(
                width - 16.0,
                CGFLOAT_MAX
            )];

    hud.frame =
        CGRectMake(
            10.0,
            safeInsets.top + 10.0,
            width,
            MIN(size.height + 16.0, 360.0)
        );
}

static void NativeProbeInspectTableView(
    UITableView *tableView
) {
    if (!tableView.window) {
        return;
    }

    UITableViewCell *cell =
        NativeProbeFindPostCell(tableView);

    if (!cell) {
        return;
    }

    // Remove outlines from previously inspected visible cells.
    for (UITableViewCell *visibleCell in tableView.visibleCells) {
        UIView *oldOutline =
            [visibleCell.contentView viewWithTag:
                kNativeProbeOutlineTag];

        [oldOutline removeFromSuperview];
    }

    NSMutableArray *textViews =
        [NSMutableArray array];

    NativeProbeCollectTextViews(
        cell.contentView,
        textViews,
        cell
    );

    NativeProbeOutlineCell(cell);

    NativeProbeUpdateHUD(
        cell,
        textViews
    );
}

%hook UITableView

- (void)layoutSubviews {
    %orig;

    static CFTimeInterval lastRun = 0.0;

    CFTimeInterval now =
        CACurrentMediaTime();

    if (now - lastRun < 0.25) {
        return;
    }

    lastRun = now;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            NativeProbeInspectTableView(self);
        }
    );
}

%end