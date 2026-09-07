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
    return sTapToTranslate || sShowTranslationTitleDetails || sShowTranslationDetails;
}

- (NSArray<ApolloSettingsSection *> *)buildForm {
    __weak typeof(self) weakSelf = self;

    ApolloSettingsRow *magnifier =
        [ApolloSettingsRow switchRowWithID:@"infoRow.magnifier"
                                     title:@"Magnify Info Row on Hold"
                                      isOn:^BOOL { return sIconRowMagnifier; }
                                  onToggle:^(UISwitch *sender) {
        sIconRowMagnifier = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyIconRowMagnifier];
        [weakSelf reloadRowWithID:@"infoRow.upvote"];
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
        return sIconRowMagnifier;
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

    ApolloSettingsRow *timestamp =
    [ApolloSettingsRow valueRowWithID:@"infoRow.timestamp"
                                title:@"Full Timestamp on Tap"
                            detail:^NSString * {
    if (sInfoRowPopupMode) return @"Pop-up";
    if (sInfoRowOverlayMode) return @"Overlay";
    return @"Off";
}
                            onSelect:^{
    [weakSelf presentTimestampPicker];
}];

    ApolloSettingsRow *translation =
        [ApolloSettingsRow switchRowWithID:@"infoRow.translation"
                                     title:@"Globe Toggles Translation"
                                      isOn:^BOOL {
        return [weakSelf translationMarkerAvailable] && sInfoRowTapTranslation;
    }
                                  onToggle:^(UISwitch *sender) {
        sInfoRowTapTranslation = sender.isOn;
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:UDKeyInfoRowTapTranslation];
        ApolloLog(@"[InfoRowSettings] translation=%d", sender.isOn);
    }];
    translation.enabled = ^BOOL { return [weakSelf translationMarkerAvailable]; };
    translation.visible = ^BOOL {
        return sShowTranslationTitleDetails && sEnableBulkTranslation && !sTapToTranslate;
    };

    return @[
        [ApolloSettingsSection sectionWithTitle:@"Magnifier"
                                         footer:@"Slide and release on an icon to activate it."
                                           rows:@[ magnifier ]],
        [ApolloSettingsSection sectionWithTitle:@"Icon Tap Actions"
                                        footer: nil
                                        rows:@[ upvote, comments, timestamp, translation ]],
    ];
}

- (void)persistInfoModesAndReloadRows {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sInfoRowPopupMode forKey:UDKeyInfoRowPopupMode];
    [defaults setBool:sInfoRowOverlayMode forKey:UDKeyInfoRowOverlayMode];
    [self reloadRowWithID:@"infoRow.timestamp"];
        NSString *mode = @"Off";
        if (sInfoRowPopupMode) {
            mode = @"Pop-up";
        } else if (sInfoRowOverlayMode) {
            mode = @"Overlay";
        }
    ApolloLog(@"[InfoRowSettings] Full Timestamp on Tap: %@", mode);
}

- (void)presentTimestampPicker {
    __weak typeof(self) weakSelf = self;

    NSInteger selectedIndex = 0;
    if (sInfoRowOverlayMode) {
        selectedIndex = 1;
    } else if (sInfoRowPopupMode) {
        selectedIndex = 2;
    }

    ApolloSettingsPresentPicker(self,
                                [self cellForRowID:@"infoRow.timestamp"],
                                @"Full Timestamp on Tap",
                                @[@"Off", @"Overlay", @"Pop-up"],
                                selectedIndex,
                                ^(NSInteger pickedIndex) {
        sInfoRowOverlayMode = (pickedIndex == 1);
        sInfoRowPopupMode = (pickedIndex == 2);
        [weakSelf persistInfoModesAndReloadRows];
    });
}

@end
