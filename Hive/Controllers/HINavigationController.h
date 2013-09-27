//
//  HINavigationController.h
//  Hive
//
//  Created by Jakub Suder on 30.08.2013.
//  Copyright (c) 2013 Hive Developers. All rights reserved.
//

#import "HIViewController.h"
#import "HITitleView.h"

@interface HINavigationController : HIViewController <HITitleViewDelegate>

@property (readonly) HIViewController *topViewController;
@property (readonly) HIViewController *rootViewController;

- (id)initWithRootViewController:(HIViewController *)rootViewController;
- (NSArray *)viewControllers;

- (void)pushViewController:(HIViewController *)controller animated:(BOOL)animated;
- (void)popViewController:(BOOL)animated;
- (void)popToRootViewControllerAnimated:(BOOL)animated;
- (void)popToViewController:(HIViewController *)controller animated:(BOOL)animated;

@end