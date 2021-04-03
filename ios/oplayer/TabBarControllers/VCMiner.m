//
//  VCMiner.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCMiner.h"

#import "VCAssetOpMiner.h"
#import "VCMinerRelationData.h"

#import "WalletManager.h"
#import "OrgUtils.h"

enum
{
    kVcSecMiner = 0,        //  MINER挖矿
    kVcSecScny,             //  SCNY挖矿
    kVcSecShare,            //  推荐挖矿
};

enum
{
    kVcSubMinerMining = 0,  //  MINER锁仓挖矿
    kVcSubScnyMining,       //  SCNY抵押挖矿
    kVcSubMinerExit,        //  退出MINER挖矿工
    kVcSubScnyExit,         //  退出SCNY挖矿
    
    kVcSubDataMiner,        //  MINER推荐挖矿数据
    kVcSubDataScny,         //  SCNY推荐挖矿数据
    
    kVcSubShareLink,        //  邀请好久（推荐挖矿）
};

@interface VCMiner ()
{    
    UITableView*            _mainTableView;
    NSArray*                _dataArray; //  assgin
}

@end

@implementation VCMiner

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (void)_genDataArray
{
    NSArray* pSection1 = @[
        @[@(kVcSubMinerMining),     @"kMinerCellLabelMinerMining"],                         //  MINER挖矿
        @[@(kVcSubMinerExit),       @"kMinerCellLabelMinerExit"],                           //  退出MINER挖矿
    ];
    
    NSArray* pSection2 = @[
        @[@(kVcSubScnyMining),      @"kMinerCellLabelScnyMining"],                          //  SCNY挖矿
        @[@(kVcSubScnyExit),        @"kMinerCellLabelScnyExit"],                            //  退出SCNY挖矿
    ];
    
    NSArray* pSection3 = @[
        @[@(kVcSubDataMiner),       @"kMinerCellLabelDataMiner"],                           //  MINER推荐挖矿数据
        @[@(kVcSubDataScny),        @"kMinerCellLabelDataScny"],                            //  SCNY推荐挖矿数据
        @[@(kVcSubShareLink),       @"kMinerCellLabelShareLink"],                           //  邀请好友
    ];
    
    _dataArray = [@[pSection1, pSection2, pSection3] ruby_select:^BOOL(id section) {
        return [section count] > 0;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  初始化数据
    [self _genDataArray];
    
    //  UI - 列表
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNaviAndTab] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_dataArray objectAtIndex:section] count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44.0f;
}

/**
 *  (private) 介绍按钮点击
 */
