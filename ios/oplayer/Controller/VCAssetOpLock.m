//
//  VCAssetOpLock.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpLock.h"
#import "VCSearchNetwork.h"
#import "ViewTipsInfoCell.h"

enum
{
    kVcSecOpAsst = 0,           //  要操作的资产
    kVcSecLockPeroidSeconds,    //  锁仓时间
    kVcSecAmount,               //  数量
    kVcSecSubmit,               //  提交按钮
    kVcSecTips,                 //  提示信息
    
    kvcSecMax
};

@interface VCAssetOpLock ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _curr_selected_asset;   //  当前选中资产
    NSDictionary*               _full_account_data;     //  REMARK：提取手续费池等部分操作该参数为nil。
    NSDecimalNumber*            _nCurrBalance;
    NSDictionary*               _curr_lock_item;        //  当前锁仓参数项（可能为nil）
    NSInteger                   _iLockPeriodSeconds;    //  锁仓时间
    
    UITableViewBase*            _mainTableView;
    ViewTextFieldAmountCell*    _tf_amount;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbCommit;
}

@end

@implementation VCAssetOpLock

-(void)dealloc
{
    _result_promise = nil;
    _nCurrBalance = nil;
    if (_tf_amount){
        _tf_amount.delegate = nil;
        _tf_amount = nil;
    }
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cell_tips = nil;
    _lbCommit = nil;
}

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        _result_promise = result_promise;
        _full_account_data = full_account_data;
        [self setCurrentAsset:curr_asset];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

/*
 *  (private) 设置当前资产
 */
- (void)setCurrentAsset:(id)asset_info
{
    assert(asset_info);
    assert(_full_account_data);
    
    //  更新当前资产
    _curr_selected_asset = asset_info;
    
    //  获取当前资产对应的锁仓挖矿条目，可能为nil。
    _curr_lock_item = [[SettingManager sharedSettingManager] getAppAssetLockItem:_curr_selected_asset[@"id"]];
    
    //  获取默认锁仓时长
    _iLockPeriodSeconds = -1;
    //  启用默认锁仓时间
    if ([[[SettingManager sharedSettingManager] getAppParameters:@"enable_default_lock_period"] boolValue]) {
        if (_curr_lock_item) {
            for (id level in [_curr_lock_item objectForKey:@"levels"]) {
                if (_iLockPeriodSeconds <= 0) {
                    _iLockPeriodSeconds = [[level objectForKey:@"seconds"] integerValue];
                }
                if ([[level objectForKey:@"default"] boolValue]) {
                    _iLockPeriodSeconds = [[level objectForKey:@"seconds"] integerValue];
                    break;
                }
            }
        } else {
            id default_list = [[SettingManager sharedSettingManager] getAppParameters:@"lock_period_list"];
            assert(default_list && [default_list count] > 0);
            _iLockPeriodSeconds = [[default_list firstObject] integerValue];
        }
        assert(_iLockPeriodSeconds > 0);
    }
    
    //  更新资产对应的余额。
    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_selected_asset];
}

- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_curr_selected_asset objectForKey:@"symbol"];
    if (not_enough) {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@(%@)",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol,
                           NSLocalizedString(@"kOtcMcAssetTransferBalanceNotEnough", @"余额不足")];
        [_tf_amount drawUI_titleValue:value color:theme.tintColor];
    } else {
        NSString* value = [NSString stringWithFormat:@"%@ %@ %@",
                           NSLocalizedString(@"kOtcMcAssetCellAvailable", @"可用"),
                           _nCurrBalance,
                           symbol];
        [_tf_amount drawUI_titleValue:value color:theme.textColorMain];
    }
}

