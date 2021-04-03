//
//  ViewMinerRelationDataHeaderCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewMinerRelationDataHeaderCell.h"
#import "NativeAppDelegate.h"
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
    
//    ThemeManager* theme = [ThemeManager sharedThemeManager];
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat yOffset = 8.0f;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
    CGFloat fLineHeight = 24.0f;
    
    //  TODO:2.2 TOOD:2.3 TODO:3.0 lang & text
    if (_item) {
        _lbInviteAccountN.text = @"总共邀请 3 人";
        
        _lbTotal.text = @"有效邀请持有量 1001.33";
        _lbMinerLastReward.text = @"MINER锁仓挖矿收益 103NCN";
        _lbRefLastReward.text = @"MINER推荐挖矿收益 13NCN";
    } else {
        _lbInviteAccountN.text = @"总共邀请 -- 人";
        
        _lbTotal.text = @"有效邀请持有量 --";
        _lbMinerLastReward.text = @"MINER锁仓挖矿收益 -- NCN";
        _lbRefLastReward.text = @"MINER推荐挖矿收益 -- NCN";
    }
    
    _lbInviteAccountN.frame = CGRectMake(xOffset, yOffset + fLineHeight * 0, fWidth, fLineHeight);
    
    _lbTotal.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 1, fWidth, fLineHeight);
    _lbMinerLastReward.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 2, fWidth, fLineHeight);
    _lbRefLastReward.frame = CGRectMake(xOffset * 2, yOffset + fLineHeight * 3, fWidth, fLineHeight);
    
    _container.frame = CGRectMake(xOffset, 0, fWidth, fCellHeight);
}

@end
