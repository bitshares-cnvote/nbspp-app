//
//  VCBotsManager.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBotsManager.h"
#import "ViewBotsGridInfoCell.h"

/*
 *  机器人账号授权状态操作枚举
 */
enum
{
    kBotsAuthorizationStatus_AlreadyAuthorized = 0,
    kBotsAuthorizationStatus_ContinueToAuthorize,
    kBotsAuthorizationStatus_StopAuthorization,
};

@interface VCBotsManager ()
{
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    NSDictionary*           _fullAccountData;
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    NSMutableDictionary*    _dataTickerHash;
    NSMutableDictionary*    _dataBalanceHash;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCBotsManager

-(void)dealloc
{
    _owner = nil;
    _fullAccountData = nil;
    _dataArray = nil;
    _dataTickerHash = nil;
    _dataBalanceHash = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithOwner:(VCBase*)owner fullAccountData:(id)fullAccountData
{
    self = [super init];
    if (self) {
        assert(owner);
        assert(fullAccountData);
        _owner = owner;
        _fullAccountData = fullAccountData;
        _dataArray = [NSMutableArray array];
        _dataTickerHash = [NSMutableDictionary dictionary];
        _dataBalanceHash = [NSMutableDictionary dictionary];
    }
    return self;
}

/*
 *  (public) 计算机器人的 bots_key。
 */
+ (NSString*)calcBotsKey:(id)bots_args catalog:(NSString*)catalog account:(NSString*)account_id
{
    id mutable_args = [bots_args mutableCopy];
    [mutable_args setObject:account_id forKey:@"__bots_owner"];
    [mutable_args setObject:catalog forKey:@"__bots_type"];
    id sorted_keys = [[mutable_args allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    id sign_str = [[sorted_keys ruby_map:^id(id arg_key) {
        return [NSString stringWithFormat:@"%@=%@", arg_key, [mutable_args objectForKey:arg_key]];  //  TODO:uri encode
    }] componentsJoinedByString:@"&"];
    return [OrgUtils md5:sign_str];
}

/*
 *  (public) 是否已授权服务器端处理量化交易判断。
 */
+ (BOOL)isAuthorizedToTheBotsManager:(id)latest_account_data
{
    assert(latest_account_data);
    id active_permission = [latest_account_data objectForKey:@"active"];
    assert(active_permission);
    
    id const_bots_account_id = [[SettingManager sharedSettingManager] getAppGridBotsTraderAccount];
    
    NSInteger weight_threshold = [[active_permission objectForKey:@"weight_threshold"] integerValue];
    for (id item in [active_permission objectForKey:@"account_auths"]) {
        id account = [item firstObject];
        if (![const_bots_account_id isEqualToString:account]) {
            continue;
        }
        NSInteger weight = [[item lastObject] integerValue];
        if (weight >= weight_threshold) {
            return YES;
        }
    }
    return NO;
}

/*
 *  (private) 是否是有效的机器人策略数据判断。
 */
- (BOOL)isValidBotsData:(id)storage_item
{
    if (!storage_item) {
        return NO;
    }
    
    id bots_key = [storage_item objectForKey:@"key"];
    if (!bots_key) {
        return NO;
    }
    
    id value = [storage_item objectForKey:@"value"];
    if (!value || ![value isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    //  验证基本参数
    id args = [value objectForKey:@"args"];
    if (!args || ![args isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    if (![args objectForKey:@"grid_n"] ||
        ![args objectForKey:@"min_price"] ||
        ![args objectForKey:@"max_price"] ||
        ![args objectForKey:@"order_amount"] ||
        ![args objectForKey:@"base"] ||
        ![args objectForKey:@"quote"]) {
        return NO;
    }
    
    if ([[args objectForKey:@"base"] isEqualToString:[args objectForKey:@"quote"]]) {
        return NO;
    }
    
    //  验证 bots_key。
    id calcd_bots_key = [[self class] calcBotsKey:args catalog:[storage_item objectForKey:@"catalog"] account:[storage_item objectForKey:@"account"]];
    if (![calcd_bots_key isEqualToString:bots_key]) {
        return NO;
    }
    
    return YES;
}

- (void)onQueryMyBotsListResponsed:(id)data_container
{
    [self onQueryMyBotsListResponsed:data_container ticker_data_array:nil balance_array:nil limit_orders:nil];
}

- (void)onQueryMyBotsListResponsed:(id)data_container
                 ticker_data_array:(id)ticker_data_array
                     balance_array:(id)balance_array
                      limit_orders:(id)limit_orders
{
    [_dataArray removeAllObjects];
    
    //  处理数据
    if (data_container) {
        id data_array = nil;
        if ([data_container isKindOfClass:[NSArray class]]) {
            data_array = data_container;
        } else if ([data_container isKindOfClass:[NSDictionary class]]) {
            data_array = [data_container allValues];
        }
        if (data_array) {
            for (id storage_item in data_array) {
                BOOL valid = [self isValidBotsData:storage_item];
                
                id value = [storage_item objectForKey:@"value"];
                id status = [value objectForKey:@"status"];
                id tipmsg = @"";
                if (valid && status) {
                    if ([status isEqualToString:@"running"]) {
                        NSInteger i_init_time = [[[value objectForKey:@"ext"] objectForKey:@"init_time"] integerValue];
                        if (i_init_time > 0) {
                            NSInteger now_ts = (NSInteger)[[NSDate date] timeIntervalSince1970];
                            NSInteger run_ts = MAX(now_ts - i_init_time, 1);  //  REMARK：有可能有时间误差，默认最低取值1秒。
                            NSInteger run_days = run_ts / 86400;
                            NSInteger run_hours = run_ts % 86400 / 3600;
                            NSInteger run_mins = run_ts % 86400 % 3600 / 60;
                            NSInteger run_secs = run_ts % 86400 % 3600 % 60;
                            if (run_days > 0) {
                                tipmsg = [NSString stringWithFormat:NSLocalizedString(@"kBotsCellLabelMsgRunTimeDHMS", @"已运行 %@ 天 %@ 小时 %@ 分 %@ 秒"), @(run_days), @(run_hours), @(run_mins), @(run_secs)];
                            } else if (run_hours > 0) {
                                tipmsg = [NSString stringWithFormat:NSLocalizedString(@"kBotsCellLabelMsgRunTimeHMS", @"已运行 %@ 小时 %@ 分 %@ 秒"), @(run_hours), @(run_mins), @(run_secs)];
                            } else if (run_mins > 0) {
                                tipmsg = [NSString stringWithFormat:NSLocalizedString(@"kBotsCellLabelMsgRunTimeMS", @"已运行 %@ 分 %@ 秒"), @(run_mins), @(run_secs)];
                            } else {
                                tipmsg = [NSString stringWithFormat:NSLocalizedString(@"kBotsCellLabelMsgRunTimeS", @"已运行 %@ 秒"), @(run_secs)];
                            }
                        }
                    } else if ([status isEqualToString:@"created"]) {
                        //  刚创建，不显示提示信息。
                    } else {
                        tipmsg = [value objectForKey:@"msg"] ?: @"";
                    }
                } else {
                    tipmsg = NSLocalizedString(@"kBotsCellLabelMsgInvalidGrid", @"该网格订单已失效");
                }
                
                [_dataArray addObject:@{
                    @"valid":@(valid),
                    @"raw":storage_item,
                    @"tipmsg":tipmsg
                }];
            }
        }
    }
    
    //  ticker数据，估值用。
    if (ticker_data_array) {
        for (id ticker_data in ticker_data_array) {
            id pair_key = [NSString stringWithFormat:@"%@_%@", [ticker_data objectForKey:@"base"], [ticker_data objectForKey:@"quote"]];
            [_dataTickerHash setObject:ticker_data forKey:pair_key];
        }
    }
    
    //  统计余额数据，估值用。
    if (balance_array) {
        for (id balance in balance_array) {
            [_dataBalanceHash setObject:[balance objectForKey:@"amount"] forKey:balance[@"asset_id"]];
        }
    }
    if (limit_orders) {
        for (id orders in limit_orders) {
            id for_sale = [orders objectForKey:@"for_sale"];
            id sell_asset_id = [[[orders objectForKey:@"sell_price"] objectForKey:@"base"] objectForKey:@"asset_id"];
            id curr_balance = [_dataBalanceHash objectForKey:sell_asset_id];
            if (curr_balance) {
                [_dataBalanceHash setObject:@([curr_balance unsignedLongLongValue] + [for_sale unsignedLongLongValue])
                                     forKey:sell_asset_id];
            } else {
                [_dataBalanceHash setObject:for_sale
                                     forKey:sell_asset_id];
            }
        }
    }
    
    //  根据ID降序排列
    if ([_dataArray count] > 0){
        [_dataArray sortUsingComparator:(^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSInteger id1 = [[[[[obj1 objectForKey:@"raw"] objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            NSInteger id2 = [[[[[obj2 objectForKey:@"raw"] objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject] integerValue];
            return id2 - id1;
        })];
    }
    
    //  刷新UI
    [self refreshView];
}

- (void)refreshView
{
    _mainTableView.hidden = [_dataArray count] <= 0;
    _lbEmpty.hidden = !_mainTableView.hidden;
    if (!_mainTableView.hidden){
        [_mainTableView reloadData];
    }
}

- (void)queryMyBotsList
{
    id op_account = [_fullAccountData objectForKey:@"account"];
    id account_name = [op_account objectForKey:@"name"];
    assert(account_name);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    id p1 = [chainMgr queryFullAccountInfo:account_name];
    id p2 = [chainMgr queryAccountStorageInfo:account_name catalog:kAppStorageCatalogBotsGridBots];
    
    [[[WsPromise all:@[p1, p2]] then:^id(id data) {
        //  更新账号信息（权限等）
        _fullAccountData = [data objectAtIndex:0];
        
        id data_array = [data objectAtIndex:1];
        GrapheneApi* api = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_db;
        
        NSMutableDictionary* pair_promise_hash = [NSMutableDictionary dictionary];
        NSMutableDictionary* asset_ids = [NSMutableDictionary dictionary];
        if (data_array && [data_array isKindOfClass:[NSArray class]]) {
            for (id storage_item in data_array) {
                id value = [storage_item objectForKey:@"value"];
                if (value && [value isKindOfClass:[NSDictionary class]]) {
                    id args = [value objectForKey:@"args"];
                    if (args && [args isKindOfClass:[NSDictionary class]]) {
                        id base = [args objectForKey:@"base"];
                        id quote = [args objectForKey:@"quote"];
                        if (base && ![base isEqualToString:@""]) {
                            [asset_ids setObject:@YES forKey:base];
                        }
                        if (quote && ![quote isEqualToString:@""]) {
                            [asset_ids setObject:@YES forKey:quote];
                        }
                        if (base && quote) {
                            //  相同交易对只查询1次
                            id pair_key = [NSString stringWithFormat:@"%@_%@", base, quote];
                            if (![pair_promise_hash objectForKey:pair_key]) {
                                [pair_promise_hash setObject:[api exec:@"get_ticker" params:@[base, quote]] forKey:pair_key];
                            }
                        }
                    }
                }
            }
        }
        
        id asset_id_array = [asset_ids allKeys];
        id p1 = [WsPromise all:[pair_promise_hash allValues]];
        id p2 = [chainMgr queryAllGrapheneObjects:asset_id_array];
        id p3 = [chainMgr queryAccountBalance:op_account[@"id"] assets:asset_id_array];
        id p4 = [api exec:@"get_limit_orders_by_account" params:@[op_account[@"id"]]];
        return [[WsPromise all:@[p1, p2, p3, p4]] then:^id(id data) {
            [self onQueryMyBotsListResponsed:data_array
                           ticker_data_array:[data objectAtIndex:0]
                               balance_array:[data objectAtIndex:2]
                                limit_orders:[data objectAtIndex:3]];
            [_owner hideBlockView];
            return nil;
        }];
    }] catch:^id(id error) {
        [_owner hideBlockView];
        [OrgUtils showGrapheneError:error];
        return nil;
    }];
}

/*
 *  事件 - 页VC切换。
 */
- (void)onControllerPageChanged
{
    [self queryMyBotsList];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    //  UI - 列表
    CGRect rect = [self rectWithoutNavi];
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    _mainTableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_mainTableView];
    _mainTableView.hidden = NO;
    
    //  UI - 空
    _lbEmpty = [self genCenterEmptyLabel:rect txt:NSLocalizedString(@"kBotsNoAnyGridBots", @"网格交易订单为空，点击右上角创建网格交易。")];
    _lbEmpty.hidden = YES;
    [self.view addSubview:_lbEmpty];
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
    CGFloat baseHeight = 8.0 + 28 + 24 * 4;
    
    id item = [_dataArray objectAtIndex:indexPath.row];
    id tipmsg = [item objectForKey:@"tipmsg"];
    if (tipmsg && ![tipmsg isEqualToString:@""]) {
        baseHeight += 24.0f;
    }
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ViewBotsGridInfoCell* cell = [[ViewBotsGridInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.showCustomBottomLine = YES;
    cell.ticker_data_hash = _dataTickerHash;
    cell.balance_hash = _dataBalanceHash;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[IntervalManager sharedIntervalManager] callBodyWithFixedInterval:tableView body:^{
        [self _onCellClicked:[_dataArray objectAtIndex:indexPath.row]];
    }];
}

- (void)_onCellClicked:(id)bots
{
    assert(bots);
    
    id list = [[[NSMutableArray array] ruby_apply:^(id ary) {
        [ary addObject:@{@"type":@(0), @"title":NSLocalizedString(@"kBotsActionStart", @"启动网格交易")}];
        [ary addObject:@{@"type":@(1), @"title":NSLocalizedString(@"kBotsActionStop", @"停止网格交易")}];
        [ary addObject:@{@"type":@(2), @"title":NSLocalizedString(@"kBotsActionDelete", @"删除网格交易")}];
    }] copy];
    
    [[MyPopviewManager sharedMyPopviewManager] showActionSheet:self
                                                       message:nil
                                                        cancel:NSLocalizedString(@"kBtnCancel", @"取消")
                                                         items:list
                                                           key:@"title"
                                                      callback:^(NSInteger buttonIndex, NSInteger cancelIndex)
     {
        if (buttonIndex != cancelIndex){
            id item = [list objectAtIndex:buttonIndex];
            switch ([[item objectForKey:@"type"] integerValue]) {
                case 0:
                {
                    [[self processingAuthorizationServer] then:^id(id status) {
                        NSInteger authorizationStatus = [status integerValue];
                        switch (authorizationStatus) {
                            case kBotsAuthorizationStatus_AlreadyAuthorized:
                            case kBotsAuthorizationStatus_ContinueToAuthorize:
                                [self _startBots:bots authorizationStatus:authorizationStatus];
                                break;
                                //  停止授权，不继续启动。
                            case kBotsAuthorizationStatus_StopAuthorization:
                                break;
                            default:
                                break;
                        }
                        return nil;
                    }];
                }
                    break;
                case 1:
                    [self _stopBots:bots];
                    break;;
                case 2:
                    [self _deleteBots:bots];
                    break;;
                default:
                    break;
            }
        }
    }];
}

/*
 *  (private) 检测机器人账号授权状态
 */
- (WsPromise*)processingAuthorizationServer
{
    if ([[self class] isAuthorizedToTheBotsManager:[_fullAccountData objectForKey:@"account"]]) {
        //  已授权
        return [WsPromise resolve:@(kBotsAuthorizationStatus_AlreadyAuthorized)];
    } else {
        return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
            id value = NSLocalizedString(@"kBotsActionStartTipsForAutoAuthorize", @"网格交易需要授权服务器进行自动化操作，是否自动授权？");
            [[UIAlertViewManager sharedUIAlertViewManager] showCancelConfirm:value
                                                                   withTitle:NSLocalizedString(@"kVcHtlcMessageTipsTitle", @"风险提示")
                                                                  completion:^(NSInteger buttonIndex)
             {
                if (buttonIndex == 1)
                {
                    //  继续授权
                    resolve(@(kBotsAuthorizationStatus_ContinueToAuthorize));
                } else {
                    //  停止授权
                    resolve(@(kBotsAuthorizationStatus_StopAuthorization));
                }
            }];
        }];
    }
}

- (void)_startBots:(id)item authorizationStatus:(NSInteger)authorizationStatus
{
    assert(item);
    assert(authorizationStatus != kBotsAuthorizationStatus_StopAuthorization);
    
    //  步骤：查询 & 启动 & 转账
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    BitsharesClientManager* client = [BitsharesClientManager sharedBitsharesClientManager];
    
    //  不支持提案：多签账号不支持跑量化机器人，量化授权会失去多签账号的意义。
    [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked){
            id op_account = [_fullAccountData objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[chainMgr queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionErrTipsAlreadyDeleted", @"该网格交易已经删除了。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if ([self isValidBotsData:latest_storage_item] && status && [status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionErrTipsAlreadyStarted", @"网格交易已经在运行中。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                //  启动参数
                id new_bots_data = @{
                    @"args": [[latest_storage_item objectForKey:@"value"] objectForKey:@"args"],
                    @"status": @"running",
                };
                id key_values = @[@[bots_key, [new_bots_data to_json]]];
                
                return [[client buildAndRunTransaction:^(TransactionBuilder *builder) {
                    id const_bots_account_id = [[SettingManager sharedSettingManager] getAppGridBotsTraderAccount];
                    
                    //  OP - 授权服务器
                    if (authorizationStatus == kBotsAuthorizationStatus_ContinueToAuthorize) {
                        id new_active_permission = [[op_account objectForKey:@"active"] mutableCopy];
                        NSMutableArray* new_account_auths = [NSMutableArray array];
                        //  保留 account_auths 权限中的其他权限
                        for (id item in [new_active_permission objectForKey:@"account_auths"]) {
                            id account = [item firstObject];
                            if (![const_bots_account_id isEqualToString:account]) {
                                [new_account_auths addObject:item];
                            }
                        }
                        //  授权账号：权重 100%
                        [new_account_auths addObject:@[const_bots_account_id, [new_active_permission objectForKey:@"weight_threshold"]]];
                        //  仅更新 account_auths 权限，key_auths 等权限保持不变 。
                        [new_active_permission setObject:[new_account_auths copy] forKey:@"account_auths"];
                        
                        id opdata_bots_authority = @{
                            @"fee":@{
                                    @"amount":@0,
                                    @"asset_id":chainMgr.grapheneCoreAssetID,
                            },
                            @"account":op_account_id,
                            @"active":[new_active_permission copy],
                        };
                        [builder add_operation:ebo_account_update opdata:opdata_bots_authority];
                    }
                    
                    //  OP - 启动
                    [builder add_operation:ebo_custom
                                    opdata:[client buildOpData_accountStorageMap:op_account_id
                                                                          remove:NO
                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                      key_values:key_values]];
                    
                    //  OP - 转账
                    id opdata_transfer = @{
                        @"fee":@{
                                @"amount":@0,
                                @"asset_id":chainMgr.grapheneCoreAssetID,
                        },
                        @"from":op_account_id,
                        @"to":const_bots_account_id,
                        @"amount":@{
                                @"amount":@1,
                                @"asset_id":chainMgr.grapheneCoreAssetID,
                        }
                    };
                    [builder add_operation:ebo_transfer opdata:opdata_transfer];
                    
                    //  获取签名KEY
                    [builder addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:op_account_id
                                                                                       requireOwnerPermission:NO]];
                }] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionTipsStartOK", @"启动成功。")];
                    [self queryMyBotsList];
                    return nil;
                }];
            }] catch:^id(id error) {
                [_owner hideBlockView];
                [OrgUtils showGrapheneError:error];
                return nil;
            }];
        }
    }];
}

- (void)_stopBots:(id)item
{
    //  不支持提案：多签账号不支持跑量化机器人，量化授权会失去多签账号的意义。
    [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked){
            
            id op_account = [_fullAccountData objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[ChainObjectManager sharedChainObjectManager] queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionErrTipsAlreadyDeleted", @"该网格交易已经删除了。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if (![self isValidBotsData:latest_storage_item] || !status || ![status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionTipsStopOK", @"网格交易已停止。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                
                id mutable_latest_value = [[latest_storage_item objectForKey:@"value"] mutableCopy];
                [mutable_latest_value setObject:@"stopped" forKey:@"status"];
                [mutable_latest_value setObject:NSLocalizedString(@"kBotsCellLabelStopMessageUserStop", @"用户停止") forKey:@"msg"];
                
                id key_values = @[@[bots_key, [mutable_latest_value to_json]]];
                
                return [[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:op_account_id
                                                                                          remove:NO
                                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                                      key_values:key_values] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionTipsStopOK", @"网格交易已停止。")];
                    [self queryMyBotsList];
                    return nil;
                }];
                
            }] catch:^id(id error) {
                
                [_owner hideBlockView];
                [OrgUtils showGrapheneError:error];
                
                return nil;
            }];
        }
    }];
}

- (void)_deleteBots:(id)item
{
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    BitsharesClientManager* client = [BitsharesClientManager sharedBitsharesClientManager];
    
    //  不支持提案：多签账号不支持跑量化机器人，量化授权会失去多签账号的意义。
    [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked){
            
            
            id op_account = [_fullAccountData objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[chainMgr queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionErrTipsAlreadyDeleted", @"该网格交易已经删除了。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if ([self isValidBotsData:latest_storage_item] && status && [status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionErrTipsStopFirst", @"该网格交易正在运行中，请先停止。")];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id key_values = @[@[bots_key, [@{} to_json]]];
                
                return [[client buildAndRunTransaction:^(TransactionBuilder *builder) {
                    //  OP - 删除网格
                    [builder add_operation:ebo_custom
                                    opdata:[client buildOpData_accountStorageMap:op_account_id
                                                                          remove:YES
                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                      key_values:key_values]];
                    
                    //  OP - 取消授权  REMARK：删除最后一个网格，自动取消授权。
                    if ([_dataArray count] <= 1) {
                        id const_bots_account_id = [[SettingManager sharedSettingManager] getAppGridBotsTraderAccount];
                        id new_active_permission = [[op_account objectForKey:@"active"] mutableCopy];
                        NSMutableArray* new_account_auths = [NSMutableArray array];
                        //  保留 account_auths 权限中的其他权限，删除 bots trader 权限。
                        for (id item in [new_active_permission objectForKey:@"account_auths"]) {
                            id account = [item firstObject];
                            if (![const_bots_account_id isEqualToString:account]) {
                                [new_account_auths addObject:item];
                            }
                        }
                        //  仅更新 account_auths 权限，key_auths 等权限保持不变 。
                        [new_active_permission setObject:[new_account_auths copy] forKey:@"account_auths"];
                        
                        id opdata_bots_authority = @{
                            @"fee":@{
                                    @"amount":@0,
                                    @"asset_id":chainMgr.grapheneCoreAssetID,
                            },
                            @"account":op_account_id,
                            @"active":[new_active_permission copy],
                        };
                        [builder add_operation:ebo_account_update opdata:opdata_bots_authority];
                    }
                    
                    //  获取签名KEY
                    [builder addSignKeys:[[WalletManager sharedWalletManager] getSignKeysFromFeePayingAccount:op_account_id
                                                                                       requireOwnerPermission:NO]];
                }] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:NSLocalizedString(@"kBotsActionTipsDeleteOK", @"删除成功。")];
                    [self queryMyBotsList];
                    return nil;
                }];
            }] catch:^id(id error) {
                
                [_owner hideBlockView];
                [OrgUtils showGrapheneError:error];
                
                return nil;
            }];
        }
    }];
}

@end
