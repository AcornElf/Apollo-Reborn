#import "settings/ApolloSettingsTableViewController.h"

#import "ApolloCommon.h"
#import "ApolloThemeRuntime.h"
#import "ApolloSettingsTextFieldTags.h"
#import <objc/runtime.h>

static char kApolloAccentActionCellKey;
static char kApolloPrimaryTextCellKey;

@implementation ApolloSettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self apollo_applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self apollo_applyTheme];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self apollo_applyTheme];
}

- (UITableView *)apollo_sourceThemeTableView {
    return ApolloInheritedSettingsThemeSourceTableView(self);
}

// Detail-carrying switch cell (subtitle style). Title-only switches use the
// form layer's switch rows; these stay custom because the shared switch cell
// has no subtitle line.
- (UITableViewCell *)switchCellWithIdentifier:(NSString *)identifier
                                        label:(NSString *)label
                                       detail:(NSString *)detail
                                           on:(BOOL)on
                                       action:(SEL)action {
    return [self switchCellWithIdentifier:identifier label:label detail:detail on:on enabled:YES action:action];
}

// A title + optional multi-line subtitle + trailing switch. Hand-laid with Auto
// Layout (not UITableViewCellStyleSubtitle nor a content-configuration + switch
// accessory): both of those measure the labels at the full cell width — the
// switch accessory isn't reserved during self-sizing — so a wrapping subtitle
// under-measures and its last line clips against the cell's bottom edge. Here
// the switch is constrained inline, so the labels wrap at the true available
// width and the cell height is exact.
- (UITableViewCell *)switchCellWithIdentifier:(NSString *)identifier
                                        label:(NSString *)label
                                       detail:(NSString *)detail
                                           on:(BOOL)on
                                      enabled:(BOOL)enabled
                                       action:(SEL)action {
    static const NSInteger kTitleTag = 7001, kDetailTag = 7002, kSwitchTag = 7003;
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    UILabel *titleLabel; UILabel *detailLabel; UISwitch *toggleSwitch;
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        titleLabel = [[UILabel alloc] init];
        titleLabel.tag = kTitleTag;
        titleLabel.numberOfLines = 0;
        titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        titleLabel.adjustsFontForContentSizeCategory = YES;

        detailLabel = [[UILabel alloc] init];
        detailLabel.tag = kDetailTag;
        detailLabel.numberOfLines = 0;
        detailLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        detailLabel.adjustsFontForContentSizeCategory = YES;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ titleLabel, detailLabel ]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 3.0;
        stack.translatesAutoresizingMaskIntoConstraints = NO;

        toggleSwitch = [[UISwitch alloc] init];
        toggleSwitch.tag = kSwitchTag;
        [toggleSwitch addTarget:self action:action forControlEvents:UIControlEventValueChanged];
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [toggleSwitch setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [toggleSwitch setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        [cell.contentView addSubview:stack];
        [cell.contentView addSubview:toggleSwitch];
        UILayoutGuide *m = cell.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:m.leadingAnchor],
            [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:11.0],
            [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-11.0],
            [toggleSwitch.leadingAnchor constraintEqualToAnchor:stack.trailingAnchor constant:12.0],
            [toggleSwitch.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
            [toggleSwitch.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        ]];
    } else {
        titleLabel = [cell.contentView viewWithTag:kTitleTag];
        detailLabel = [cell.contentView viewWithTag:kDetailTag];
        toggleSwitch = (UISwitch *)[cell.contentView viewWithTag:kSwitchTag];
    }

    titleLabel.text = label;
    titleLabel.textColor = enabled ? [UIColor labelColor] : [UIColor tertiaryLabelColor];
    detailLabel.text = detail;
    detailLabel.textColor = enabled ? [UIColor secondaryLabelColor] : [UIColor tertiaryLabelColor];
    detailLabel.hidden = (detail.length == 0);
    toggleSwitch.on = on;
    toggleSwitch.enabled = enabled;
    toggleSwitch.onTintColor = [self apollo_themeAccentColor];
    return cell;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIColor *)apollo_themeCellBackgroundColor {
    UITableView *source = [self apollo_sourceThemeTableView];
    if (!ApolloThemeSourceTableIsStale(source)) {
        for (UITableViewCell *cell in source.visibleCells) {
            UIColor *color = cell.backgroundColor ?: cell.contentView.backgroundColor;
            if (color) return color;
        }
    }
    return ApolloThemeCardBackgroundColor() ?: [UIColor secondarySystemGroupedBackgroundColor];
}

- (UIColor *)apollo_themeAccentColor {
    return ApolloThemeAccentColor() ?: self.view.tintColor ?: [UIColor systemBlueColor];
}

