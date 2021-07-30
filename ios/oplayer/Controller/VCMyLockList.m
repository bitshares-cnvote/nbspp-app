//
//  VCMyLockList.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCMyLockList.h"
#import "VCVestingBalance.h"
#import "VCSearchNetwork.h"
#import "VCImportAccount.h"
#import "BitsharesClientManager.h"
#import "ViewLockPositionCell.h"
#import "OrgUtils.h"
#import "ScheduleManager.h"
#import "MyPopviewManager.h"

@interface VCMyLockList ()
{
    NSDictionary*           _fullAccountInfo;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCMyLockList

-(void)dealloc
{
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _fullAccountInfo = nil;
}

- (id)initWithFullAccountInfo:(NSDictionary*)accountInfo
{
    self = [super init];
    if (self){
        _fullAccountInfo = accountInfo;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)onQueryVestingBalanceResponsed:(NSArray*)data_array
{
    //  更新数据
    [_dataArray removeAllObjects];
    if (data_array && [data_array count] > 0){
        for (id vesting in data_array) {
            id oid = [vesting objectForKey:@"id"];
            assert(oid);
            if (!oid){
                continue;
            }
            //  该界面仅显示普通 vesting balance，略过锁仓挖矿的 vesting balance 对象。
            if (![VCVestingBalance isLockMiningVestingObject:vesting]) {
                continue;
            }
            //  略过总金额为 0 的待解冻金额对象。
            if ([[[vesting objectForKey:@"balance"] objectForKey:@"amount"] unsignedLongLongValue] == 0){
                continue;
            }
            //  linear_vesting_policy = 0,
            //  cdd_vesting_policy = 1,
            //  instant_vesting_policy = 2,
            switch ([[[vesting objectForKey:@"policy"] objectAtIndex:0] integerValue]) {
                case ebvp_cdd_vesting_policy:
                    [_dataArray addObject:vesting];
                    break;
                default:
                    //  不支持的其他的新类型
                    break;
            }
        }
    }
    
    //  根据ID降序排列
    if ([_dataArray count] > 0){
        [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger id1 = [[[[obj1 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            NSInteger id2 = [[[[obj2 objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            return id2 - id1;
        })];
    }
    
    //  更新显示
    _mainTableView.hidden = [_dataArray count] == 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryVestingBalance
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    id account = [_fullAccountInfo objectForKey:@"account"];
    id uid = [account objectForKey:@"id"];
    assert(uid);
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
    
    id p1 = [api exec:@"get_vesting_balances" params:@[uid]];
    [[p1 then:^id(id data_array) {
        NSMutableDictionary* asset_ids = [NSMutableDictionary dictionary];
        for (id vesting in data_array) {
            [asset_ids setObject:@YES forKey:[[vesting objectForKey:@"balance"] objectForKey:@"asset_id"]];
        }
        //  查询 & 缓存
        return [[chainMgr queryAllAssetsInfo:[asset_ids allKeys]] then:(^id(id asset_hash) {
            [self hideBlockView];
            [self onQueryVestingBalanceResponsed:data_array];
            return nil;
        })];
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNaviAndPageBar];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kVcMyStakeListUITipsNoData", @"没有任何锁仓对象")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
    
    //  查询
    [self queryVestingBalance];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataArray count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat baseHeight = 8.0 + 28 + 24 * 2;
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* identify = @"id_lockup_position_info_cell";
    ViewLockPositionCell* cell = (ViewLockPositionCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewLockPositionCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify vc:self];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.showCustomBottomLine = YES;
    cell.row = indexPath.row;
    [cell setTagData:indexPath.row];
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/**
 *  事件 - 提取待解冻金额
 */
- (void)onButtonClicked_Withdraw:(UIButton*)button
{
    id vesting = [_dataArray objectAtIndex:button.tag];
    NSLog(@"vesting : %@", vesting[@"id"]);
    
    id policy = [vesting objectForKey:@"policy"];
    assert(policy);
    
    switch ([[policy objectAtIndex:0] integerValue]) {
        case ebvp_cdd_vesting_policy:       //  验证提取日期
        {
            id policy_data = [policy objectAtIndex:1];
            id start_claim = [policy_data objectForKey:@"start_claim"];
            NSTimeInterval start_claim_ts = [OrgUtils parseBitsharesTimeString:start_claim];
            NSTimeInterval now_ts = [[NSDate date] timeIntervalSince1970];
            if (now_ts <= start_claim_ts){
                id s = [OrgUtils getDateTimeLocaleString:[NSDate dateWithTimeIntervalSince1970:start_claim_ts]];
                [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVestingTipsStartClaim", @"该笔金额在 %@ 之后方可提取。"), s]];
                return;
            }
        }
            break;
        default:
            assert(false);
            break;
    }
    
    //  计算可提取数量 到期全部提取。
    unsigned long long withdraw_available = [[[vesting objectForKey:@"balance"] objectForKey:@"amount"] unsignedLongLongValue];
    assert(withdraw_available > 0);
    
    //  ----- 准备提取 -----
    //  1、判断手续费是否足够。
    id extra_balance = @{[[vesting objectForKey:@"balance"] objectForKey:@"asset_id"]:@(withdraw_available)};
    id fee_item =  [[ChainObjectManager sharedChainObjectManager] getFeeItem:ebo_vesting_balance_withdraw
                                                           full_account_data:_fullAccountInfo
                                                               extra_balance:extra_balance];
    if (![[fee_item objectForKey:@"sufficient"] boolValue]){
        [OrgUtils makeToast:NSLocalizedString(@"kTipsTxFeeNotEnough", @"手续费不足，请确保帐号有足额的 BTS/CNY/USD 用于支付网络手续费。")];
        return;
    }
    
    //  2、解锁钱包or账号
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked){
            [self processWithdrawVestingBalanceCore:vesting
                                  full_account_data:_fullAccountInfo
                                           fee_item:fee_item
                                 withdraw_available:withdraw_available];
        }
    }];
}


- (void)processWithdrawVestingBalanceCore:(id)vesting_balance
                        full_account_data:(id)full_account_data
                                 fee_item:(id)fee_item
                       withdraw_available:(unsigned long long)withdraw_available
{
    assert(vesting_balance);
    assert(full_account_data);
    assert(fee_item);
    id balance_id = vesting_balance[@"id"];
    
    id balance = vesting_balance[@"balance"];
    assert(balance);
    id account = [full_account_data objectForKey:@"account"];
    assert(account);
    
    id uid = [account objectForKey:@"id"];
    
    id op = @{
        @"fee":@{@"amount":@0, @"asset_id":fee_item[@"fee_asset_id"]},
        @"vesting_balance":balance_id,
        @"owner":uid,
        @"amount":@{@"amount":@(withdraw_available), @"asset_id":balance[@"asset_id"]}
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_vesting_balance_withdraw
                     using_owner_authority:NO invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] vestingBalanceWithdraw:op] then:(^id(id data) {
            [self hideBlockView];
            //  UI - 提示
            [OrgUtils makeToast:[NSString stringWithFormat:NSLocalizedString(@"kVcMyStakeListSubmitTipsClaimSuccess", @"锁仓资金 %@ 取回成功。"),
                                 balance_id]];
            //  [统计]
            [OrgUtils logEvents:@"txAssetOnchainLockupWithdrawFullOK" params:@{@"account":uid}];
            //  刷新
            [self queryVestingBalance];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txAssetOnchainLockupWithdrawFailed" params:@{@"account":uid}];
            return nil;
        })];
    }];
}

@end