- (NSString*)genTransferTipsMessage
{
    //  TODO:3.2 lang
    if (_curr_lock_item) {
        id share_asset = [_curr_lock_item objectForKey:@"share_asset"];
        return [NSString stringWithFormat:@"【温馨提示】\n锁仓挖矿和 %@ 挖矿共享同一个矿池奖励。\n1、锁仓 30 天，1.5 倍收益。\n2、锁仓 90 天，2 倍收益。\n3、锁仓 180 天，3 倍收益。\n\n※ 锁仓资产在到期之前不可取回，请谨慎操作。", share_asset];
    } else {
        return @"【温馨提示】\n1、锁仓资产在到期之前不可取回，请谨慎操作。\n2、该资产不是挖矿资产，锁仓不会产生任何收益。";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 数量输入框
    _tf_amount = [[ViewTextFieldAmountCell alloc] initWithTitle:NSLocalizedString(@"kOtcMcAssetTransferCellLabelAmount", @"数量")
                                                    placeholder:@"请输入锁仓数量"//TOOD:3.2 lang
                                                         tailer:[_curr_selected_asset objectForKey:@"symbol"]];
    _tf_amount.delegate = self;
    [self _drawUI_Balance:NO];
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:[self genTransferTipsMessage]];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer* pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    pTap.cancelsTouchesInView = NO; //  IOS 5.0系列导致按钮没响应
    [self.view addGestureRecognizer:pTap];
    
    //  TODO:3.2 lang
    _lbCommit = [self createCellLableButton:@"锁仓"];
}

-(void)onTap:(UITapGestureRecognizer*)pTap
{
    [self resignAllFirstResponder];
}

- (void)resignAllFirstResponder
{
    //  REMARK：强制结束键盘
    [self.view endEditing:YES];
    [_tf_amount endInput];
}

#pragma mark- for UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return [OrgUtils isValidAmountOrPriceInput:textField.text
                                         range:range
                                    new_string:string
                                     precision:[[_curr_selected_asset objectForKey:@"precision"] integerValue]];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecOpAsst || section == kVcSecLockPeroidSeconds) {
        return 2;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
        case kVcSecLockPeroidSeconds:
            if (indexPath.row == 0) {
                return 28.0f;
            }
            break;
        case kVcSecAmount:
            return 28.0f + 44.0f;
        case kVcSecTips:
            return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
        default:
            break;
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 10.0f;
}
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case kVcSecOpAsst:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = @"锁仓资产";//TODO:3.2 lang
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                //  REMARK：这里显示选中资产名称，而不是余额资产名称。
                cell.textLabel.text = [_curr_selected_asset objectForKey:@"symbol"];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.textLabel.textColor = theme.textColorMain;
            }
            return cell;
        }
            break;
        case kVcSecAmount:
            return _tf_amount;
            
        case kVcSecLockPeroidSeconds:
        {
            ThemeManager* theme = [ThemeManager sharedThemeManager];
            
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textColor = theme.textColorMain;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            if (indexPath.row == 0) {
                cell.textLabel.font = [UIFont systemFontOfSize:13.0f];
                cell.textLabel.text = @"锁仓周期";//TODO:3.2 lang
                cell.hideBottomLine = YES;
            } else {
                cell.showCustomBottomLine = YES;
                if (_iLockPeriodSeconds > 0) {
                    cell.textLabel.text = [self _fmtNday:_iLockPeriodSeconds];
                    cell.textLabel.textColor = theme.textColorMain;
                } else {
                    cell.textLabel.text = @"请选择锁仓周期";//TODO:3.2 lang
                    cell.textLabel.textColor = theme.textColorGray;
                }
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            }
            return cell;
        }
            
        case kVcSecTips:
            return _cell_tips;
            
        case kVcSecSubmit:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        default:
            break;
    }
    //  not reached.
    return nil;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        switch (indexPath.section) {
            case kVcSecOpAsst:
            {
                if (indexPath.row == 1) {
                    [self onSelectAssetClicked];
                }
            }
                break;
            case kVcSecLockPeroidSeconds:
            {
                if (indexPath.row == 1) {
                    [self onLockPeriodClicked];
                }
            }
                break;
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSelectAssetClicked
{
    VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
        if (asset_info){
            NSString* new_id = [asset_info objectForKey:@"id"];
            NSString* old_id = [_curr_selected_asset objectForKey:@"id"];
            if (![new_id isEqualToString:old_id]) {
                [self setCurrentAsset:asset_info];
                //  切换资产后重新输入
                [_tf_amount clearInputTextValue];
                [_tf_amount drawUI_newTailer:[_curr_selected_asset objectForKey:@"symbol"]];
                [self _drawUI_Balance:NO];
                [_cell_tips updateLabelText:[self genTransferTipsMessage]];
                [_mainTableView reloadData];
            }
        }
    }];
    
    [self pushViewController:vc
                     vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                   backtitle:kVcDefaultBackTitleName];
}

