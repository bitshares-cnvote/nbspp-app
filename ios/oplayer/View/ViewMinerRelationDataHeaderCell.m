//
//  ViewMinerRelationDataHeaderCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewMinerRelationDataHeaderCell.h"
#import "NativeAppDelegate.h"
#import "ChainObjectManager.h"
#import "SettingManager.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewMinerRelationDataHeaderCell()
{
    NSDictionary*   _item;
    
    UIView*         _container;
    
    UILabel*        _lbInviteAccountN;  //  总邀请人数
    UILabel*        _lbTotal;           //  总持仓
    UILabel*        _lbMinerLastReward; //  抵押挖矿最近收益
    UILabel*        _lbRefLastReward;   //  推荐挖矿最近收益
}

@end

@implementation ViewMinerRelationDataHeaderCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbInviteAccountN = nil;
    _lbTotal = nil;
    _lbMinerLastReward = nil;
    _lbRefLastReward = nil;
}

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        ThemeManager* theme = [ThemeManager sharedThemeManager];
        
        _container = [[UIView alloc] init];
        UIColor* backColor = theme.textColorHighlight;
        _container.backgroundColor = backColor;
        _container.layer.borderWidth = 1;
        _container.layer.cornerRadius = 5;
        _container.layer.masksToBounds = YES;
        _container.layer.borderColor = backColor.CGColor;
        _container.layer.backgroundColor = backColor.CGColor;
        [self addSubview:_container];
        
        _lbInviteAccountN = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:16.0f] superview:_container];
        _lbInviteAccountN.textColor = theme.textColorFlag;
        _lbInviteAccountN.textAlignment = NSTextAlignmentLeft;
        
        _lbTotal = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:_container];
        _lbTotal.textColor = theme.textColorFlag;
        _lbTotal.textAlignment = NSTextAlignmentLeft;
        
        _lbMinerLastReward = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:_container];
        _lbMinerLastReward.textColor = theme.textColorFlag;
        _lbMinerLastReward.textAlignment = NSTextAlignmentLeft;
        
        _lbRefLastReward = [ViewUtils auxGenLabel:[UIFont systemFontOfSize:13.0f] superview:_container];
        _lbRefLastReward.textColor = theme.textColorFlag;
        _lbRefLastReward.textAlignment = NSTextAlignmentLeft;
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
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 8.0f;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
    CGFloat fLineHeight = 24.0f;
    
    id str_miner_prefix = @"";
    id str_share_prefix = @"";
    id str_mining_asset_symbol = @"";
    if (_is_miner) {
        str_miner_prefix = NSLocalizedString(@"kMinerNBSMiningRewardTitle", @"MINER锁仓挖矿收益");
        str_share_prefix = NSLocalizedString(@"kMinerNBSShareMiningRewardTitle", @"MINER推荐挖矿收益");
        str_mining_asset_symbol = @"MINER";
    } else {
        str_miner_prefix = NSLocalizedString(@"kMinerCNYMiningRewardTitle", @"SCNY抵押挖矿收益");
        str_share_prefix = NSLocalizedString(@"kMinerCNYShareMiningRewardTitle", @"SCNY推荐挖矿收益");
        str_mining_asset_symbol = @"SCNY";
    }
    
    ChainObjectManager* chainMgr = [ChainObjectManager sharedChainObjectManager];
    id reward_asset = [chainMgr getChainObjectByID:[[SettingManager sharedSettingManager] getAppParameters:@"mining_reward_asset"]];
    assert(reward_asset);
    
    if (_item) {
        _lbInviteAccountN.text = [NSString stringWithFormat:NSLocalizedString(@"kMinerTotalInviteAccountTitle", @"总共邀请 %@ 人"),
                                  _item[@"total_account"]];
        _lbTotal.text = [NSString stringWithFormat:NSLocalizedString(@"kMinerTotalInviteAmountTitle", @"有效邀请持有量 %@ %@"),
                         _item[@"total_amount"], str_mining_asset_symbol];
        id data_reward_hash = [_item objectForKey:@"data_reward_hash"] ?: @{};
        //  抵押或锁仓挖矿
        id reward_mining = [data_reward_hash objectForKey:@"mining"];
        if (reward_mining) {
            id opdata = [[[reward_mining objectForKey:@"history"] objectForKey:@"op"] lastObject];
            assert([reward_asset[@"id"] isEqualToString:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]]);
            id n_reward_amount = [NSDecimalNumber decimalNumberWithMantissa:[[[opdata objectForKey:@"amount"] objectForKey:@"amount"] unsignedLongLongValue]
                                                                   exponent:-[[reward_asset objectForKey:@"precision"] integerValue]
                                                                 isNegative:NO];
            
            id date_str = [OrgUtils fmtMMddTimeShowString:[[reward_mining objectForKey:@"header"] objectForKey:@"timestamp"]];
            
            _lbMinerLastReward.text = [NSString stringWithFormat:@"%@(%@) %@ %@",
                                       str_miner_prefix, date_str, n_reward_amount, reward_asset[@"symbol"]];
        } else {
            _lbMinerLastReward.text = [NSString stringWithFormat:@"%@ %@ %@",
                                       str_miner_prefix, @(0), reward_asset[@"symbol"]];
        }
        //  推荐挖矿
        id reward_shares = [data_reward_hash objectForKey:@"shares"];
        if (reward_shares) {
            id opdata = [[[reward_shares objectForKey:@"history"] objectForKey:@"op"] lastObject];
            assert([reward_asset[@"id"] isEqualToString:[[opdata objectForKey:@"amount"] objectForKey:@"asset_id"]]);
            id n_reward_amount = [NSDecimalNumber decimalNumberWithMantissa:[[[opdata objectForKey:@"amount"] objectForKey:@"amount"] unsignedLongLongValue]
                                                                   exponent:-[[reward_asset objectForKey:@"precision"] integerValue]
                                                                 isNegative:NO];
            
            id date_str = [OrgUtils fmtMMddTimeShowString:[[reward_shares objectForKey:@"header"] objectForKey:@"timestamp"]];
            
            _lbRefLastReward.text = [NSString stringWithFormat:@"%@(%@) %@ %@",
                                     str_share_prefix, date_str, n_reward_amount, reward_asset[@"symbol"]];
            
        } else {
            _lbRefLastReward.text = [NSString stringWithFormat:@"%@ %@ %@", str_share_prefix, @(0), reward_asset[@"symbol"]];
        }
    } else {
        _lbInviteAccountN.text = [NSString stringWithFormat:NSLocalizedString(@"kMinerTotalInviteAccountTitle", @"总共邀请 %@ 人"), @"--"];
        _lbTotal.text = [NSString stringWithFormat:NSLocalizedString(@"kMinerTotalInviteAmountTitle", @"有效邀请持有量 %@ %@"),
                         @"--", str_mining_asset_symbol];
        _lbMinerLastReward.text = [NSString stringWithFormat:@"%@ %@ %@", str_miner_prefix, @"--", reward_asset[@"symbol"]];
        _lbRefLastReward.text = [NSString stringWithFormat:@"%@ %@ %@", str_share_prefix, @"--", reward_asset[@"symbol"]];
    }
    
    _lbInviteAccountN.frame = CGRectMake(xOffset, yOffset + fLineHeight * 0, fWidth, fLineHeight);
    
    _lbTotal.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 1, fWidth, fLineHeight);
    _lbMinerLastReward.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 2, fWidth, fLineHeight);
    _lbRefLastReward.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 3, fWidth, fLineHeight);
    
    _container.frame = CGRectMake(xOffset, 0, fWidth, fCellHeight);
}

@end