- (void)onIntroButtonClicked:(UIButton*)sender
{
    //  TODO:2.2 TODO:2.3  TODO:3.0
    //    if (!_owner){
    //        return;
    //    }
    //
    //    id group_data = [_marketInfos[@"group_list"] objectAtIndex:sender.tag];
    //    id group_link = [group_data objectForKey:@"group_link"];
    //    if (!group_link || [group_link isEqualToString:@""]) {
    //        return;
    //    }
    //
    //    [OrgUtils safariOpenURL:group_link];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    id sec_title = @"";
    
    switch (section) {
        case kVcSecMiner:
            sec_title = NSLocalizedString(@"kMinerSecTitleMiner", @"NBS锁仓挖矿");
            break;
        case kVcSecScny:
            sec_title = NSLocalizedString(@"kMinerSecTitleScny", @"nbCNY抵押挖矿");
            break;
        case kVcSecShare:
            sec_title = NSLocalizedString(@"kMinerSecTitleShare", @"推荐挖矿");
            break;
        default:
            break;
    }
    
    CGFloat fWidth = self.view.bounds.size.width;
    
    UIView* myView = [[UIView alloc] init];
    myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, fWidth - 24, 44)];    //  REMARK：12 和 ViewMarketTickerInfoCell 里控件边距一致。
    titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    
    titleLabel.text = sec_title;
    
    [myView addSubview:titleLabel];
    
    //  介绍
    UIButton* introButton = [UIButton buttonWithType:UIButtonTypeSystem];
    introButton.titleLabel.font = [UIFont systemFontOfSize:13];
    introButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [introButton setTitle:NSLocalizedString(@"kLabelGroupIntroduction", @"介绍 >") forState:UIControlStateNormal];
    [introButton setTitleColor:[ThemeManager sharedThemeManager].textColorGray forState:UIControlStateNormal];
    introButton.userInteractionEnabled = YES;
    [introButton addTarget:self action:@selector(onIntroButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    introButton.frame = CGRectMake(fWidth - 120 - 12, 0, 120, 44);
    introButton.tag = section;
    [myView addSubview:introButton];
    
    return myView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    cell.backgroundColor = [UIColor clearColor];
    
    cell.showCustomBottomLine = YES;
    
    cell.textLabel.text = NSLocalizedString([item lastObject], @"");
    cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
    
    switch ([[item firstObject] integerValue]) {
        case kVcSubMinerMining:
        case kVcSubScnyMining:
            cell.imageView.image = [UIImage templateImageNamed:@"iconDeposit"];
            break;
        case kVcSubMinerExit:
        case kVcSubScnyExit:
            cell.imageView.image = [UIImage templateImageNamed:@"iconWithdraw"];
            break;
            
        case kVcSubDataMiner:
        case kVcSubDataScny:
            cell.imageView.image = [UIImage templateImageNamed:@"iconOrders"];
            break;
            
        case kVcSubShareLink:
            cell.imageView.image = [UIImage templateImageNamed:@"iconShare"];
            break;
        default:
            break;
    }
    
    cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        UIViewController* vc = nil;
        
        id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        switch ([[item firstObject] integerValue]) {
            case kVcSubMinerMining:
            {
                [self GuardWalletExist:^{
                    [self gotoMiningOrExit:@"1.3.0"];   //  NBS TODO:立即值
                }];
            }
                break;
            case kVcSubScnyMining:
            {
                [self GuardWalletExist:^{
                    [self gotoMiningOrExit:@"1.3.14"];  //  CNY TODO:立即值
                }];
            }
                break;
            case kVcSubMinerExit:
            {
                [self GuardWalletExist:^{
                    [self gotoMiningOrExit:@"1.3.23"];  //  MINER TODO:立即值
                }];
            }
                break;
            case kVcSubScnyExit:
            {
                [self GuardWalletExist:^{
                    [self gotoMiningOrExit:@"1.3.24"];  //  SCNY TODO:立即值
                }];
            }
                break;
            case kVcSubDataMiner:
            {
                [self GuardWalletExist:^{
                    [self gotoViewMiningData:@"1.3.23"  //  MINER TODO:立即值
                                       title:NSLocalizedString(@"kVcTitleAssetMiningDataMiner", @"MINER挖矿数据")];
                }];
            }
                break;
            case kVcSubDataScny:
            {
                [self GuardWalletExist:^{
                    [self gotoViewMiningData:@"1.3.24"  //  SCNY TODO:立即值
                                       title:NSLocalizedString(@"kVcTitleAssetMiningDataScny", @"SCNY挖矿数据")];
                }];
            }
                break;
            case kVcSubShareLink:
            {
                [self GuardWalletExist:^{
                    //  TODO:2.2 TODO:2.3 TODO:3.0 link & test & copytest
                    id value = [VcUtils genShareLink:YES];
                    [UIPasteboard generalPasteboard].string = [value copy];
                    [OrgUtils makeToast:NSLocalizedString(@"kShareLinkCopied", @"分享链接已复制。")];
                }];
            }
                break;
            default:
                break;
        }
        if (vc){
            [self pushViewController:vc vctitle:nil backtitle:kVcDefaultBackTitleName];
        }
    }];
}

- (void)gotoViewMiningData:(NSString*)asset_id title:(NSString*)title
{
    assert(asset_id);
    VCMinerRelationData* vc = [[VCMinerRelationData alloc] initWithAsset:asset_id];
    [self pushViewController:vc vctitle:title backtitle:kVcDefaultBackTitleName];
}

- (void)gotoMiningOrExit:(NSString*)asset_id
{
    assert(asset_id);
    
    id miner_item = [[SettingManager sharedSettingManager] getAppAssetMinerItem:asset_id];
    if (!miner_item) {
        [OrgUtils makeToast:NSLocalizedString(@"kMinerCellClickTipsDontSupportedFeature", @"该功能未开启。")];
        return;
    }
    
    assert([[WalletManager sharedWalletManager] isWalletExist]);
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    
    id min_to_receive_asset_id = [[[miner_item objectForKey:@"price"] objectForKey:@"min_to_receive"] objectForKey:@"asset_id"];
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id p1 = [chainMgr queryFullAccountInfo:[op_account objectForKey:@"id"]];
    id p2 = [chainMgr queryAllGrapheneObjects:@[asset_id, min_to_receive_asset_id]];
    
    [VcUtils simpleRequest:self
                   request:[WsPromise all:@[p1, p2]]
                  callback:^(id data_array) {
        id full_account = [data_array objectAtIndex:0];
        VCAssetOpMiner* vc = [[VCAssetOpMiner alloc] initWithMinerItem:miner_item
                                                     full_account_data:full_account
                                                        result_promise:nil];
        id title = [[miner_item objectForKey:@"miner"] boolValue] ? NSLocalizedString(@"kVcTitleAssetOpMinerIn", @"挖矿") : NSLocalizedString(@"kVcTitleAssetOpMinerOut", @"退出挖矿");
        [self pushViewController:vc vctitle:title backtitle:kVcDefaultBackTitleName];
    }];
}

#pragma mark- switch theme
- (void)switchTheme
{
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    if (_mainTableView){
        [_mainTableView reloadData];
    }
}

#pragma mark- switch language
- (void)switchLanguage
{
    self.title = NSLocalizedString(@"kTabBarNameMiner", @"挖矿");
    self.tabBarItem.title = NSLocalizedString(@"kTabBarNameMiner", @"挖矿");
    if (_mainTableView) {
        [_mainTableView reloadData];
    }
}

@end
