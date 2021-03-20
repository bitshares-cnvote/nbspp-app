//
//  VCBotsManager.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCBotsManager.h"
#import "ViewBotsGridInfoCell.h"

@interface VCBotsManager ()
{
    __weak VCBase*          _owner;         //  REMARK：声明为 weak，否则会导致循环引用。
    
    UITableViewBase*        _mainTableView;
    NSMutableArray*         _dataArray;
    
    UILabel*                _lbEmpty;
}

@end

@implementation VCBotsManager

-(void)dealloc
{
    _owner = nil;
    _dataArray = nil;
    _lbEmpty = nil;
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
}

- (id)initWithOwner:(VCBase*)owner
{
    self = [super init];
    if (self) {
        assert(owner);
        _owner = owner;
        assert([[WalletManager sharedWalletManager] isWalletExist]);
        _dataArray = [NSMutableArray array];
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
                [_dataArray addObject:@{
                    @"valid":@(valid),
                    @"raw":storage_item
                }];
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
    id account_name = [[WalletManager sharedWalletManager] getWalletAccountName];
    assert(account_name);
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    [[[chainMgr queryAccountStorageInfo:account_name
                                catalog:kAppStorageCatalogBotsGridBots] then:^id(id data_array) {
        NSMutableDictionary* ids = [NSMutableDictionary dictionary];
        if (data_array && [data_array isKindOfClass:[NSArray class]]) {
            for (id storage_item in data_array) {
                id value = [storage_item objectForKey:@"value"];
                if (value && [value isKindOfClass:[NSDictionary class]]) {
                    id args = [value objectForKey:@"args"];
                    if (args && [args isKindOfClass:[NSDictionary class]]) {
                        id base = [args objectForKey:@"base"];
                        id quote = [args objectForKey:@"quote"];
                        if (base && ![base isEqualToString:@""]) {
                            [ids setObject:@YES forKey:base];
                        }
                        if (quote && ![quote isEqualToString:@""]) {
                            [ids setObject:@YES forKey:quote];
                        }
                    }
                }
            }
        }
        return [[chainMgr queryAllGrapheneObjects:[ids allKeys]] then:^id(id data) {
            [self onQueryMyBotsListResponsed:data_array];
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
    
    //  UI - 空 TODO:3.1 lang
    _lbEmpty = [self genCenterEmptyLabel:rect txt:@"网格交易订单为空，点击右上角创建网格交易。"];
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
    
    return baseHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ViewBotsGridInfoCell* cell = [[ViewBotsGridInfoCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.showCustomBottomLine = YES;
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
    
    //  TODO:lang 动态列表
    id list = [[[NSMutableArray array] ruby_apply:^(id ary) {
        [ary addObject:@{@"type":@(0), @"title":@"启动网格交易"}];
        [ary addObject:@{@"type":@(1), @"title":@"停止网格交易"}];
        [ary addObject:@{@"type":@(2), @"title":@"删除网格交易"}];
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
                    [self _startBots:bots];
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

- (void)_startBots:(id)item
{
    //  步骤：查询 & 启动 & 转账
    
    //  不支持提案：多签账号不支持跑量化机器人，量化授权会失去多签账号的意义。
    [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked){
            id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[ChainObjectManager sharedChainObjectManager] queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"该网格交易已经删除了。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if ([self isValidBotsData:latest_storage_item] && status && [status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"网格交易已经在运行中。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                //  TODO:启动参数
                id args = [[latest_storage_item objectForKey:@"value"] objectForKey:@"args"];
                id new_bots_data = @{
                    @"args": args,
                    
                    @"status": @"running",
                    // @"msg": @"",
                    // @"mask": @"",
                    // @"trade_num": 0,
                    
                    @"ext": @{
                            @"init_time": @((NSInteger)[[NSDate date] timeIntervalSince1970]),
                            @"init_base_amount": @"1",//TODO:
                            @"init_quote_amount": @"1",//TODO:
                    },
                };
                id key_values = @[@[bots_key, [new_bots_data to_json]]];
                
                //  TODO:转账触发启动事件
                
                return [[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:op_account_id
                                                                                          remove:NO
                                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                                      key_values:key_values] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"启动成功。"];
                    [self queryMyBotsList];
                    return nil;
                }];
                return nil;
                
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
            
            
            id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[ChainObjectManager sharedChainObjectManager] queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"该网格交易已经删除了。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if (![self isValidBotsData:latest_storage_item] || !status || ![status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"网格交易已停止。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                
                id mutable_latest_value = [[latest_storage_item objectForKey:@"value"] mutableCopy];
                [mutable_latest_value setObject:@"stopped" forKey:@"status"];
                [mutable_latest_value setObject:@"User Stop" forKey:@"msg"];
                
                id key_values = @[@[bots_key, [mutable_latest_value to_json]]];
                
                return [[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:op_account_id
                                                                                          remove:NO
                                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                                      key_values:key_values] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"网格交易已停止。"];
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
    //  不支持提案：多签账号不支持跑量化机器人，量化授权会失去多签账号的意义。
    [_owner GuardWalletUnlocked:YES body:^(BOOL unlocked) {
        if (unlocked){
            
            
            id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
            id op_account_id = [op_account objectForKey:@"id"];
            id storage_item = [item objectForKey:@"raw"];
            id bots_key = [storage_item objectForKey:@"key"];
            
            [_owner showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
            [[[[ChainObjectManager sharedChainObjectManager] queryAccountAllBotsData:op_account_id] then:^id(id result_hash) {
                id latest_storage_item = [result_hash objectForKey:bots_key];
                if (!latest_storage_item) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"该网格交易已经删除了。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id status = [[latest_storage_item objectForKey:@"value"] objectForKey:@"status"];
                if ([self isValidBotsData:latest_storage_item] && status && [status isEqualToString:@"running"]) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"该网格交易正在运行中，请先停止。"];
                    //  刷新界面
                    [self onQueryMyBotsListResponsed:result_hash];
                    return nil;
                }
                
                id key_values = @[@[bots_key, [@{} to_json]]];
                return [[[BitsharesClientManager sharedBitsharesClientManager] accountStorageMap:op_account_id
                                                                                          remove:YES
                                                                                         catalog:kAppStorageCatalogBotsGridBots
                                                                                      key_values:key_values] then:^id(id data) {
                    [_owner hideBlockView];
                    [OrgUtils makeToast:@"删除成功。"];
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
