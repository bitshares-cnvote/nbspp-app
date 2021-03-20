//
//  VCBotsCreate.m
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCBotsCreate.h"
#import "VCBotsManager.h"

#import "ViewTipsInfoCell.h"
#import "OrgUtils.h"

#import "VCSearchNetwork.h"

enum
{
    kVcSubMinPrice = 0,         //  网格价格下限
    kVcSubMaxPrice,             //  网格价格上限
    kVcSubGridN,                //  网格数量
    kVcSubAmount,               //  每格交易数量
    kVcSubQuoteAsset,           //  交易资产
    kVcSubBaseAsset,            //  报价资产
    
    kVcSubSubmitButton,         //  创建按钮
    kVcSubUiTipMessage,         //  UI温馨提示信息
};

@interface VCBotsCreate ()
{
    WsPromiseObject*        _result_promise;
    
    UITableView*            _mainTableView;
    NSArray*                _dataArray;
    
    ViewTipsInfoCell*       _cell_tips;
    ViewBlockLabel*         _lbCommit;
    
    NSMutableDictionary*    _op_data;
}

@end

@implementation VCBotsCreate

- (void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _lbCommit = nil;
    _cell_tips = nil;
    _result_promise = nil;
}

- (id)initWithResultPromise:(WsPromiseObject*)result_promise
{
    self = [super init];
    if (self){
        assert([[WalletManager sharedWalletManager] isWalletExist]);
        _result_promise = result_promise;
        _dataArray = [NSMutableArray array];
        _op_data = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  TODO:lang
    NSArray* pSection1 = @[
        @{@"type":@(kVcSubMinPrice), @"name":@"最低价格"},
        @{@"type":@(kVcSubMaxPrice), @"name":@"最高价格"},
    ];
    
    NSArray* pSection2 = @[
        @{@"type":@(kVcSubGridN), @"name":@"网格数量"},
        @{@"type":@(kVcSubAmount), @"name":@"每格交易数量"},
    ];
    
    NSArray* pSection3 = @[
        @{@"type":@(kVcSubQuoteAsset), @"name":@"交易资产"},
        @{@"type":@(kVcSubBaseAsset), @"name":@"报价资产"},
    ];
    
    NSArray* pSection4 = @[
        @{@"type":@(kVcSubSubmitButton), @"name":@""},
    ];
    
    NSArray* pSection5 = @[
        @{@"type":@(kVcSubUiTipMessage), @"name":@""},
    ];
    
    _dataArray = @[pSection1, pSection2, pSection3, pSection4, pSection5];
    
    _mainTableView = [[UITableView alloc] initWithFrame:[self rectWithoutNavi] style:UITableViewStyleGrouped];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_mainTableView];
    
    //  UI - 提示信息
    _cell_tips = [[ViewTipsInfoCell alloc] initWithText:@"【温馨提示】\n设置网格量化订单参数。"];
    _cell_tips.hideBottomLine = YES;
    _cell_tips.hideTopLine = YES;
    _cell_tips.backgroundColor = [UIColor clearColor];
    
    //  UI - 创建按钮
    _lbCommit = [self createCellLableButton:@"创建"];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row_type = [[[[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] objectForKey:@"type"] integerValue];
    if (row_type == kVcSubUiTipMessage) {
        return [_cell_tips calcCellDynamicHeight:tableView.layoutMargins.left];
    }
    return tableView.rowHeight;
}

/**
 *  调整Header和Footer高度。REMARK：header和footer VIEW 不能为空，否则高度设置无效。
 */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 15.0f;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    NSInteger row_type = [[item objectForKey:@"type"] integerValue];
    
    switch (row_type) {
        case kVcSubSubmitButton:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            [self addLabelButtonToCell:_lbCommit cell:cell leftEdge:tableView.layoutMargins.left];
            return cell;
        }
            break;
        case kVcSubUiTipMessage:
        {
            return _cell_tips;
        }
            break;
        default:
        {
            UITableViewCellBase* cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundColor = [UIColor clearColor];
            
            cell.showCustomBottomLine = YES;
            
            cell.textLabel.text = [item objectForKey:@"name"];
            cell.textLabel.textColor = [ThemeManager sharedThemeManager].textColorMain;
            cell.imageView.tintColor = [ThemeManager sharedThemeManager].textColorNormal;
            
            switch (row_type) {
                case kVcSubMinPrice:
                {
                    id min_price = [_op_data objectForKey:@"min_price"];
                    if (min_price) {
                        id n_min_price = [NSDecimalNumber decimalNumberWithMantissa:[min_price integerValue] exponent:-8 isNegative:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", n_min_price];
                    } else {
                        cell.detailTextLabel.text = @"请输入最低价格";
                    }
                }
                    break;
                case kVcSubMaxPrice:
                {
                    id max_price = [_op_data objectForKey:@"max_price"];
                    if (max_price) {
                        id n_max_price = [NSDecimalNumber decimalNumberWithMantissa:[max_price integerValue] exponent:-8 isNegative:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", n_max_price];
                    } else {
                        cell.detailTextLabel.text = @"请输入最低价格";
                    }
                }
                    break;
                case kVcSubGridN:
                {
                    id grid_n = [_op_data objectForKey:@"grid_n"];
                    if (grid_n) {
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", @([grid_n integerValue])];
                    } else {
                        cell.detailTextLabel.text = @"请输入网格数量";
                    }
                }
                    break;
                case kVcSubAmount:
                {
                    id order_amount = [_op_data objectForKey:@"order_amount"];
                    if (order_amount) {
                        id quote = [_op_data objectForKey:@"quote"];
                        assert(quote);
                        NSInteger precision = [[quote objectForKey:@"precision"] integerValue];
                        id n_order_amount = [NSDecimalNumber decimalNumberWithMantissa:[order_amount integerValue] exponent:-precision isNegative:NO];
                        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", n_order_amount];
                    } else {
                        cell.detailTextLabel.text = @"请输入每格交易数量";
                    }
                }
                    break;
                case kVcSubQuoteAsset:
                {
                    id quote = [_op_data objectForKey:@"quote"];
                    if (quote) {
                        cell.detailTextLabel.text = [quote objectForKey:@"symbol"];
                    } else {
                        cell.detailTextLabel.text = @"请选择交易资产";
                    }
                }
                    break;;
                case kVcSubBaseAsset:
                {
                    id base = [_op_data objectForKey:@"base"];
                    if (base) {
                        cell.detailTextLabel.text = [base objectForKey:@"symbol"];
                    } else {
                        cell.detailTextLabel.text = @"请选择报价资产";
                    }
                }
                    break;
                default:
                    break;
            }
            
            return cell;
        }
            break;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        
        id item = [[_dataArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        
        //  TODO:lang
        switch ([[item objectForKey:@"type"] integerValue]) {
            case kVcSubMinPrice:
            {
                [VcUtils showInputDecimalClicked:@"最低价格"
                                     placeholder:@"请输入最低价格"
                                       precision:8
                                       min_value:nil
                                       max_value:nil
                                           scale:[[NSDecimalNumber one] decimalNumberByMultiplyingByPowerOf10:8]
                                        callback:^(NSDecimalNumber *n_value) {
                    [_op_data setObject:n_value forKey:@"min_price"];
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcSubMaxPrice:
            {
                [VcUtils showInputDecimalClicked:@"最高价格"
                                     placeholder:@"请输入最高价格"
                                       precision:8
                                       min_value:nil
                                       max_value:nil
                                           scale:[[NSDecimalNumber one] decimalNumberByMultiplyingByPowerOf10:8]
                                        callback:^(NSDecimalNumber *n_value) {
                    [_op_data setObject:n_value forKey:@"max_price"];
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcSubGridN:
            {
                [VcUtils showInputDecimalClicked:@"网格数量"
                                     placeholder:@"请输入网格数量 2 ~ 99"
                                       precision:0
                                       min_value:[NSDecimalNumber decimalNumberWithMantissa:2 exponent:0 isNegative:NO]
                                       max_value:[NSDecimalNumber decimalNumberWithMantissa:99 exponent:0 isNegative:NO]
                                           scale:nil
                                        callback:^(NSDecimalNumber *n_value) {
                    [_op_data setObject:n_value forKey:@"grid_n"];
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcSubAmount:
            {
                id quote = [_op_data objectForKey:@"quote"];
                if (!quote) {
                    [OrgUtils makeToast:@"请先选择交易资产。"];
                    return;
                }
                NSInteger precision = [[quote objectForKey:@"precision"] integerValue];
                [VcUtils showInputDecimalClicked:@"每格交易数量"
                                     placeholder:@"请输入每格交易数量"
                                       precision:precision
                                       min_value:nil
                                       max_value:nil
                                           scale:[[NSDecimalNumber one] decimalNumberByMultiplyingByPowerOf10:precision]
                                        callback:^(NSDecimalNumber *n_value) {
                    [_op_data setObject:n_value forKey:@"order_amount"];
                    [_mainTableView reloadData];
                }];
            }
                break;
            case kVcSubQuoteAsset:
            {
                VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
                    if (asset_info){
                        id old_quote = [_op_data objectForKey:@"quote"];
                        if (old_quote && ![old_quote[@"id"] isEqualToString:asset_info[@"id"]]) {
                            [_op_data removeObjectForKey:@"order_amount"];
                        }
                        [_op_data setObject:asset_info forKey:@"quote"];
                        [_mainTableView reloadData];
                    }
                }];
                [self pushViewController:vc
                                 vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubBaseAsset:
            {
                VCSearchNetwork* vc = [[VCSearchNetwork alloc] initWithSearchType:enstAssetAll callback:^(id asset_info) {
                    if (asset_info){
                        [_op_data setObject:asset_info forKey:@"base"];
                        [_mainTableView reloadData];
                    }
                }];
                [self pushViewController:vc
                                 vctitle:NSLocalizedString(@"kVcTitleSearchAssets", @"搜索资产")
                               backtitle:kVcDefaultBackTitleName];
            }
                break;
            case kVcSubSubmitButton:
                [self onSubmitClicked];
                break;
            default:
                break;
        }
        
    }];
}

- (void)onSubmitClicked
{
    //  检查参数有效性
    id base = [_op_data objectForKey:@"base"];
    if (!base) {
        [OrgUtils makeToast:@"请选择报价资产。"];
        return;
    }
    
    id quote = [_op_data objectForKey:@"quote"];
    if (!quote) {
        [OrgUtils makeToast:@"请选择交易资产。"];
        return;
    }
    
    id base_id = [base objectForKey:@"id"];
    id quote_id = [quote objectForKey:@"id"];
    if ([base_id isEqualToString:quote_id]) {
        [OrgUtils makeToast:@"交易资产和报价资产不能相同。"];
        return;
    }
    
    id grid_n = [_op_data objectForKey:@"grid_n"];
    if (!grid_n) {
        [OrgUtils makeToast:@"请设置网格数量。"];
        return;
    }
    NSInteger i_grid_n = [grid_n integerValue];
    if (i_grid_n < 2 || i_grid_n > 99) {
        [OrgUtils makeToast:@"网格数量的有效范围 2 ~ 99。"];
        return;
    }
    
    id order_amount = [_op_data objectForKey:@"order_amount"];
    if (!order_amount) {
        [OrgUtils makeToast:@"请设置每格交易数量。"];
        return;
    }
    id n_order_amount = [NSDecimalNumber decimalNumberWithMantissa:[order_amount unsignedLongLongValue]
                                                          exponent:-[[quote objectForKey:@"precision"] integerValue]
                                                        isNegative:NO];
    if ([n_order_amount compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"请设置每格交易数量。"];
        return;
    }
    
    id n_min_price = nil;
    id min_price = [_op_data objectForKey:@"min_price"];
    if (min_price) {
        n_min_price = [NSDecimalNumber decimalNumberWithMantissa:[min_price unsignedLongLongValue] exponent:-8 isNegative:NO];
    }
    if (!n_min_price || [n_min_price compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"请设置最低价格。"];
        return;
    }
    
    id n_max_price = nil;
    id max_price = [_op_data objectForKey:@"max_price"];
    if (max_price) {
        n_max_price = [NSDecimalNumber decimalNumberWithMantissa:[max_price unsignedLongLongValue] exponent:-8 isNegative:NO];
    }
    if (!n_max_price || [n_max_price compare:[NSDecimalNumber zero]] <= 0) {
        [OrgUtils makeToast:@"请设置最高价格。"];
        return;
    }
    if ([n_max_price compare:n_min_price] <= 0) {
        [OrgUtils makeToast:@"请重新设置最低价格或最高价格的值。"];
        return;
    }
    
    [self GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked) {
            //  准备创建机器人
            id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            
            id init_bots_data = @{
                @"args": @{
                        @"grid_n": @(i_grid_n),
                        @"min_price": min_price,
                        @"max_price": max_price,
                        @"order_amount": order_amount,
                        @"base": base_id,
                        @"quote": quote_id,
                },
                @"status": @"created",
            };
            //  TODO:catalog
            id bots_key = [VCBotsManager calcBotsKey:init_bots_data[@"args"] catalog:kAppStorageCatalogBotsGridBots account:op_account_id];
            id key_values = @[@[bots_key, [init_bots_data to_json]]];
            
            ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
            [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            id p1 = [chainMgr queryAccountAllBotsData:op_account_id];
            id p2 = [chainMgr queryAllGrapheneObjectsSkipCache:@[op_account_id]];
            [[[WsPromise all:@[p1, p2]] then:^id(id data_array) {
                id result_hash = [data_array objectAtIndex:0];
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (latest_storage_item) {
                    [self hideBlockView];
                    [OrgUtils makeToast:@"已经存在相同参数的机器人，请调整参数后再试。"];
                    //  刷新界面
                    return nil;
                }
                
                //  TODO:授权判断在 后续放到 创建之前，提醒用户。确认。
                
                return [[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:op_account_id
                                                                                          remove:NO
                                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                                      key_values:key_values] then:^id(id data) {
                    [self hideBlockView];
                    //  TODO:lang
                    [OrgUtils makeToast:@"创建成功。"];
                    //  返回上一个界面并刷新
                    if (_result_promise) {
                        [_result_promise resolve:@YES];
                    }
                    [self closeOrPopViewController];
                    return nil;
                }];
            }] catch:^id(id error) {
                [self hideBlockView];
                [OrgUtils showGrapheneError:error];
                return nil;
            }];
        }
    }];
    
}

@end
