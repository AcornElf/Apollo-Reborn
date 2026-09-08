#import "ApolloNotificationBackendViewController.h"
#import "ApolloNotificationBackend.h"
#import "ApolloSettingsTextFieldTags.h"
#import "ApolloBarkNotifications.h"
#import "ApolloPushNotifications.h"
#import "ApolloState.h"
#import "UserDefaultConstants.h"
#import <SafariServices/SafariServices.h>

@implementation ApolloNotificationBackendViewController

- (NSString *)apollo_screenTitle {
    return @"Notification Backend";
}

- (BOOL)isNotificationBackendURLValid:(NSString *)urlString {
    if (urlString.length == 0) return YES; // empty = disabled, treated as valid
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    return url.host.length > 0;
}

- (ApolloSettingsSection *)buildNotificationBackendSection {
    __weak typeof(self) weakSelf = self;

    ApolloSettingsRow *backendURL =
        [ApolloSettingsRow customRowWithID:@"notif.url"
                                      cell:^UITableViewCell *(__unused UITableView *tableView, __unused ApolloSettingsRow *row) {
            NSString *currentURL = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendURL] ?: @"";
            UITableViewCell *cell = [weakSelf stackedTextFieldCellWithIdentifier:@"Cell_NotifBackend_URL"
                                                                           label:@"Self-Hosted Backend URL"
                                                                     placeholder:@"https://apollo.example.com"
                                                                            text:currentURL
                                                                             tag:TagNotificationBackendURL];
            for (UIView *subview in cell.contentView.subviews) {
                if ([subview isKindOfClass:[UITextField class]]) {
                    UITextField *tf = (UITextField *)subview;
                    tf.delegate = weakSelf;
                    tf.keyboardType = UIKeyboardTypeURL;
                    tf.textColor = [weakSelf isNotificationBackendURLValid:currentURL] ? [UIColor labelColor] : [UIColor systemRedColor];
                    break;
                }
            }
            return cell ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        }
                                  onSelect:nil];

    // Setup Instructions
    ApolloSettingsRow *setupInstructions =
            [ApolloSettingsRow customRowWithID:@"notif.setup"
                                        cell:^UITableViewCell *(UITableView *tableView, __unused ApolloSettingsRow *row) {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell_NotifBackend_Setup"];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell_NotifBackend_Setup"];
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                }
                cell.textLabel.text = @"Backend Setup Instructions";
                [weakSelf apollo_applyAccentActionTextColorToCell:cell];
                return cell;
            }
                                    onSelect:^{
                                        NSURL *url = [NSURL URLWithString:@"https://github.com/nickclyde/apollo-backend"];
                                        SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:url];
                                        [weakSelf presentViewController:safariVC animated:YES completion:nil];
}];

    ApolloSettingsRow *installBark = nil;
    if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"bark://"]]) {
        installBark =
            [ApolloSettingsRow customRowWithID:@"notif.install-bark"
                                        cell:^UITableViewCell *(UITableView *tableView, __unused ApolloSettingsRow *row) {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell_NotifBackend_InstallBark"];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell_NotifBackend_InstallBark"];
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                }
                cell.textLabel.text = @"Install Bark";
                [weakSelf apollo_applyAccentActionTextColorToCell:cell];
                return cell;
            }
                                    onSelect:^{
                                        NSURL *url = [NSURL URLWithString:@"https://apps.apple.com/us/app/bark-custom-notifications/id1403753865"];
                                        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                                    }];
    }

    ApolloSettingsRow *testConnection =
            [ApolloSettingsRow customRowWithID:@"notif.test"
                                        cell:^UITableViewCell *(UITableView *tableView, __unused ApolloSettingsRow *row) {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell_NotifBackend_Test"];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell_NotifBackend_Test"];
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                }
                cell.textLabel.text = @"Test Backend Connection";
                [weakSelf apollo_applyAccentActionTextColorToCell:cell];
                return cell;
            }
                                    onSelect:^{ [weakSelf testNotificationBackendConnection]; }];
    testConnection.visible = ^BOOL {
        NSString *url = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendURL];
        return url.length > 0 &&
           [self isNotificationBackendURLValid:url];
};
              
    ApolloSettingsRow *registrationToken =
        [ApolloSettingsRow customRowWithID:@"notif.token"
                                      cell:^UITableViewCell *(__unused UITableView *tableView, __unused ApolloSettingsRow *row) {
            NSString *currentToken = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendRegistrationToken] ?: @"";
            UITableViewCell *cell = [weakSelf stackedTextFieldCellWithIdentifier:@"Cell_NotifBackend_Token"
                                                               label:@"Registration Token"
                                                         placeholder:@"(optional)"
                                                                text:currentToken
                                                                 tag:TagNotificationBackendRegistrationToken
                                                              detail:@"Required only if the backend has REGISTRATION_SECRET set."];

            for (UIView *subview in cell.contentView.subviews) {
                if ([subview isKindOfClass:[UITextField class]]) {
                    ((UITextField *)subview).delegate = weakSelf;
                    break;
                }
            }

            return cell ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        }
                                  onSelect:nil];

    // The Bark rows are always visible: on builds without a push entitlement
    // Bark is the only delivery path, and on entitled builds it's an optional
    // alternative transport (the backend flips the device row between apns and
    // bark on re-registration).
    ApolloSettingsRow *barkSwitch =
        [ApolloSettingsRow customRowWithID:@"notif.barkSwitch"
                                      cell:^UITableViewCell *(__unused UITableView *tableView, __unused ApolloSettingsRow *row) {
            return [weakSelf switchCellWithIdentifier:@"Cell_NotifBackend_BarkSwitch"
                                                label:@"Bark Delivery"
                                               detail:@"Deliver notifications through the free Bark app instead of native push. Works without a push entitlement."
                                                   on:[[NSUserDefaults standardUserDefaults] boolForKey:UDKeyBarkNotificationsEnabled]
                                               action:@selector(barkNotificationsSwitchToggled:)]
                ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        }
                                  onSelect:nil];

    barkSwitch.visible = ^BOOL {
        NSString *url = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendURL];
        return url.length > 0;
};

    ApolloSettingsRow *barkURL =
        [ApolloSettingsRow customRowWithID:@"notif.barkURL"
                                      cell:^UITableViewCell *(__unused UITableView *tableView, __unused ApolloSettingsRow *row) {
            NSString *currentURL = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyBarkPushURL] ?: @"";
            UITableViewCell *cell = [weakSelf stackedTextFieldCellWithIdentifier:@"Cell_NotifBackend_BarkURL"
                                                                           label:@"Bark Push URL"
                                                                     placeholder:@"https://api.day.app/yourdevicekey"
                                                                            text:currentURL
                                                                             tag:TagBarkPushURL
                                                                          detail:@"In Bark, open the Service tab, tap the cloud icon in the top right, select your server and choose Copy Address and Key. Paste the copied value here. Keep your key private."];
            for (UIView *subview in cell.contentView.subviews) {
                if ([subview isKindOfClass:[UITextField class]]) {
                    UITextField *tf = (UITextField *)subview;
                    tf.delegate = weakSelf;
                    tf.keyboardType = UIKeyboardTypeURL;
                    tf.textColor = [weakSelf isNotificationBackendURLValid:currentURL] ? [UIColor labelColor] : [UIColor systemRedColor];
                    break;
                }
            }
            return cell ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        }
                                  onSelect:nil];
    barkURL.visible = ^BOOL {
    NSString *backendURL = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendURL];
    return backendURL.length > 0 &&
           [[NSUserDefaults standardUserDefaults] boolForKey:UDKeyBarkNotificationsEnabled];
};

    ApolloSettingsRow *testBark =
        [ApolloSettingsRow customRowWithID:@"notif.testBark"
                                      cell:^UITableViewCell *(UITableView *tableView, __unused ApolloSettingsRow *row) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell_NotifBackend_TestBark"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell_NotifBackend_TestBark"];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
            cell.textLabel.text = @"Test Bark Notification";
            [weakSelf apollo_applyAccentActionTextColorToCell:cell];
            return cell;
        }
                                  onSelect:^{ [weakSelf testBarkNotification]; }];
    testBark.visible = ^BOOL {
    NSString *backendURL = [[NSUserDefaults standardUserDefaults] stringForKey:UDKeyNotificationBackendURL];
    return backendURL.length > 0 &&
           [self isNotificationBackendURLValid:backendURL] &&
           [[NSUserDefaults standardUserDefaults] boolForKey:UDKeyBarkNotificationsEnabled];
};

    // Custom rather than a button row: the label is centered, which the shared
    // button-row cell doesn't do.

    return [ApolloSettingsSection sectionWithTitle:nil
                                            footer:nil
                                              rows:@[ backendURL, registrationToken, barkSwitch, barkURL,
                                                    testBark, testConnection, setupInstructions, installBark ]];
}

