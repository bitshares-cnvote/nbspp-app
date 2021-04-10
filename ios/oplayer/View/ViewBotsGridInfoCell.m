//
//  ViewBotsGridInfoCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewBotsGridInfoCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "ChainObjectManager.h"
#import "OrgUtils.h"
#import "ModelUtils.h"

@interface ViewBotsGridInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbBotsPairs;                   //  量化交易对
    UILabel*        _lbBotsStatus;                  //  机器人状态
    
    UILabel*        _lbPriceRangeTitle;
    UILabel*        _lbPriceRange;                  //  价格区间
    UILabel*        _lbGridNTitle;
    UILabel*        _lbGridN;                       //  网格数量
    UILabel*        _lbAmountTitle;
    UILabel*        _lbAmount;                      //  每格交易数量
    
    UILabel*        _lbTradeNumTitle;
    UILabel*        _lbTradeNum;                    //  交易次数
    UILabel*        _lbProfitTitle;
    UILabel*        _lbProfit;                      //  浮动盈亏
    UILabel*        _lbApyTitle;
    UILabel*        _lbApy;                         //  年化
    
    UILabel*        _lbMessage;                     //  描述信息 运行时长 or 错误信息等
}

@end

@implementation ViewBotsGridInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbBotsPairs = nil;
    _lbBotsStatus = nil;
    
    _lbPriceRangeTitle = nil;
    _lbPriceRange = nil;
    _lbProfitTitle = nil;
    _lbProfit = nil;
    _lbGridNTitle = nil;
    _lbGridN = nil;
    
    _lbAmountTitle = nil;
    _lbAmount = nil;
    _lbTradeNumTitle = nil;
    _lbTradeNum = nil;
    _lbApyTitle = nil;
    _lbApy = nil;
    
    _lbMessage = nil;
    _ticker_data_hash = nil;
    _balance_hash = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        _lbBotsPairs = [self auxGenLabel:[UIFont boldSystemFontOfSize:16]];
        _lbBotsStatus = [self auxGenLabel:[UIFont boldSystemFontOfSize:12]];
        _lbBotsStatus.textColor= [ThemeManager sharedThemeManager].textColorFlag;
        _lbBotsStatus.textAlignment = NSTextAlignmentCenter;
        _lbBotsStatus.layer.borderWidth = 1;
        _lbBotsStatus.layer.cornerRadius = 2;
        _lbBotsStatus.layer.masksToBounds = YES;
        
        //  第二行
        _lbPriceRangeTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbPriceRange = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbGridNTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbGridN = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbGridNTitle.textAlignment = NSTextAlignmentCenter;
        _lbGridN.textAlignment = NSTextAlignmentCenter;
        
        _lbAmountTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbAmount = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbAmountTitle.textAlignment = NSTextAlignmentRight;
        _lbAmount.textAlignment = NSTextAlignmentRight;
        
        //  第三行
        _lbTradeNumTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTradeNum = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbProfitTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbProfit = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbProfitTitle.textAlignment = NSTextAlignmentCenter;
        _lbProfit.textAlignment = NSTextAlignmentCenter;
        
        _lbApyTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbApy = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbApyTitle.textAlignment = NSTextAlignmentRight;
        _lbApy.textAlignment = NSTextAlignmentRight;
        
        //  错误信息
        _lbMessage = [self auxGenLabel:[UIFont systemFontOfSize:13]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

-(void)setItem:(NSDictionary*)item
{
    if (_item != item)
    {
        _item = item;
        [self setNeedsDisplay];
        //  REMARK fix ios7 detailTextLabel not show
        if ([NativeAppDelegate systemVersion] < 9)
        {
            [self layoutSubviews];
        }
    }
}

- (NSDecimalNumber*)_getBalanceByAsset:(id)asset
{
    assert(asset);
    id balance = [_balance_hash objectForKey:asset[@"id"]];
    if (balance) {
        return [NSDecimalNumber decimalNumberWithMantissa:[balance unsignedLongLongValue]
                                                 exponent:-[[asset objectForKey:@"precision"] integerValue]
                                               isNegative:NO];
    } else {
        return [NSDecimalNumber zero];
    }
}


- (NSDecimalNumber*)_estimatedByBaseAsset:(id)duck_ticker_data n_base:(id)n_base n_quote:(id)n_quote
{
    id highest_bid = [duck_ticker_data objectForKey:@"highest_bid"];
    id lowest_ask = [duck_ticker_data objectForKey:@"lowest_ask"];
    if (!highest_bid || !lowest_ask) {
        return nil;
    }
    id n_highest_bid = [NSDecimalNumber decimalNumberWithString:highest_bid];
    id n_lowest_ask = [NSDecimalNumber decimalNumberWithString:lowest_ask];
    id n_mid_price = [[n_highest_bid decimalNumberByAdding:n_lowest_ask] decimalNumberByDividingBy:[NSDecimalNumber decimalNumberWithString:@"2"]];
    return [[n_quote decimalNumberByMultiplyingBy:n_mid_price] decimalNumberByAdding:n_base];
}

- (id)_calcProfitAndApy:(id)base_asset quote:(id)quote_asset ext_data:(id)ext_data
{
    if (!_ticker_data_hash || !_balance_hash) {
        return nil;
    }
    
    if (!base_asset || !quote_asset || !ext_data) {
        return nil;
    }
    
    id pair_key = [NSString stringWithFormat:@"%@_%@", [base_asset objectForKey:@"symbol"], [quote_asset objectForKey:@"symbol"]];
    id ticker_data = [_ticker_data_hash objectForKey:pair_key];
    if (!ticker_data) {
        return nil;
    }
    
    NSInteger base_precision = [[base_asset objectForKey:@"precision"] integerValue];
    NSInteger quote_precision = [[quote_asset objectForKey:@"precision"] integerValue];
    
    id n_init_balance_base = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"init_balance_base"] unsignedLongLongValue]
                                                               exponent:-base_precision
                                                             isNegative:NO];
    id n_init_balance_quote = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"init_balance_quote"] unsignedLongLongValue]
                                                                exponent:-quote_precision
                                                              isNegative:NO];
    id n_cancelled_order_base = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"cancelled_order_base"] unsignedLongLongValue]
                                                                  exponent:-base_precision
                                                                isNegative:NO];
    id n_cancelled_order_quote = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"cancelled_order_quote"] unsignedLongLongValue]
                                                                   exponent:-quote_precision
                                                                 isNegative:NO];
    
    //  网格启动时候的账号总金额
    id n_started_base_balance = [n_init_balance_base decimalNumberByAdding:n_cancelled_order_base];
    id n_started_quote_balance = [n_init_balance_quote decimalNumberByAdding:n_cancelled_order_quote];
    
    //  网格启动初始化挂单金额
    id n_init_order_base = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"init_order_base"] unsignedLongLongValue]
                                                             exponent:-base_precision
                                                           isNegative:NO];
    id n_init_order_quote = [NSDecimalNumber decimalNumberWithMantissa:[[ext_data objectForKey:@"init_order_quote"] unsignedLongLongValue]
                                                              exponent:-quote_precision
                                                            isNegative:NO];
    
    //  网格启动挂单完毕剩余的金额（多余的资金）
    id n_left_base = [n_started_base_balance decimalNumberBySubtracting:n_init_order_base];
    id n_left_quote = [n_started_quote_balance decimalNumberBySubtracting:n_init_order_quote];
    
    //  现在状态下的总金额
    id n_now_base_balance = [self _getBalanceByAsset:base_asset];
    id n_now_quote_balance = [self _getBalanceByAsset:quote_asset];
    
    id n_valid_base = [n_now_base_balance decimalNumberBySubtracting:n_left_base];
    id n_valid_quote = [n_now_quote_balance decimalNumberBySubtracting:n_left_quote];
    
    //  折算
    id n_est_old_base = [self _estimatedByBaseAsset:ext_data n_base:n_init_order_base n_quote:n_init_order_quote];
    id n_est_now_base = [self _estimatedByBaseAsset:ticker_data n_base:n_valid_base n_quote:n_valid_quote];
    if (!n_est_old_base || !n_est_now_base) {
        return nil;
    }
    
    //  浮动盈亏（以 base 资产计价）
    id n_profit = [n_est_now_base decimalNumberBySubtracting:n_est_old_base withBehavior:[ModelUtils decimalHandlerRoundUp:base_precision]];
    
    NSInteger now_ts = (NSInteger)[[NSDate date] timeIntervalSince1970];
    NSInteger start_ts = [[ext_data objectForKey:@"init_time"] integerValue];
    NSInteger diff_ts = MAX(now_ts - start_ts, 1);  //  REMARK：有可能有时间误差，默认最低取值1秒。
    //  31622400 - 366天的秒数
    id n_apy = [[[[n_profit decimalNumberByDividingBy:n_est_old_base] decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithString:@"31622400"]] decimalNumberByDividingBy:[NSDecimalNumber decimalNumberWithMantissa:diff_ts exponent:0 isNegative:NO]] decimalNumberByMultiplyingByPowerOf10:2 withBehavior:[ModelUtils decimalHandlerRoundUp:2]];
    
    return @{@"n_profit": n_profit, @"n_apy": n_apy};
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_item){
        return;
    }
    
    ThemeManager* theme = [ThemeManager sharedThemeManager];
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat firstLineHeight = 28.0f;
    CGFloat fLineHeight = 24.0f;
    
    //  获取数据
    id storage_item = [_item objectForKey:@"raw"];
    id value = [storage_item objectForKey:@"value"];
    id args = [value objectForKey:@"args"];
    
    id base_asset = nil;
    id quote_asset = nil;
    id n_min_price = nil;
    id n_max_price = nil;
    NSInteger n_grid_n = nil;
    id n_amount = nil;
    if (args) {
        id base_id = [args objectForKey:@"base"];
        id quote_id = [args objectForKey:@"quote"];
        if (base_id) {
            base_asset = [chainMgr getChainObjectByID:base_id];
        }
        if (quote_id) {
            quote_asset = [chainMgr getChainObjectByID:quote_id];
            if (quote_asset) {
                n_amount = [NSDecimalNumber decimalNumberWithMantissa:[[args objectForKey:@"order_amount"] unsignedLongLongValue]
                                                             exponent:-[[quote_asset objectForKey:@"precision"] integerValue]
                                                           isNegative:NO];
            }
        }
        n_grid_n = [[args objectForKey:@"grid_n"] integerValue];
        n_min_price = [NSDecimalNumber decimalNumberWithMantissa:[[args objectForKey:@"min_price"] unsignedLongLongValue] exponent:-8 isNegative:NO];
        n_max_price = [NSDecimalNumber decimalNumberWithMantissa:[[args objectForKey:@"max_price"] unsignedLongLongValue] exponent:-8 isNegative:NO];
    }
    
    //  计算收益等相关数据
    id profit_apy_hash = [self _calcProfitAndApy:base_asset quote:quote_asset ext_data:[value objectForKey:@"ext"]];
        
    //  第一行 交易对 - 状态
    id quote_symbol = quote_asset ? quote_asset[@"symbol"] : @"--";
    id base_symbol = base_asset ? base_asset[@"symbol"] : @"--";
    
    _lbBotsPairs.text = [NSString stringWithFormat:NSLocalizedString(@"kBotsCellLabelPairNameTitle", @"网格交易#%@ (%@/%@)"),
                         [[[storage_item objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject],
                         quote_symbol, base_symbol];
    _lbBotsPairs.frame = CGRectMake(xOffset, yOffset, fWidth, firstLineHeight);
    
    if ([[_item objectForKey:@"valid"] boolValue]) {
        id status = [value objectForKey:@"status"];
        if (status && [status isEqualToString:@"running"]) {
            UIColor* backColor = theme.buyColor;
            _lbBotsStatus.layer.borderColor = backColor.CGColor;
            _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
            
            _lbBotsStatus.text = NSLocalizedString(@"kBotsCellLabelStatusRunning", @"运行中");
        } else {
            UIColor* backColor = theme.textColorGray;
            _lbBotsStatus.layer.borderColor = backColor.CGColor;
            _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
            _lbBotsStatus.text = NSLocalizedString(@"kBotsCellLabelStatusStopped", @"已停止");
        }
    } else {
        
        UIColor* backColor = theme.sellColor;
        _lbBotsStatus.layer.borderColor = backColor.CGColor;
        _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
        
        _lbBotsStatus.text = NSLocalizedString(@"kBotsCellLabelStatusInvalid", @"已失效");
    }
    CGSize size1 = [ViewUtils auxSizeWithLabel:_lbBotsPairs];
    CGSize size2 = [ViewUtils auxSizeWithLabel:_lbBotsStatus];
    _lbBotsStatus.frame = CGRectMake(xOffset + size1.width + 4,
                                     yOffset + (firstLineHeight - size2.height - 2)/2,
                                     size2.width + 8, size2.height + 2);
    yOffset += firstLineHeight;
    
    //  第二行 价格区间 网格数量 每个交易数量 标题栏
    _lbPriceRangeTitle.text = NSLocalizedString(@"kBotsCellLabelPriceRangeTitle", @"价格区间");
    _lbGridNTitle.text = NSLocalizedString(@"kBotsCellLabelGridN", @"网格数量");
    _lbAmountTitle.text = NSLocalizedString(@"kBotsCellLabelAmountPerGrid", @"每格交易数量");
    
    _lbPriceRangeTitle.textColor = theme.textColorGray;
    _lbGridNTitle.textColor = theme.textColorGray;
    _lbAmountTitle.textColor = theme.textColorGray;
    
    _lbPriceRangeTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbGridNTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbAmountTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第三行 价格区间 网格数量 每个交易数量 值
    if (n_min_price && n_max_price) {
        _lbPriceRange.text = [NSString stringWithFormat:@"%@ ~ %@", [OrgUtils formatFloatValue:n_min_price], [OrgUtils formatFloatValue:n_max_price]];
    } else {
        _lbPriceRange.text = @"-- ~ --";
    }
    _lbPriceRange.textColor = theme.textColorNormal;
    
    _lbGridN.text = [NSString stringWithFormat:@"%@", @(n_grid_n)];
    _lbGridN.textColor = theme.textColorNormal;
    
    _lbAmount.text = n_amount ? [OrgUtils formatFloatValue:n_amount] : @"--";
    _lbAmount.textColor = theme.textColorNormal;
    
    _lbPriceRange.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbGridN.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbAmount.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第四行 交易次数 浮动盈亏 年华收益 标题栏
    _lbTradeNumTitle.text = NSLocalizedString(@"kBotsCellLabelTradeNum", @"交易次数");
    _lbProfitTitle.text = NSLocalizedString(@"kBotsCellLabelProfit", @"浮动盈亏");
    _lbApyTitle.text = NSLocalizedString(@"kBotsCellLabelApy", @"年化收益");
    
    _lbTradeNumTitle.textColor = theme.textColorGray;
    _lbProfitTitle.textColor = theme.textColorGray;
    _lbApyTitle.textColor = theme.textColorGray;
    
    _lbTradeNumTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbProfitTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbApyTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第五行 交易次数 浮动盈亏 年华收益 值
    _lbTradeNum.text = [NSString stringWithFormat:@"%@", @([[value objectForKey:@"trade_num"] integerValue])];
    _lbTradeNum.textColor = theme.textColorNormal;
    
    if (profit_apy_hash) {
        id n_zero = [NSDecimalNumber zero];
        
        id n_profit = [profit_apy_hash objectForKey:@"n_profit"];
        if ([n_profit compare:n_zero] > 0) {
            _lbProfit.text = [NSString stringWithFormat:@"+%@ %@", [OrgUtils formatFloatValue:n_profit usesGroupingSeparator:NO], base_symbol];
            _lbProfit.textColor = theme.buyColor;
        } else if ([n_profit compare:n_zero] < 0) {
            _lbProfit.text = [NSString stringWithFormat:@"%@ %@", [OrgUtils formatFloatValue:n_profit usesGroupingSeparator:NO], base_symbol];
            _lbProfit.textColor = theme.sellColor;
        } else {
            _lbProfit.text = [OrgUtils formatFloatValue:n_profit usesGroupingSeparator:NO];
            _lbProfit.textColor = theme.textColorNormal;
        }
        
        id n_apy = [profit_apy_hash objectForKey:@"n_apy"];
        if ([n_apy compare:n_zero] > 0) {
            _lbApy.text = [NSString stringWithFormat:@"%@%%", n_apy];
            _lbApy.textColor = theme.buyColor;
        } else if ([n_apy compare:n_zero] < 0) {
            _lbApy.text = [NSString stringWithFormat:@"%@%%", n_apy];
            _lbApy.textColor = theme.sellColor;
        } else {
            _lbApy.text = [NSString stringWithFormat:@"%@%%", n_apy];
            _lbApy.textColor = theme.textColorNormal;
        }
    } else {
        _lbProfit.text = @"--";
        _lbProfit.textColor = theme.textColorNormal;
        
        _lbApy.text = @"--%";
        _lbApy.textColor = theme.textColorNormal;
    }

    _lbTradeNum.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbProfit.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbApy.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  获取资产描述
    _lbMessage.text = @"已运行 17 天 2 小时 2 分 18 秒";//TODO:3.0
    _lbMessage.textColor = theme.textColorMain;
    _lbMessage.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
