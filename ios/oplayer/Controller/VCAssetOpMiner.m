//
//  VCAssetOpMiner.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCAssetOpMiner.h"
#import "VCSearchNetwork.h"
#import "ViewTipsInfoCell.h"

enum
{
    kVcSecAmount = 0,       //  数量
    kVcSecSubmit,           //  提交按钮
    kVcSecTips,             //  提示信息
    
    kvcSecMax
};

@interface VCAssetOpMiner ()
{
    WsPromiseObject*            _result_promise;
    
    NSDictionary*               _miner_item;
    
    NSDictionary*               _curr_receive_asset;    //  获得资产
    NSDictionary*               _curr_balance_asset;    //  支出资产
    NSDictionary*               _full_account_data;
    NSDecimalNumber*            _nCurrBalance;
    
    UITableViewBase*            _mainTableView;
    ViewTextFieldAmountCell*    _tf_amount;
    
    ViewTipsInfoCell*           _cell_tips;
    ViewBlockLabel*             _lbCommit;
}

@end

@implementation VCAssetOpMiner

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

- (id)initWithMinerItem:(id)miner_item
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self) {
        assert(miner_item);
        assert(full_account_data);
        _result_promise = result_promise;
        _miner_item = miner_item;
        _full_account_data = full_account_data;
        
        ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
        id price = [_miner_item objectForKey:@"price"];
        id amount_to_sell = [price objectForKey:@"amount_to_sell"];
        id min_to_receive = [price objectForKey:@"min_to_receive"];
        _curr_balance_asset = [chainMgr getChainObjectByID:[amount_to_sell objectForKey:@"asset_id"]];
        _curr_receive_asset = [chainMgr getChainObjectByID:[min_to_receive objectForKey:@"asset_id"]];
        assert(_curr_balance_asset);
        assert(_curr_receive_asset);
        
        [self _auxGenCurrBalanceAndBalanceAsset];
    }
    return self;
}

- (void)refreshView
{
    [_mainTableView reloadData];
}

/*
 *  (private) 生成当前余额 以及 余额对应的资产。
 */
- (void)_auxGenCurrBalanceAndBalanceAsset
{
    _nCurrBalance = [ModelUtils findAssetBalance:_full_account_data asset:_curr_balance_asset];
}

- (void)_drawUI_Balance:(BOOL)not_enough
{
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    NSString* symbol = [_curr_balance_asset objectForKey:@"symbol"];
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
    id price = [_miner_item objectForKey:@"price"];
    id amount_to_sell = [price objectForKey:@"amount_to_sell"];
    id min_to_receive = [price objectForKey:@"min_to_receive"];
    
    id n_amount_to_sell = [NSDecimalNumber decimalNumberWithMantissa:[[amount_to_sell objectForKey:@"amount"] unsignedLongValue]
                                                            exponent:-[[_curr_balance_asset objectForKey:@"precision"] integerValue]
                                                          isNegative:NO];
    
    id n_min_to_receive = [NSDecimalNumber decimalNumberWithMantissa:[[min_to_receive objectForKey:@"amount"] unsignedLongValue]
                                                            exponent:-[[_curr_receive_asset objectForKey:@"precision"] integerValue]
                                                          isNegative:NO];
    
    id n_unit_price = [n_min_to_receive decimalNumberByDividingBy:n_amount_to_sell];
    
    return [NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpMinerUiTips", @"【温馨提示】\n1、根据 1:%@ 比例快速兑换 %@ 资产，如果市场深度不足则会兑换失败。\n2、根据市场情况可能存在少许误差。"),
            n_unit_price, _curr_receive_asset[@"symbol"]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    self.view.backgroundColor = theme.appBackColor;
    
    //  UI - 数量输入框
    _tf_amount = [[ViewTextFieldAmountCell alloc] initWithTitle:NSLocalizedString(@"kOtcMcAssetTransferCellLabelAmount", @"数量")
                                                    placeholder:NSLocalizedString(@"kVcAssetOpMinerCellPlaceholderAmount", @"请输入兑换数量")
                                                         tailer:[_curr_balance_asset objectForKey:@"symbol"]];
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
    
    //  UI - 兑换按钮
    _lbCommit = [self createCellLableButton:[NSString stringWithFormat:NSLocalizedString(@"kVcAssetOpMinerBtnName", @"%@ 兑换 %@"),
                                             _curr_balance_asset[@"symbol"],
                                             _curr_receive_asset[@"symbol"]]];
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
                                     precision:[[_curr_balance_asset objectForKey:@"precision"] integerValue]];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kvcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
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
        case kVcSecAmount:
            return _tf_amount;
            
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
            case kVcSecSubmit:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
    }];
}

