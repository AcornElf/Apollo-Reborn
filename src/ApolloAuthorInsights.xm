//
//  ApolloAuthorInsights.xm
//  Apollo-Reborn
//
//  Prototype: inserts a fake author-insights row into the
//  CommentsHeaderCellNode layout, immediately after PostInfoNode.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ApolloCommon.h"
#import "ApolloTextureDecls.h"
#import "ApolloAccountCredentials.h"
#import "Tweak.h"

@interface RDKLink (ApolloAuthorInsightsAccessor)
@property (nonatomic, readonly) double upvoteRatio;
@end

#pragma mark - Node

static const void *kApolloAuthorInsightsNodeKey = &kApolloAuthorInsightsNodeKey;

static ASDisplayNode *ApolloAuthorInsightsEnsureNode(id headerNode,
                                                     NSString *text) {
    ASDisplayNode *node =
        objc_getAssociatedObject(headerNode, kApolloAuthorInsightsNodeKey);

    if (node) return node;

    Class textNodeClass = NSClassFromString(@"ASTextNode");
    if (!textNodeClass) {
        ApolloLog(@"[AuthorInsights][UI] ASTextNode class not found");
        return nil;
    }

    node = [[textNodeClass alloc] init];
    node.userInteractionEnabled = NO;
    node.backgroundColor = [UIColor systemRedColor];
    node.cornerRadius = 4.0;

    ASTextNode *textNode = (ASTextNode *)node;
    textNode.maximumNumberOfLines = 1;
    textNode.attributedText =
        [[NSAttributedString alloc]
            initWithString:text
                attributes:@{
                    NSFontAttributeName:
                        [UIFont systemFontOfSize:12.0],
                    NSForegroundColorAttributeName:
                        [UIColor whiteColor]
                }];

    objc_setAssociatedObject(headerNode,
                             kApolloAuthorInsightsNodeKey,
                             node,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [(ASDisplayNode *)headerNode addSubnode:node];

    return node;
}

#pragma mark - Layout helpers

static ASStackLayoutSpec *ApolloAuthorInsightsRebuildStack(
    ASStackLayoutSpec *stack,
    NSArray *children
) {
    Class stackClass = NSClassFromString(@"ASStackLayoutSpec");
    if (!stackClass) return nil;

    ASStackLayoutSpec *rebuilt =
        [stackClass stackLayoutSpecWithDirection:stack.direction
                                         spacing:stack.spacing
                                  justifyContent:stack.justifyContent
                                      alignItems:stack.alignItems
                                        children:children];

    rebuilt.flexWrap = stack.flexWrap;
    rebuilt.alignContent = stack.alignContent;
    rebuilt.lineSpacing = stack.lineSpacing;

    return rebuilt;
}

static ASStackLayoutSpec *ApolloAuthorInsightsInsertAfterPostInfo(
    ASStackLayoutSpec *stack,
    id insightNode,
    NSUInteger depth
) {
    Class stackClass = NSClassFromString(@"ASStackLayoutSpec");

    if (!stackClass ||
        ![stack isKindOfClass:stackClass] ||
        depth > 6) {
        return nil;
    }

    NSArray *children = stack.children ?: @[];

    for (NSUInteger i = 0; i < children.count; i++) {
        id child = children[i];
        NSString *className = NSStringFromClass([child class]);

        if ([className isEqualToString:@"Apollo.PostInfoNode"] ||
            [className isEqualToString:@"_TtC6Apollo12PostInfoNode"]) {

            NSMutableArray *rebuiltChildren = [children mutableCopy];
            [rebuiltChildren insertObject:insightNode atIndex:i + 1];

            ApolloLog(@"[AuthorInsights][layout] found PostInfoNode at depth %lu index %lu",
                      (unsigned long)depth,
                      (unsigned long)i);

            return ApolloAuthorInsightsRebuildStack(stack,
                                                     rebuiltChildren);
        }
    }

    for (NSUInteger i = 0; i < children.count; i++) {
        id child = children[i];

        if ([child isKindOfClass:stackClass]) {
            ASStackLayoutSpec *rebuilt =
                ApolloAuthorInsightsInsertAfterPostInfo(
                    (ASStackLayoutSpec *)child,
                    insightNode,
                    depth + 1);

            if (rebuilt) {
                NSMutableArray *rebuiltChildren = [children mutableCopy];
                rebuiltChildren[i] = rebuilt;

                return ApolloAuthorInsightsRebuildStack(
                    stack,
                    rebuiltChildren);
            }
        }
    }

    return nil;
}

static id ApolloAuthorInsightsPlaceInSpec(
    id rootSpec,
    id insightNode,
    NSUInteger depth
) {
    if (!rootSpec || !insightNode || depth > 6) return nil;

    Class stackClass = NSClassFromString(@"ASStackLayoutSpec");
    Class insetClass = NSClassFromString(@"ASInsetLayoutSpec");

    if (stackClass && [rootSpec isKindOfClass:stackClass]) {
        return ApolloAuthorInsightsInsertAfterPostInfo(
            (ASStackLayoutSpec *)rootSpec,
            insightNode,
            0);
    }

    if (insetClass && [rootSpec isKindOfClass:insetClass]) {
        ASInsetLayoutSpec *inset = (ASInsetLayoutSpec *)rootSpec;

        id rebuiltChild =
            ApolloAuthorInsightsPlaceInSpec(inset.child,
                                            insightNode,
                                            depth + 1);

        if (!rebuiltChild) return nil;

        return [insetClass insetLayoutSpecWithInsets:inset.insets
                                               child:rebuiltChild];
    }

    return nil;
}

#pragma mark - Header

%hook _TtC6Apollo22CommentsHeaderCellNode

- (id)layoutSpecThatFits:(struct ApolloTextureSizeRange)constrainedSize {
    id originalSpec = %orig;

    @try {
        RDKLink *link = MSHookIvar<RDKLink *>(self, "link");
        NSString *activeUsername = ApolloActiveAccountUsername();

        long long score = link.score;
        double upvoteRatio = link.upvoteRatio;

        long long upvotes = 0;
        long long downvotes = 0;

        BOOL hasVoteCounts =
            ApolloApproximateVoteCounts(score,
                                        upvoteRatio * 100.0,
                                        &upvotes,
                                        &downvotes);

        if (link.author.length == 0 || activeUsername.length == 0) {
            return originalSpec;
        }

        if ([link.author caseInsensitiveCompare:activeUsername] != NSOrderedSame) {
            return originalSpec;
        }

        NSString *percentText =
        [NSString stringWithFormat:@"%.0f%%", upvoteRatio * 100.0];

    NSString *insightText;

    if (hasVoteCounts) {
        insightText =
            [NSString stringWithFormat:@"%@ upvoted · ↑ %lld ↓ %lld · %.0f:%.0f",
                                    percentText,
                                    upvotes,
                                    downvotes,
                                    upvoteRatio * 100.0,
                                    (1.0 - upvoteRatio) * 100.0];
    } else {
        insightText =
            [NSString stringWithFormat:@"%@ upvoted",
                                    percentText];
    }

    ASDisplayNode *insightNode =
        ApolloAuthorInsightsEnsureNode((id)self, insightText);

        if (!insightNode) return originalSpec;

        id rebuilt =
            ApolloAuthorInsightsPlaceInSpec(originalSpec,
                                            insightNode,
                                            0);

        if (rebuilt) return rebuilt;

        ApolloLog(@"[AuthorInsights][layout] PostInfoNode not found; leaving original layout unchanged");
    }
    @catch (__unused id e) {
        ApolloLog(@"[AuthorInsights][probe] exception while reading link/author");
    }

    return originalSpec;
}

%end