- (void)apollo_applyPrimaryTextColorToCell:(UITableViewCell *)cell {
    if (!cell) return;
    objc_setAssociatedObject(cell, &kApolloPrimaryTextCellKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)apollo_applyAccentActionTextColorToCell:(UITableViewCell *)cell {
    if (!cell) return;
    objc_setAssociatedObject(cell, &kApolloAccentActionCellKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)apollo_applyThemeToCell:(UITableViewCell *)cell {
    if (!cell) return;

    UIColor *cellColor = [self apollo_themeCellBackgroundColor];
    cell.backgroundColor = cellColor;

    UIColor *accentColor = [self apollo_themeAccentColor];
    cell.tintColor = accentColor;
    if (cell.accessoryView) cell.accessoryView.tintColor = accentColor;

    for (UIView *subview in cell.contentView.subviews) {
        subview.tintColor = accentColor;
    }

    if ([objc_getAssociatedObject(cell, &kApolloAccentActionCellKey) boolValue]) {
        cell.textLabel.textColor = accentColor;
    } else if (cell.textLabel.enabled &&
               [objc_getAssociatedObject(cell, &kApolloPrimaryTextCellKey) boolValue]) {
        UIColor *primary = ApolloThemeRuntimeColor(ApolloThemeTokenLabel);
        if (primary) cell.textLabel.textColor = primary;
    }
}

- (void)apollo_applyTheme {
    ApolloApplyInheritedSettingsTableTheme(self);

    UIColor *accentColor = [self apollo_themeAccentColor];
    self.view.tintColor = accentColor;
    self.tableView.tintColor = accentColor;
    self.navigationController.navigationBar.tintColor = accentColor;

    for (UITableViewCell *cell in self.tableView.visibleCells) {
        [self apollo_applyThemeToCell:cell];
    }
}

- (void)tableView:(UITableView *)__unused tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)__unused indexPath {
    [self apollo_applyThemeToCell:cell];
}

- (UITableViewCell *)stackedTextFieldCellWithIdentifier:(NSString *)identifier
                                                  label:(NSString *)label
                                            placeholder:(NSString *)placeholder
                                                   text:(NSString *)text
                                                    tag:(NSInteger)tag {
    return [self stackedTextFieldCellWithIdentifier:identifier label:label placeholder:placeholder text:text tag:tag detail:nil];
}

- (UITableViewCell *)stackedTextFieldCellWithIdentifier:(NSString *)identifier
                                                  label:(NSString *)label
                                            placeholder:(NSString *)placeholder
                                                   text:(NSString *)text
                                                    tag:(NSInteger)tag
                                                 detail:(NSString *)detail {
    static const NSInteger kLabelTag = 9000;
    static const NSInteger kDetailTag = 9002;

    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.hidden = YES;

        UILabel *captionLabel = [[UILabel alloc] init];
        captionLabel.tag = kLabelTag;
        captionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        captionLabel.adjustsFontForContentSizeCategory = YES;
        captionLabel.translatesAutoresizingMaskIntoConstraints = NO;

        UITextField *textField = [[UITextField alloc] init];
        textField.tag = tag;
        textField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCallout];
        textField.adjustsFontForContentSizeCategory = YES;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.returnKeyType = UIReturnKeyDone;
        textField.translatesAutoresizingMaskIntoConstraints = NO;

        [cell.contentView addSubview:captionLabel];
        [cell.contentView addSubview:textField];

        UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [captionLabel.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [captionLabel.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [captionLabel.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],

            [textField.topAnchor constraintEqualToAnchor:captionLabel.bottomAnchor constant:4],
            [textField.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [textField.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        ]];

        if (detail) {
            UILabel *detailLabel = [[UILabel alloc] init];
            detailLabel.tag = kDetailTag;
            detailLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
            detailLabel.adjustsFontForContentSizeCategory = YES;
            detailLabel.textColor = [UIColor secondaryLabelColor];
            detailLabel.numberOfLines = 0;
            detailLabel.translatesAutoresizingMaskIntoConstraints = NO;

            [cell.contentView addSubview:detailLabel];
            [NSLayoutConstraint activateConstraints:@[
                [detailLabel.topAnchor constraintEqualToAnchor:textField.bottomAnchor constant:4],
                [detailLabel.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
                [detailLabel.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
                [detailLabel.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
            ]];
        } else {
            [textField.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor].active = YES;
        }
    }

    UILabel *captionLabel = [cell.contentView viewWithTag:kLabelTag];
    captionLabel.text = label;

    UILabel *detailLabel = [cell.contentView viewWithTag:kDetailTag];
    if (detailLabel) {
        detailLabel.text = detail;
    }

    UITextField *textField = nil;
    for (UIView *subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            textField = (UITextField *)subview;
            break;
        }
    }
    textField.text = text;
    textField.placeholder = placeholder;
    textField.accessibilityLabel = label;   // VoiceOver: tie the field to its caption
    if (tag == TagImageChestAPIToken) {
        textField.textAlignment = NSTextAlignmentLeft;
        textField.adjustsFontSizeToFitWidth = NO;
    } else {
        textField.adjustsFontSizeToFitWidth = YES;
        textField.minimumFontSize = 12;
    }

    return cell;
}
@end


// UITextView subclass that allows users to tap links within footer text, but not select text
@implementation ApolloFooterLinkTextView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UITextPosition *position = [self closestPositionToPoint:point];
    if (!position) return NO;

    UITextRange *range = [self.tokenizer rangeEnclosingPosition:position withGranularity:UITextGranularityCharacter inDirection:UITextLayoutDirectionLeft];
    if (!range) return NO;

    NSInteger startIndex = [self offsetFromPosition:self.beginningOfDocument toPosition:range.start];
    return [self.attributedText attribute:NSLinkAttributeName atIndex:startIndex effectiveRange:nil] != nil;
}


@end