- (NSString*)_fmtNday:(NSInteger)seconds
{
    NSInteger hours = seconds / 3600;
    if ((hours % 24) == 0) {
        NSInteger days = hours / 24;
        if (days > 1){
            return [NSString stringWithFormat:NSLocalizedString(@"kProposalLabelNDays", @"%@天"), @(days)];
        }else{
            return [NSString stringWithFormat:NSLocalizedString(@"kProposalLabel1Days", @"%@天"), @(days)];
        }
    } else {
        //  非整数”天“，按照小时显示。
        if (hours > 1) {
            return [NSString stringWithFormat:NSLocalizedString(@"kProposalLabelNHours", @"%@小时"), @(hours)];
        } else {
            return [NSString stringWithFormat:NSLocalizedString(@"kProposalLabel1Hours", @"%@小时"), @(hours)];
        }
    }
}

- (void)onLockPeriodClicked
{
    //  REMARK：锁仓时间。
    NSArray* default_list = nil;
    if (_curr_lock_item) {
        default_list = [[_curr_lock_item objectForKey:@"levels"] ruby_map:^id(id src) {
            return [src objectForKey:@"seconds"];
        }];
    } else {
        default_list = [[SettingManager sharedSettingManager] getAppParameters:@"lock_period_list"];
    }
    
    NSMutableArray* data_array = [NSMutableArray array];
    NSInteger default_select = -1;
    for (id sec in default_list) {
        NSInteger seconds = [sec integerValue];
        assert(seconds > 0);
        id name = [self _fmtNday:seconds];
        if (seconds == _iLockPeriodSeconds){
            default_select = [data_array count];
        }
        [data_array addObject:@{@"name":name, @"value":@(seconds)}];
    }
    
    [[[MyPopviewManager sharedMyPopviewManager] showModernListView:self.navigationController
                                                           message:@"锁仓周期"//TODO:3.2 text & lang
                                                             items:data_array
                                                           itemkey:@"name"
                                                      defaultIndex:default_select] then:(^id(id result) {
        if (result){
            NSInteger sec = [[result objectForKey:@"value"] integerValue];
            if (sec != _iLockPeriodSeconds){
                _iLockPeriodSeconds = sec;
                [_mainTableView reloadData];
            }
        }
        return nil;
    })];
}

- (void)onSubmitClicked
{
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:@"请输入有效的锁仓数量。"];//TODO:3.2 lang
        return;
    }
    
    NSDecimalNumber* n_min_amount = [NSDecimalNumber zero];
    if (_curr_lock_item) {
        n_min_amount = [NSDecimalNumber decimalNumberWithMantissa:[[_curr_lock_item objectForKey:@"min_amount"] unsignedLongLongValue]
                                                         exponent:0
                                                       isNegative:NO];
        if ([n_amount compare:n_min_amount] < 0) {
            //  TODO:3.2 lang
            [OrgUtils makeToast:[NSString stringWithFormat:@"单次最低锁仓数量 %@ %@", n_min_amount, _curr_selected_asset[@"symbol"]]];
            return;
        }
    }
    
    if ([_nCurrBalance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    if (_iLockPeriodSeconds <= 0) {
        [OrgUtils makeToast:@"请选择锁仓周期。"];//TODO:3.2 lang
        return;
    }
    
    //  TODO:3.2 text & lang
    id value = [NSString stringWithFormat:@"您确认锁仓 %@ %@ 吗？\n\n※ 锁仓到期之前不可取回，请谨慎操作。", n_amount, _curr_selected_asset[@"symbol"]];
    [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                           withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
                                                          completion:^(NSInteger buttonIndex)
     {
        if (buttonIndex == 1)
        {
            [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
                if (unlocked) {
                    [self _execAssetLockCore:n_amount];
                }
            }];
        }
    }];
}

