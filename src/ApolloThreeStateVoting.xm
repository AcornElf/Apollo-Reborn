// Three-state score-tap voting for comments and posts.
// Neutral → upvote → downvote → neutral.
// Uses Apollo's native action controller for voting and UI updates.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <stdint.h>

#import "ApolloNativeActionMenus.h"
#import "ApolloState.h"

// Cycle score taps through no vote → upvote → downvote → no vote.
// Apollo's native action controller handles the actual vote and UI updates.
static BOOL ApolloThreeStateInvokeNextAction(id actionController) {
    uint16_t action = UINT16_MAX;

    if (ApolloNativeActionMenuHasAction(actionController, 6)) {
        // Downvoted → No vote
        action = 6;
    } else if (ApolloNativeActionMenuHasAction(actionController, 4)) {
        // Upvoted → Downvoted
        action = 5;
    } else if (ApolloNativeActionMenuHasAction(actionController, 3)) {
        // No vote → Upvoted
        action = 3;
    }

    if (action == UINT16_MAX ||
        !ApolloNativeActionMenuHasAction(actionController, action)) {
        NSLog(@"[VoteCycle] Native action unavailable");
        return NO;
    }

    NSLog(@"[VoteCycle] Invoking native action %u", action);
    ApolloNativeActionMenuInvokeAction(actionController, action);
    return YES;
}

static BOOL ApolloThreeStateCycleVote(id cell, id sender, SEL menuSelector) {
    UIView *sourceView = nil;

    if ([sender respondsToSelector:@selector(view)]) {
        sourceView = ((id (*)(id, SEL))objc_msgSend)(
            sender, @selector(view));
    }

    if (!sourceView.window ||
        ![cell respondsToSelector:menuSelector]) {
        return NO;
    }

    id actionController = ApolloNativeActionMenuCaptureController(sourceView, ^{
        ((void (*)(id, SEL, id))objc_msgSend)(
            cell, menuSelector, sender);
    });

    return ApolloThreeStateInvokeNextAction(actionController);
}

%hook _TtC6Apollo15CommentCellNode

- (void)pointsTappedWithSender:(id)sender {
    if (!sThreeStateVoting || !ApolloThreeStateCycleVote(
            self, sender, @selector(moreOptionsTappedWithSender:))) {
        %orig;
    }
}

%end

%hook _TtC6Apollo17LargePostCellNode

- (void)pointsButtonTappedWithSender:(id)sender {
    if (!sThreeStateVoting || !ApolloThreeStateCycleVote(
            self, sender, @selector(moreOptionsButtonTappedWithSender:))) {
        %orig;
    }
}

%end

%hook _TtC6Apollo19CompactPostCellNode

- (void)pointsButtonTappedWithSender:(id)sender {
    if (!sThreeStateVoting || !ApolloThreeStateCycleVote(
            self, sender, @selector(moreOptionsButtonTappedWithSender:))) {
        %orig;
    }
}

%end

// Find the post-detail controller through the score button's responder chain.
static BOOL ApolloThreeStateCycleHeaderVote(id sender) {
    UIView *sourceView = nil;

    if ([sender respondsToSelector:@selector(view)]) {
        sourceView = ((id (*)(id, SEL))objc_msgSend)(
            sender, @selector(view));
    }

    if (!sourceView.window) return NO;

    Class commentsClass =
        objc_getClass("_TtC6Apollo22CommentsViewController");

    UIResponder *responder = sourceView;
    id commentsController = nil;

    while (responder) {
        if (commentsClass && [responder isKindOfClass:commentsClass]) {
            commentsController = responder;
            break;
        }
        responder = responder.nextResponder;
    }

    SEL menuSelector =
        @selector(moreOptionsBarButtonItemTappedWithSender:);

    if (!commentsController ||
        ![commentsController respondsToSelector:menuSelector]) {
        NSLog(@"[VoteCycle] Post-detail controller unavailable");
        return NO;
    }

    id actionController =
        ApolloNativeActionMenuCaptureController(sourceView, ^{
            ((void (*)(id, SEL, id))objc_msgSend)(
                commentsController, menuSelector, sourceView);
        });

    return ApolloThreeStateInvokeNextAction(actionController);
}

%hook _TtC6Apollo22CommentsHeaderCellNode

- (void)pointsButtonTappedWithSender:(id)sender {
    if (!sThreeStateVoting || !ApolloThreeStateCycleHeaderVote(sender)) {
        %orig;
    }
}

%end

%ctor {
    %init;
}
