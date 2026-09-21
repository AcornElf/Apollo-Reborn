//
//  ApolloAuthorInsights.xm
//  Apollo-Reborn
//
//  Prototype: inserts a fake author-insights row into the CommentsHeaderCellNode
//  layout, immediately after Apollo's existing PostInfoNode.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "ApolloCommon.h"
#import "ApolloTextureDecls.h"

#pragma mark - Node

static const void *kApolloAuthorInsightsNodeKey = &kApolloAuthorInsightsNodeKey;

static ASTextNode *ApolloAuthorInsightsEnsureNode(id headerNode) {
    ASTextNode *node = objc_getAssociatedObject(headerNode, kApolloAuthorInsightsNodeKey);
    if (node) return node;

    node = [ASTextNode new];
    node.userInteractionEnabled = NO;
    node.maximumNumberOfLines = 1;

    node.attributedText =
        [[NSAttributedString alloc] initWithString:@"96% upvoted · 96 ↑ 4 ↓ · 96:4"
                                         attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:12.0],
        NSForegro        NSForegro       UIColor whiteColor]
    }];

    node.backgroundColor = [UIColor systemRedColor];
    node.cornerRadius = 4.0;

    objc_setAssociatedObject(headerNode,
                             kApolloAuthorInsightsNodeKey,
                                                                                       _NO                      pla                             :node];

    return node    return node    return node    return node    return node    rlloAuthorInsightsRebuildStack(
    ASStackLayoutSpec *stack,
    NSArray *children
))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))et)))))))))))))))))))))))))utS)))))))))))))))))))))))))))ck)))))))))))))))))))))))))))))))))))sta))))))))))))))))))))))))))))))                        spacing:))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))                                    alignItems:stack.alignI)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))re)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))gnContent = stack.alignContent;
    rebuilt.lineSpacing = stack.    rebuilt.lineSpacing = sbui    rebuilt.lineSpacing = stack.    reoAuthorInsightsInsertAfterPostInfo(
    ASStackLayoutSpec *sta    ASStackLayoutSpec *sta    ASStackLayoutSpec *sta    ASStackLayoutSpec *sta    ASStackLayoutSpec *sta    ASStackLayoutSpec *sta    ASStackLayoutSpeOfClass:stackClass] || depth > 6) {
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

            return ApolloAuthorInsightsRebuildStack(stack, rebuiltChildren);
        }
    }

    // The PostInfoNode may be inside a nested stack.
    for (NSUInteger i = 0; i < children.count; i++) {
        id child = children[i];

        if ([child isKindOfClass:stackClass]) {
            ASStackLayoutSpec *rebuilt =
                ApolloAuthorInsightsInsertAfterPostInfo(
                    (ASStackLayoutSpec *)child,
                    insightNode,
                    depth + 1
                                                                      leArray *rebuiltChildren = [children mutableCopy];
                rebuiltChildren[i] = rebuilt;
                return ApolloAuthorInsightsRe                return ApolloAutn);
            }
        }
    }

                                                                       c, id insightNode, NSUInteger depth) {
    if (!rootSpec || !insightNode || depth > 6) return nil;

    Class stackClass = NSClassFromString(@"ASStackLayoutSpec");
    Class insetClass = NSClassFromString(@"ASInsetLayoutSpec");

    if (stackClass && [rootSpec isKindOfClass:stackClass]) {
        return ApolloAuthorInsightsInsertAfterPostInfo(
            (ASStackLayoutSpec *)rootSpec,
            insightNode,
            0
        );
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

- (id)layoutSpecThatFits:(- (id)layoutSpecThatFits:(- (id)layoutSpecThatFits:(- (idigin- (id)layoutSpecThatFits:(- (id)layoutSpecThatFits:(- (id)lay ApolloAuthorInsightsEnsureNode((id)self);
        if (!insightNode) return originalSpec;

        id rebuilt =
            ApolloAuthorInsightsPlaceInSpec(originalSpec,
                                            insightNode,
                                            0);

        if (rebuilt) return rebuilt;

        ApolloLog(@"[AuthorInsights][layout] PostInfoNode not found; leaving original layout unchan        ApolloLog(@"[Autnused id e) {
    }

    return originalSpec;
}

%end
