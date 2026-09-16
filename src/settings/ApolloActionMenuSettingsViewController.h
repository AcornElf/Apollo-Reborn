#import "ApolloSettingsForm.h"

// "Action Menus" screen (Apollo Reborn → Interface): reorder and hide the rows
// of Apollo's ••• menus — the feed's, a post's, a post's comments view's and a
// comment's. The ••• button top-right is the preview: it opens the menu being
// edited as Apollo would open it right now (a real UIMenu on Liquid Glass, a
// classic-sheet lookalike before it). Touch and hold a row to drag it into
// place; its switch hides it (and brings it back later). Model, item catalogue
// and persistence live in ApolloActionMenuLayout.h; the menus themselves read
// the saved layout in ApolloActionMenu.xm.
@interface ApolloActionMenuSettingsViewController : ApolloSettingsFormViewController
@end
