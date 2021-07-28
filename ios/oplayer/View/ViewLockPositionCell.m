//
//  ViewLockPositionCell.m
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import "ViewLockPositionCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"
#import "ChainObjectManager.h"
#import "VCVestingBalance.h"

@interface ViewLockPositionCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAssetName;           //  锁仓资产名
    
    UILabel*        _lbAmountTitle;         //  锁仓数量
    UILabel*        _lbAmountValue;         //  锁仓数量
    
    UILabel*        _lbLockPeriodTitle;     //  锁仓周期
    UILabel*        _lbLockPeriodValue;     //  锁仓周期
    
    UILabel*        _lbStatusTitle;         //  当前状态（什么时候到期等）
    UILabel*        _lbStatusValue;         //  当前状态（什么时候到期等）
    
    UIButton*       _btnWithdraw;           //  提取按钮
}

@end

@implementation ViewLockPositionCell

@synthesize item=_item;
@synthesize row;

- (void)dealloc
{
    _item = nil;
    
    _lbAssetName = nil;
    _lbAmountTitle = nil;
    _lbAmountValue = nil;
    _lbLockPeriodTitle = nil;
    _lbLockPeriodValue = nil;
    _lbStatusTitle = nil;
    _lbStatusValue = nil;
    
    _btnWithdraw = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier vc:(UIViewController*)vc
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  第一行
        _lbAssetName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAssetName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAssetName.textAlignment = NSTextAlignmentLeft;
        _lbAssetName.numberOfLines = 1;
        _lbAssetName.backgroundColor = [UIColor clearColor];
        _lbAssetName.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_lbAssetName];
        
        if (vc){
            _btnWithdraw = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnWithdraw.backgroundColor = [UIColor clearColor];
            [_btnWithdraw setTitle:NSLocalizedString(@"kVestingCellBtnWithdrawal", @"提取") forState:UIControlStateNormal];
            [_btnWithdraw setTitleColor:[ThemeManager sharedThemeManager].textColorHighlight forState:UIControlStateNormal];
            _btnWithdraw.titleLabel.font = [UIFont systemFontOfSize:16.0];
            _btnWithdraw.userInteractionEnabled = YES;
            _btnWithdraw.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            [_btnWithdraw addTarget:vc action:@selector(onButtonClicked_Withdraw:) forControlEvents:UIControlEventTouchUpInside];
            _btnWithdraw.hidden = YES;
            [self addSubview:_btnWithdraw];
        }else{
            _btnWithdraw = nil;
        }
        
        //  第二行
        _lbAmountTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmountTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmountTitle.textAlignment = NSTextAlignmentLeft;
        _lbAmountTitle.numberOfLines = 1;
        _lbAmountTitle.backgroundColor = [UIColor clearColor];
        _lbAmountTitle.font = [UIFont systemFontOfSize:13];
        _lbAmountTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAmountTitle];
        
        _lbLockPeriodTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbLockPeriodTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbLockPeriodTitle.textAlignment = NSTextAlignmentCenter;
        _lbLockPeriodTitle.numberOfLines = 1;
        _lbLockPeriodTitle.backgroundColor = [UIColor clearColor];
        _lbLockPeriodTitle.font = [UIFont systemFontOfSize:13];
        _lbLockPeriodTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbLockPeriodTitle];
        
        _lbStatusTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbStatusTitle.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbStatusTitle.textAlignment = NSTextAlignmentRight;
        _lbStatusTitle.numberOfLines = 1;
        _lbStatusTitle.backgroundColor = [UIColor clearColor];
        _lbStatusTitle.font = [UIFont systemFontOfSize:13];
        _lbStatusTitle.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbStatusTitle];
        
        //  第三行
        _lbAmountValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmountValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmountValue.textAlignment = NSTextAlignmentLeft;
        _lbAmountValue.numberOfLines = 1;
        _lbAmountValue.backgroundColor = [UIColor clearColor];
        _lbAmountValue.font = [UIFont systemFontOfSize:14];
        _lbAmountValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbAmountValue];
        
        _lbLockPeriodValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbLockPeriodValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbLockPeriodValue.textAlignment = NSTextAlignmentCenter;
        _lbLockPeriodValue.numberOfLines = 1;
        _lbLockPeriodValue.backgroundColor = [UIColor clearColor];
        _lbLockPeriodValue.font = [UIFont systemFontOfSize:14];
        _lbLockPeriodValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbLockPeriodValue];
        
        _lbStatusValue = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbStatusValue.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbStatusValue.textAlignment = NSTextAlignmentRight;
        _lbStatusValue.numberOfLines = 1;
        _lbStatusValue.backgroundColor = [UIColor clearColor];
        _lbStatusValue.font = [UIFont systemFontOfSize:14];
        _lbStatusValue.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbStatusValue];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)setTagData:(NSInteger)tag
{
    if (_btnWithdraw){
        _btnWithdraw.tag = tag;
    }
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
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 0;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    
    //  准备数据
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id balance = [_item objectForKey:@"balance"];
    id balance_asset = [chainMgr getChainObjectByID:balance[@"asset_id"]];
    
    assert([[[_item objectForKey:@"policy"] objectAtIndex:0] integerValue] == ebvp_cdd_vesting_policy);
    id policy_data = [[_item objectForKey:@"policy"] objectAtIndex:1];
    NSTimeInterval start_claim_ts = [OrgUtils parseBitsharesTimeString:[policy_data objectForKey:@"start_claim"]];
    NSTimeInterval init_ts = [OrgUtils parseBitsharesTimeString:[policy_data objectForKey:@"coin_seconds_earned_last_update"]];
    NSTimeInterval now_ts = [OrgUtils current_ts];  //  TODO:是否用区块时间判断
    NSInteger diff_ts = (NSInteger)(start_claim_ts - init_ts);
    diff_ts -= diff_ts % 3600;                      //  REMARK：按小时取整，创建的时候正常浮动了一定秒数。
    
    //  第一行 ID TODO:3.2 lang
    _lbAssetName.text = [NSString stringWithFormat:@"锁仓编号 #%@", [[[_item objectForKey:@"id"] componentsSeparatedByString:@"."] lastObject]];
    _lbAssetName.textColor = theme.textColorMain;
    
    if (_btnWithdraw){
        _lbAssetName.frame = CGRectMake(xOffset, yOffset, fWidth - 84, 28);
        _btnWithdraw.frame = CGRectMake(self.bounds.size.width - xOffset - 120, yOffset, 120, 28);
    }else{
        _lbAssetName.frame = CGRectMake(xOffset, yOffset, fWidth, 28);
    }
    
    yOffset += 28;
    
    //  第二行 TODO:3.2 lang
    _lbAmountTitle.text = [NSString stringWithFormat:@"%@(%@)", NSLocalizedString(@"kLabelTradeHisTitleAmount", @"数量"), balance_asset[@"symbol"]];;
    _lbLockPeriodTitle.text = @"周期";
    _lbStatusTitle.text = @"到期时间";
    _lbAmountTitle.textColor = theme.textColorGray;
    _lbLockPeriodTitle.textColor = theme.textColorGray;
    _lbStatusTitle.textColor = theme.textColorGray;
    
    _lbAmountTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbLockPeriodTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbStatusTitle.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    
    yOffset += 24;
    
    //  第三行 数量和价格
    _lbAmountValue.text = [NSString stringWithFormat:@"%@", [OrgUtils formatAssetString:balance[@"amount"] asset:balance_asset]];
    _lbAmountValue.textColor = theme.textColorNormal;
    
    //  TODO:3.2
    _lbLockPeriodValue.text = [OrgUtils fmtNhoursAndDays:diff_ts];
    _lbLockPeriodValue.textColor = theme.textColorNormal;
    
    //  TODO:3.2 lang
    if (now_ts >= start_claim_ts) {
        _lbStatusValue.text = @"已到期";
        _lbStatusValue.textColor = theme.textColorMain;
        if (_btnWithdraw) {
            _btnWithdraw.hidden = NO;
        }
    } else {
        NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"yy-MM-dd HH:mm:ss"];
        _lbStatusValue.text = [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970:start_claim_ts]];
        _lbStatusValue.textColor = theme.textColorNormal;
        if (_btnWithdraw) {
            _btnWithdraw.hidden = YES;
        }
    }
    
    //    //  DEBUG:only for test
    //#ifdef DEBUG
    //    if (_btnWithdraw) {
    //        _btnWithdraw.hidden = NO;
    //    }
    //#endif  //  DEBUG
    
    _lbAmountValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbLockPeriodValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
    _lbStatusValue.frame = CGRectMake(xOffset, yOffset, fWidth, 24);
}

@end
