#import <UIKit/UIKit.h>

@interface ApolloSettingsTableViewController : UITableViewController

- (UITableView *)apollo_sourceThemeTableView;

- (UITableViewCell *)stackedTextFieldCellWithIdentifier:(NSString *)identifier
                                                  label:(NSString *)label
                                            placeholder:(NSString *)placeholder
                                                   text:(NSString *)text
                                                    tag:(NSInteger)tag;

- (UITableViewCell *)stackedTextFieldCellWithIdentifier:(NSString *)identifier
                                                  label:(NSString *)label
                                            placeholder:(NSString *)placeholder
                                                   text:(NSString *)text
                                                    tag:(NSInteger)tag
                                                 detail:(NSString *)detail;

- (UITableViewCell *)switchCellWithIdentifier:(NSString *)identifier
                                        label:(NSString *)label
                                       detail:(NSString *)detail
                                           on:(BOOL)on
                                       action:(SEL)action;

- (UITableViewCell *)switchCellWithIdentifier:(NSString *)identifier
                                        label:(NSString *)label
                                       detail:(NSString *)detail
                                           on:(BOOL)on
                                      enabled:(BOOL)enabled
                                       action:(SEL)action;

- (UIColor *)apollo_themeCellBackgroundColor;
- (UIColor *)apollo_themeAccentColor;
- (void)apollo_applyPrimaryTextColorToCell:(UITableViewCell *)cell;
- (void)apollo_applyAccentActionTextColorToCell:(UITableViewCell *)cell;
- (void)apollo_applyThemeToCell:(UITableViewCell *)cell;
- (void)apollo_applyTheme;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

@end

@interface ApolloFooterLinkTextView : UITextView
@end
