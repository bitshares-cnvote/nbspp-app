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

@interface ViewBotsGridInfoCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbBotsPairs;                   //  量化交易对
    UILabel*        _lbBotsStatus;                  //  机器人状态
    
    UILabel*        _lbMinPriceTitle;
    UILabel*        _lbMinPrice;                    //  最低价
    UILabel*        _lbMaxPriceTitle;
    UILabel*        _lbMaxPrice;                    //  最高价
    UILabel*        _lbGridNTitle;
    UILabel*        _lbGridN;                       //  网格数量
    
    UILabel*        _lbAmountTitle;
    UILabel*        _lbAmount;                      //  每格交易数量
    UILabel*        _lbTradeNumTitle;
    UILabel*        _lbTradeNum;                    //  交易次数
    UILabel*        _lbApyTitle;
    UILabel*        _lbApy;                         //  年化
    
    UILabel*        _lbStoppedMessage;              //  退出描述信息
}

@end

@implementation ViewBotsGridInfoCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbBotsPairs = nil;
    _lbBotsStatus = nil;
    
    _lbMinPriceTitle = nil;
    _lbMinPrice = nil;
    _lbMaxPriceTitle = nil;
    _lbMaxPrice = nil;
    _lbGridNTitle = nil;
    _lbGridN = nil;
    
    _lbAmountTitle = nil;
    _lbAmount = nil;
    _lbTradeNumTitle = nil;
    _lbTradeNum = nil;
    _lbApyTitle = nil;
    _lbApy = nil;
    
    _lbStoppedMessage = nil;
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
        _lbMinPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbMinPrice = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbMaxPriceTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbMaxPrice = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbMaxPriceTitle.textAlignment = NSTextAlignmentCenter;
        _lbMaxPrice.textAlignment = NSTextAlignmentCenter;
        
        _lbGridNTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbGridN = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbGridNTitle.textAlignment = NSTextAlignmentRight;
        _lbGridN.textAlignment = NSTextAlignmentRight;

        //  第三行
        _lbAmountTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbAmount = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        
        _lbTradeNumTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTradeNum = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbTradeNumTitle.textAlignment = NSTextAlignmentCenter;
        _lbTradeNum.textAlignment = NSTextAlignmentCenter;
        
        _lbApyTitle = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbApy = [self auxGenLabel:[UIFont systemFontOfSize:13]];
        _lbApyTitle.textAlignment = NSTextAlignmentRight;
        _lbApy.textAlignment = NSTextAlignmentRight;
        
        //  错误信息
        _lbStoppedMessage = [self auxGenLabel:[UIFont systemFontOfSize:13]];
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
    
    //  第一行 交易对 - 状态
    id quote_symbol = quote_asset ? quote_asset[@"symbol"] : @"--";
    id base_symbol = base_asset ? base_asset[@"symbol"] : @"--";
    //  TODO: lang
    _lbBotsPairs.text = [NSString stringWithFormat:@"网格交易 (%@/%@)", quote_symbol, base_symbol];
    _lbBotsPairs.frame = CGRectMake(xOffset, yOffset, fWidth, firstLineHeight);
    
    if ([[_item objectForKey:@"valid"] boolValue]) {
        id status = [value objectForKey:@"status"];
        if (status && [status isEqualToString:@"running"]) {
            UIColor* backColor = theme.buyColor;
            _lbBotsStatus.layer.borderColor = backColor.CGColor;
            _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
            
            _lbBotsStatus.text = @"运行中";
        } else {
            UIColor* backColor = theme.textColorGray;
            _lbBotsStatus.layer.borderColor = backColor.CGColor;
            _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
            _lbBotsStatus.text = @"已停止";
        }
    } else {
        
        UIColor* backColor = theme.sellColor;
        _lbBotsStatus.layer.borderColor = backColor.CGColor;
        _lbBotsStatus.layer.backgroundColor = backColor.CGColor;
        
        _lbBotsStatus.text = @"已失效";
    }
    CGSize size1 = [ViewUtils auxSizeWithLabel:_lbBotsPairs];
    CGSize size2 = [ViewUtils auxSizeWithLabel:_lbBotsStatus];
    _lbBotsStatus.frame = CGRectMake(xOffset + size1.width + 4,
                                     yOffset + (firstLineHeight - size2.height - 2)/2,
                                     size2.width + 8, size2.height + 2);
    yOffset += firstLineHeight;
    
    //  第二行 最低价 最高价 网格数量 标题
    _lbMinPriceTitle.text = @"最低价";
    _lbMaxPriceTitle.text = @"最高价";
    _lbGridNTitle.text = @"网格数量";
    _lbMinPriceTitle.textColor = theme.textColorGray;
    _lbMaxPriceTitle.textColor = theme.textColorGray;
    _lbGridNTitle.textColor = theme.textColorGray;
    
    _lbMinPriceTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbMaxPriceTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbGridNTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第三行 最低价 最高价 网格数量 值
    _lbMinPrice.text = n_min_price ? [OrgUtils formatFloatValue:n_min_price] : @"--";
    _lbMinPrice.textColor = theme.textColorNormal;
    
    _lbMaxPrice.text = n_max_price ? [OrgUtils formatFloatValue:n_max_price] : @"--";
    _lbMaxPrice.textColor = theme.textColorNormal;
    
    _lbGridN.text = [NSString stringWithFormat:@"%@", @(n_grid_n)];
    _lbGridN.textColor = theme.textColorNormal;
    
    _lbMinPrice.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbMaxPrice.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbGridN.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第四行 每格交易数量 交易次数 年华收益 标题
    _lbAmountTitle.text = @"每格交易数量";
    _lbTradeNumTitle.text = @"交易次数";
    _lbApyTitle.text = @"年华收益";
    _lbAmountTitle.textColor = theme.textColorGray;
    _lbTradeNumTitle.textColor = theme.textColorGray;
    _lbApyTitle.textColor = theme.textColorGray;
    
    _lbAmountTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbTradeNumTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbApyTitle.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //  第五行 每格交易数量 交易次数 年华收益 值
    _lbAmount.text = n_amount ? [OrgUtils formatFloatValue:n_amount] : @"--";
    _lbAmount.textColor = theme.textColorNormal;
    
    _lbTradeNum.text = [NSString stringWithFormat:@"%@", @([[value objectForKey:@"trade_num"] integerValue])];
    _lbTradeNum.textColor = theme.textColorNormal;
    
    _lbApy.text = @"333%";//TODO:ing
    _lbApy.textColor = theme.textColorNormal;
    
    _lbAmount.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbTradeNum.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    _lbApy.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
    yOffset += fLineHeight;
    
    //
    //    //  获取资产描述
    //    NSString* description = [asset_options objectForKey:@"description"];
    //    id description_json = [OrgUtils parse_json:description];
    //    if (description_json) {
    //        id main_desc = [description_json objectForKey:@"main"];
    //        if (main_desc) {
    //            description = main_desc;
    //        }
    //    }
    //    _lbStoppedMessage.text = description;
    //    _lbStoppedMessage.textColor = theme.textColorMain;
    //    _lbStoppedMessage.frame = CGRectMake(xOffset, yOffset, fWidth, fLineHeight);
}

@end