/*
 *  (private) 执行锁仓操作
 */
- (void)_execAssetLockCore:(NSDecimalNumber*)n_amount
{
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    id uid = [op_account objectForKey:@"id"];
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[_curr_selected_asset[@"precision"] integerValue]]];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    //  查询节点最新区块时间
    GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] last_connection].api_db;
    id p = [api exec:@"get_objects" params:@[@[BTS_DYNAMIC_GLOBAL_PROPERTIES_ID]]];
    [[p then:^id(id data_array) {
        assert(data_array && [data_array count] == 1);
        NSTimeInterval head_block_sec = [OrgUtils parseBitsharesTimeString:[[data_array firstObject] objectForKey:@"time"]];
        
        //  REMARK：锁仓时间使用链上时间作为基准。如果当前节点未同步，比其他节点时间慢少许，则忽略；慢太多，则交易会提交失败，交易过期。
        //  对于节点差细微时间未同步，增加 90s 固定锁仓时间处理。
        NSInteger start_claim_ts = (NSInteger)head_block_sec + _iLockPeriodSeconds + 90;
        id op = @{
            @"fee":@{@"amount":@0, @"asset_id":@"1.3.0"},
            @"creator":uid,
            @"owner":uid,
            @"amount":@{@"amount":@([n_amount_pow unsignedLongLongValue]), @"asset_id":_curr_selected_asset[@"id"]},
            @"policy":@[@1, @{@"start_claim":@(start_claim_ts), @"vesting_seconds":@0}]
        };
        
        //  锁仓不支持提案，因为提案最终执行之前不确定，会导致锁仓到期时间误差。
        [[[[BitsharesClientManager sharedBitsharesClientManager] vestingBalanceCreate:op] then:(^id(id data) {
            [self hideBlockView];
            [OrgUtils makeToast:@"锁仓成功。"];//TODO:3.2 lang
            //  [统计]
            [OrgUtils logEvents:@"txAssetOnchainLockupFullOK" params:@{@"account":op_account[@"id"]}];
            //  返回上一个界面并刷新
            if (_result_promise) {
                [_result_promise resolve:@YES];
            }
            [self closeOrPopViewController];
            return nil;
        })] catch:(^id(id error) {
            [self hideBlockView];
            [OrgUtils showGrapheneError:error];
            //  [统计]
            [OrgUtils logEvents:@"txAssetOnchainLockupFailed" params:@{@"account":op_account[@"id"]}];
            return nil;
        })];
        
        return nil;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;
    }];
}

#pragma mark- for ViewTextFieldAmountCellDelegate
- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onAmountChanged:(NSDecimalNumber*)newValue
{
    [self onAmountChanged:newValue];
}

- (void)textFieldAmount:(ViewTextFieldAmountCell*)sheet onTailerClicked:(UIButton*)sender
{
    [_tf_amount setInputTextValue:[OrgUtils formatFloatValue:_nCurrBalance usesGroupingSeparator:NO]];
    [self onAmountChanged:nil];
}

/**
 *  (private) 划转数量发生变化。
 */
- (void)onAmountChanged:(NSDecimalNumber*)newValue
{
    if (!newValue) {
        newValue = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    }
    [self _drawUI_Balance:[_nCurrBalance compare:newValue] < 0];
}

@end