- (void)onSubmitClicked
{
    id n_amount = [OrgUtils auxGetStringDecimalNumberValue:[_tf_amount getInputTextValue]];
    
    NSDecimalNumber* n_zero = [NSDecimalNumber zero];
    if ([n_amount compare:n_zero] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpMinerSubmitTipsPleaseInputValidAmount", @"请输入有效的兑换数量。")];
        return;
    }
    
    if ([_nCurrBalance compare:n_amount] < 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kOtcMcAssetSubmitTipBalanceNotEnough", @"余额不足。")];
        return;
    }
    
    //  计算得到的数量
    NSInteger curr_receive_asset_precision = [[_curr_receive_asset objectForKey:@"precision"] integerValue];
    id price = [_miner_item objectForKey:@"price"];
    id amount_to_sell = [price objectForKey:@"amount_to_sell"];
    id min_to_receive = [price objectForKey:@"min_to_receive"];
    id n_amount_to_sell = [NSDecimalNumber decimalNumberWithMantissa:[[amount_to_sell objectForKey:@"amount"] unsignedLongValue]
                                                            exponent:-[[_curr_balance_asset objectForKey:@"precision"] integerValue]
                                                          isNegative:NO];
    id n_min_to_receive = [NSDecimalNumber decimalNumberWithMantissa:[[min_to_receive objectForKey:@"amount"] unsignedLongValue]
                                                            exponent:-curr_receive_asset_precision
                                                          isNegative:NO];
    id n_final_receive = [[n_min_to_receive decimalNumberByMultiplyingBy:n_amount] decimalNumberByDividingBy:n_amount_to_sell
                                                                                                withBehavior:[ModelUtils decimalHandlerRoundDown:curr_receive_asset_precision]];
    if ([n_final_receive compare:n_zero] <= 0) {
        [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpMinerSubmitTipsPleaseInputValidAmount", @"请输入有效的兑换数量。")];
        return;
    }
    
    [self GuardWalletUnlocked:NO body:^(BOOL unlocked) {
        if (unlocked) {
            [self _execAssetMinerCore:n_amount n_receive:n_final_receive];
        }
    }];
}

/*
 *  (private) 执行快速兑换操作
 */
- (void)_execAssetMinerCore:(NSDecimalNumber*)n_amount n_receive:(NSDecimalNumber*)n_receive
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id op_account = [_full_account_data objectForKey:@"account"];
    assert(op_account);
    
    //  根据兑换数量计算得到数量。
    id n_amount_pow = [NSString stringWithFormat:@"%@", [n_amount decimalNumberByMultiplyingByPowerOf10:[_curr_balance_asset[@"precision"] integerValue]]];
    id n_receive_pow = [NSString stringWithFormat:@"%@", [n_receive decimalNumberByMultiplyingByPowerOf10:[_curr_receive_asset[@"precision"] integerValue]]];
    
    NSTimeInterval now_sec = ceil([[NSDate date] timeIntervalSince1970]);
    uint32_t expiration_ts = (uint32_t)(now_sec + 64281600);    //  两年后：64281600 = 3600*24*31*12*2
    
    id op = @{
        @"fee":@{
                @"amount":@0,
                @"asset_id":chainMgr.grapheneCoreAssetID, //  手续费资产ID
        },
        @"seller":op_account[@"id"],                      //  买卖帐号
        @"amount_to_sell":@{@"asset_id":_curr_balance_asset[@"id"], @"amount":n_amount_pow},
        @"min_to_receive":@{@"asset_id":_curr_receive_asset[@"id"], @"amount":n_receive_pow},
        @"expiration":@(expiration_ts),                   //  订单过期日期时间戳
        @"fill_or_kill":@YES,
    };
    
    //  确保有权限发起普通交易，否则作为提案交易处理。
    [self GuardProposalOrNormalTransaction:ebo_limit_order_create
                     using_owner_authority:NO
                  invoke_proposal_callback:NO
                                    opdata:op
                                 opaccount:op_account
                                      body:^(BOOL isProposal, NSDictionary *proposal_create_args)
     {
        assert(!isProposal);
        [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
        [[[[BitsharesClientManager sharedBitsharesClientManager] createLimitOrder:op] then:(^id(id data) {
            [self hideBlockView];
            //  UI提示
            [OrgUtils makeToast:NSLocalizedString(@"kVcAssetOpMinerSubmitTipSwapOK", @"兑换成功。")];
            //  [统计]
            [OrgUtils logEvents:@"txAssetMinerFullOK" params:@{@"account":op_account[@"id"]}];
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
            [OrgUtils logEvents:@"txAssetMinerFailed" params:@{@"account":op_account[@"id"]}];
            return nil;
        })];
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
