//
//  DBNFourthViewController.m
//  DoubleNavigationController_Example
//
//  Created by Yao Li on 2019/3/29.
//  Copyright © 2019 yao.li. All rights reserved.
//

#import "DBNFourthViewController.h"
#import <DoubleNavigationController/DoubleNavigationControllerProtocol.h>

@interface DBNFourthViewController ()

@end

@implementation DBNFourthViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    UIButton *testButton = [[UIButton alloc] initWithFrame:CGRectMake(50, 200, 180, 40)];
    [self.view addSubview:testButton];
    [testButton setTitle:@"Back To Root" forState:UIControlStateNormal];
    [testButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [testButton addTarget:self action:@selector(eventFromButton:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)eventFromButton:(UIButton *)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}
@end
