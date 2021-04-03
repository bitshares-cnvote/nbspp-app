//
//  VCMinerRelationData.m
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//

#import "VCMinerRelationData.h"
#import "ViewMinerRelationDataCell.h"
#import "ViewMinerRelationDataHeaderCell.h"
#import "ViewEmptyInfoCell.h"

enum
{
    kVcSecHeader = 0,           //  统计数据
    kVcSecRefList,              //  推荐详细列表
    
    kVcSecMax
};

@interface VCMinerRelationData ()
{
    NSString*                           _asset_id;
    
    UITableViewBase*                    _mainTableView;
    ViewEmptyInfoCell*                  _cellNoData;
    
    ViewMinerRelationDataHeaderCell*    _header;            //  顶部统计数据
    NSDictionary*                       _headerData;        //  顶部统计数据
    NSMutableArray*                     _dataArray;
}

@end

@implementation VCMinerRelationData

-(void)dealloc
{
    if (_mainTableView){
        [[IntervalManager sharedIntervalManager] releaseLock:_mainTableView];
        _mainTableView.delegate = nil;
        _mainTableView = nil;
    }
    _cellNoData = nil;
    _dataArray = nil;
    
    _headerData = nil;
    _asset_id = nil;
}

- (id)initWithAsset:(id)asset_id
{
    self = [super init];
    if (self) {
        // Custom initialization
        assert([[WalletManager sharedWalletManager] isWalletExist]);
        assert(asset_id);
        _asset_id = [asset_id copy];
        _headerData = nil;
        _dataArray = [NSMutableArray array];
    }
    return self;
}

- (void)queryAllData
{
    id op_account = [[[WalletManager sharedWalletManager] getWalletAccountInfo] objectForKey:@"account"];
    assert(op_account);
    id account_id = op_account[@"id"];
    
    [self showBlockViewWithTitle:NSLocalizedString(@"kTipsBeRequesting", @"请求中...")];
    
    BOOL is_miner = [_asset_id isEqualToString:@"1.3.23"];  //  TODO:MINER立即值
    
    //  查询推荐关系
    id p1 = [[[NbWalletAPI sharedNbWalletAPI] checkAuthInfo] then:^id(id data) {
        if (!data || [data objectForKey:@"error"]) {
            return NSLocalizedString(@"kMinerCellClickTipsInvalidAuthToken", @"当前账号登录信息失效，请重新登录。");
        }
        return [[NbWalletAPI sharedNbWalletAPI] queryRelation:account_id is_miner:is_miner];
    }];
    
    //  查询收益数据（最近的NCN转账明细）
    GrapheneApi* api_history = [[GrapheneConnectionManager sharedGrapheneConnectionManager] any_connection].api_history;
    id stop = [NSString stringWithFormat:@"1.%@.0", @(ebot_operation_history)];
    id start = [NSString stringWithFormat:@"1.%@.%@", @(ebot_operation_history), @(0)];
    id p2 = [api_history exec:@"get_account_history" params:@[account_id, stop, @100, start]];
    
    [[[WsPromise all:@[p1, p2]] then:^id(id data_array) {
        id data_miner_or_error_message = [data_array objectAtIndex:0];
        id data_history = [data_array objectAtIndex:1];
        if ([data_miner_or_error_message isKindOfClass:[NSString class]]) {
            [self hideBlockView];
            [OrgUtils makeToast:data_miner_or_error_message];
        } else {
            [self onQueryResponsed:data_miner_or_error_message data_history:data_history];
            [self hideBlockView];
        }
        return nil;;
    }] catch:^id(id error) {
        [self hideBlockView];
        [OrgUtils makeToast:NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。")];
        return nil;;
    }];
}

- (void)onQueryResponsed:(id)data_miner data_history:(id)data_history
{
    id data_miner_items = [data_miner objectForKey:@"data"];
    
    //  clear
    [_dataArray removeAllObjects];
    
    //  推荐关系列表
    if (data_miner_items && [data_miner_items isKindOfClass:[NSArray class]] && [data_miner_items count] > 0) {
        [_dataArray addObjectsFromArray:data_miner_items];
    }
    
    //  TODO:history TODO:2.2
    
    //  动态设置UI的可见性
    if ([_dataArray count] > 0){
        _cellNoData.hidden = YES;
        [_mainTableView reloadData];
    }else{
        _cellNoData.hidden = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
    
    // Do any additional setup after loading the view.
    CGRect rect = [self rectWithoutNaviAndPageBar];
    
    _mainTableView = [[UITableViewBase alloc] initWithFrame:rect style:UITableViewStylePlain];
    _mainTableView.delegate = self;
    _mainTableView.dataSource = self;
    _mainTableView.backgroundColor = [UIColor clearColor];
    _mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;  //  REMARK：不显示cell间的横线。
    [self.view addSubview:_mainTableView];
    
    //  UI - 顶部统计数据
    _header = [[ViewMinerRelationDataHeaderCell alloc] init];
    
    //  UI - 空列表 TODO:lang
    _cellNoData = [[ViewEmptyInfoCell alloc] initWithText:@"没有任何推荐数据" iconName:nil];
    _cellNoData.hideTopLine = YES;
    _cellNoData.hideBottomLine = YES;
    _cellNoData.hidden = YES;
    
    //  查询数据
    [self queryAllData];
}

#pragma mark- TableView delegate method
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kVcSecMax;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kVcSecHeader) {
        return 1;
    }
    
    NSInteger n = [_dataArray count];
    if (n > 0){
        //  rows + title
        return n;
    }else{
        //  Empty Cell
        return 1;
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kVcSecHeader) {
        return 12.0f;
    } else {
        return 12 + 44.0f;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == kVcSecHeader){
        return [[UIView alloc] init];
    }else{
        CGFloat fWidth = self.view.bounds.size.width;
        CGFloat xOffset = tableView.layoutMargins.left;
        UIView* myView = [[UIView alloc] init];
        myView.backgroundColor = [ThemeManager sharedThemeManager].appBackColor;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOffset, 12, fWidth - xOffset * 2, 44.0f)];
        titleLabel.textColor = [ThemeManager sharedThemeManager].textColorHighlight;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        //  TODO:2.2 lang
        titleLabel.text = @"推荐明细";
        [myView addSubview:titleLabel];
        
        return myView;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecHeader) {
        return 8 + 24.0f * 4 + 8;
    } else {
        if ([_dataArray count] <= 0) {
            //  Empty Cell
            return 60.0f;
        } else {
            return tableView.rowHeight;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kVcSecHeader) {
        _header.item = _headerData;
        return _header;
    }
    
    if ([_dataArray count] <= 0) {
        return _cellNoData;
    }
    
    static NSString* identify = @"id_miner_relation_data";
    
    ViewMinerRelationDataCell* cell = (ViewMinerRelationDataCell *)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[ViewMinerRelationDataCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.backgroundColor = [UIColor clearColor];
    }
    cell.showCustomBottomLine = YES;
    [cell setItem:[_dataArray objectAtIndex:indexPath.row]];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