- (void)testNotificationBackendConnection {
    if (!ApolloIsNotificationBackendConfigured()) {
        [self showAlertWithTitle:@"Backend URL Required" message:@"Enter a self-hosted apollo-backend URL above before testing."];
        return;
    }

    UIAlertController *spinner = [UIAlertController alertControllerWithTitle:@"Testing connection…"
                                                                     message:@"\n"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [indicator startAnimating];
    [spinner.view addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
        [indicator.centerXAnchor constraintEqualToAnchor:spinner.view.centerXAnchor],
        [indicator.bottomAnchor constraintEqualToAnchor:spinner.view.bottomAnchor constant:-20],
    ]];

    [self presentViewController:spinner animated:YES completion:^{
        ApolloTestNotificationBackendConnection(^(BOOL ok, NSString *message) {
            [spinner dismissViewControllerAnimated:YES completion:^{
                [self showAlertWithTitle:ok ? @"Success" : @"Failed" message:message];
            }];
        });
    }];
}

- (void)testBarkNotification {
    if (!ApolloBarkConfigured()) {
        NSString *why = [[NSUserDefaults standardUserDefaults] boolForKey:UDKeyBarkNotificationsEnabled]
            ? @"Enter a valid Bark push URL (from the Bark app's server list) before testing."
            : @"Turn on Bark Delivery and enter your Bark push URL before testing.";
        [self showAlertWithTitle:@"Bark Not Configured" message:why];
        return;
    }

    UIAlertController *spinner = [UIAlertController alertControllerWithTitle:@"Sending test notification…"
                                                                     message:@"\n"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [indicator startAnimating];
    [spinner.view addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
        [indicator.centerXAnchor constraintEqualToAnchor:spinner.view.centerXAnchor],
        [indicator.bottomAnchor constraintEqualToAnchor:spinner.view.bottomAnchor constant:-20],
    ]];

    [self presentViewController:spinner animated:YES completion:^{
        ApolloBarkSendTestNotification(^(BOOL ok, NSString *message) {
            [spinner dismissViewControllerAnimated:YES completion:^{
                NSString *finalMessage = message;
                if (ok && !ApolloIsNotificationBackendConfigured()) {
                    finalMessage = [message stringByAppendingString:
                        @"\n\nNote: Bark delivery also needs a Backend URL above — without one there is no server watching your Reddit account."];
                }
                [self showAlertWithTitle:ok ? @"Success" : @"Failed" message:finalMessage];
            }];
        });
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag == TagNotificationBackendURL) {
        NSString *trimmed = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        while ([trimmed hasSuffix:@"/"]) {
            trimmed = [trimmed substringToIndex:trimmed.length - 1];
        }
        textField.text = trimmed;
        [[NSUserDefaults standardUserDefaults] setValue:trimmed forKey:UDKeyNotificationBackendURL];
        textField.textColor = [self isNotificationBackendURLValid:trimmed] ? [UIColor labelColor] : [UIColor systemRedColor];
    } else if (textField.tag == TagNotificationBackendRegistrationToken) {
        NSString *trimmed = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        textField.text = trimmed;
        [[NSUserDefaults standardUserDefaults] setValue:trimmed forKey:UDKeyNotificationBackendRegistrationToken];
    } else if (textField.tag == TagBarkPushURL) {
        NSString *trimmed = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        while ([trimmed hasSuffix:@"/"]) {
            trimmed = [trimmed substringToIndex:trimmed.length - 1];
        }
        textField.text = trimmed;
        [[NSUserDefaults standardUserDefaults] setValue:trimmed forKey:UDKeyBarkPushURL];
        textField.textColor = [self isNotificationBackendURLValid:trimmed] ? [UIColor labelColor] : [UIColor systemRedColor];
        if (ApolloBarkModeActive()) {
            // Bark is on and the URL is usable — sync the backend device row
            // so the (new) endpoint applies immediately. Covers both
            // first-time setup (toggle flipped before the URL existed) and
            // endpoint edits on an already-registered device.
            ApolloBarkSyncBackendDeviceTransport();
        }
    }
}

- (NSArray<ApolloSettingsSection *> *)buildForm {
    return @[ [self buildNotificationBackendSection] ];
}

@end