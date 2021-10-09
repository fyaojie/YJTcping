//
//  CMSViewController.m
//  YJTcping
//
//  Created by 562925462@qq.com on 10/09/2021.
//  Copyright (c) 2021 562925462@qq.com. All rights reserved.
//

#import "CMSViewController.h"
#import <YJTcping.h>
@interface CMSViewController ()

@end

@implementation CMSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [YJTcping startTcping];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
