#import "InfoRowSettingsViewController.h"

#import "ApolloCommon.h"
#import "ApolloState.h"
#import "UserDefaultConstants.h"

@implementation InfoRowSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Info Row";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Translation's marker prerequisites live on another settings screen. A
    // form rebuild refreshes both the disabled switch and the explanatory
    // footer after returning here, without any index-based table updates.
    [self rebuildForm];
}

- (BOOL)translationMarkerAvailable {
    if (!sEnableBulkTranslation) {
        return NO;
    }

    return sTapToTranslate || sShowTranslationTitleDetails || sShowTranslationDetails;
}

- (NSArray<ApolloSettingsSection *> *)buildForm {
    __weak typeof(self) weakSelf = self;

    ApolloSettingsRow *magnifier =
        [ApolloSettingsRow switchRowWithID:@"infoRow.magnifier"
                                     title:@"Magnify Info Row on Hold"
                                      isOn:^BOOL { return sInfoRowMagnifier; }
                                  onToggle:^(UISwitch *sender) {
        sInfoRowMagnifier = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyIconRowMagnifier];
        [self visibilityDidChange];
        ApolloLog(@"[InfoRowSettings] magnifier=%d", sender.isOn);
    }];

    ApolloSettingsRow *upvote =
        [ApolloSettingsRow switchRowWithID:@"infoRow.upvote"
                                     title:@"Upvote on Release"
                                      isOn:^BOOL { return sInfoRowTapUpvote; }
                                  onToggle:^(UISwitch *sender) {
        sInfoRowTapUpvote = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyInfoRowTapUpvote];
        ApolloLog(@"[InfoRowSettings] upvote=%d", sender.isOn);
    }];

    upvote.visible = ^BOOL {
        return [[NSUserDefaults standardUserDefaults] boolForKey:UDKeyIconRowMagnifier];
    };

    ApolloSettingsRow *comments =
        [ApolloSettingsRow switchRowWithID:@"infoRow.comments"
                                     title:@"Jump to Comments"
                                      isOn:^BOOL { return sInfoRowTapComments; }
                                  onToggle:^(UISwitch *sender) {
        sInfoRowTapComments = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyInfoRowTapComments];
        ApolloLog(@"[InfoRowSettings] comments=%d", sender.isOn);
    }];

    ApolloSettingsRow *details =
    [ApolloSettingsRow valueRowWithID:@"infoRow.details"
                                title:@"Full Details on Tap"
                            detail:^NSString * {
    if (sInfoRowPopupMode) return @"Pop-Up";
    if (sInfoRowOverlayMode) return @"Overlay";
    return @"Off";
}
                            onSelect:^{
    [weakSelf presentDetailsPicker];
}];

    ApolloSettingsRow *translation =
        [ApolloSettingsRow switchRowWithID:@"infoRow.translation"
                                     title:@"Globe Toggles Translation"
                                      isOn:^BOOL {
        return sInfoRowTapTranslation;
    }
                                  onToggle:^(UISwitch *sender) {
        sInfoRowTapTranslation = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyInfoRowTapTranslation];
        ApolloLog(@"[InfoRowSettings] translation=%d", sender.isOn);
    }];

    translation.enabled = ^BOOL {
        return [weakSelf translationMarkerAvailable];
    };

    translation.disabledSwitchState = ApolloSettingsDisabledSwitchStateOff;

    return @[
        [ApolloSettingsSection sectionWithTitle:@"Magnifier"
                                         footer:@"Hold, slide and release on an icon to activate it."
                                           rows:@[ magnifier, upvote ]],
        [ApolloSettingsSection sectionWithTitle:@"Icon Tap Actions"
                                        footer: ![self translationMarkerAvailable]
                                        ? @"Reveal more detail when tapping the timestamp and vote percentage icons. Enable Bulk Translation and a Details option to use Globe Toggles Translation."
                                        : @"Reveal more detail when tapping the timestamp and vote percentage icons."
                                        rows:@[ comments, details, translation ]],
    ];
}

- (void)persistInfoModesAndReloadRows {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sInfoRowPopupMode forKey:UDKeyInfoRowPopupMode];
    [defaults setBool:sInfoRowOverlayMode forKey:UDKeyInfoRowOverlayMode];
    [self reloadRowWithID:@"infoRow.details"];
        NSString *mode = @"Off";
        if (sInfoRowPopupMode) {
            mode = @"Pop-Up";
        } else if (sInfoRowOverlayMode) {
            mode = @"Overlay";
        }
    ApolloLog(@"[InfoRowSettings] Full details on Tap: %@", mode);
}

- (void)presentDetailsPicker {
    __weak typeof(self) weakSelf = self;

    NSInteger selectedIndex = 0;
    if (sInfoRowOverlayMode) {
        selectedIndex = 1;
    } else if (sInfoRowPopupMode) {
        selectedIndex = 2;
    }

    ApolloSettingsPresentPicker(self,
                                [self cellForRowID:@"infoRow.details"],
                                @"Full details on Tap",
                                @[@"Off", @"Overlay", @"Pop-Up"],
                                selectedIndex,
                                ^(NSInteger pickedIndex) {
        sInfoRowOverlayMode = (pickedIndex == 1);
        sInfoRowPopupMode = (pickedIndex == 2);
        [weakSelf persistInfoModesAndReloadRows];
    });
}

@end
