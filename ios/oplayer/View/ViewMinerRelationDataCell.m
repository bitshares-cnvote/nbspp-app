//
//  ViewMinerRelationDataCell.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewMinerRelationDataCell.h"
#import "NativeAppDelegate.h"
#import "ThemeManager.h"
#import "OrgUtils.h"

@interface ViewMinerRelationDataCell()
{
    NSDictionary*   _item;
    
    UILabel*        _lbAccountName;
    UILabel*        _lbAmount;
    UILabel*        _lbDate;
}

@end

@implementation ViewMinerRelationDataCell

@synthesize item=_item;

- (void)dealloc
{
    _item = nil;
    
    _lbAccountName = nil;
    _lbAmount = nil;
    _lbDate = nil;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.textLabel.text = @" ";
        self.textLabel.hidden = YES;
        self.backgroundColor = [UIColor clearColor];
        
        //  TODO:fowallet font name
        _lbAccountName = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAccountName.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAccountName.textAlignment = NSTextAlignmentLeft;
        _lbAccountName.numberOfLines = 1;
        _lbAccountName.backgroundColor = [UIColor clearColor];
        _lbAccountName.font = [UIFont systemFontOfSize:13.0f];
        [self addSubview:_lbAccountName];
        
        _lbAmount = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbAmount.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbAmount.textAlignment = NSTextAlignmentCenter;
        _lbAmount.numberOfLines = 1;
        _lbAmount.backgroundColor = [UIColor clearColor];
        _lbAmount.font = [UIFont systemFontOfSize:13.0f];
        [self addSubview:_lbAmount];
        
        _lbDate = [[UILabel alloc] initWithFrame:CGRectZero];
        _lbDate.lineBreakMode = NSLineBreakByTruncatingTail;
        _lbDate.textAlignment = NSTextAlignmentRight;
        _lbDate.numberOfLines = 1;
        _lbDate.backgroundColor = [UIColor clearColor];
        _lbDate.font = [UIFont systemFontOfSize:13.0f];
        _lbDate.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_lbDate];
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
    
    CGFloat xOffset = self.textLabel.frame.origin.x;
    CGFloat fWidth = self.bounds.size.width - xOffset * 2;
    CGFloat fCellHeight = self.bounds.size.height;
    
//    if ([[_item objectForKey:@"title"] boolValue]){
//        _lbAccountName.text = @"账号";//TODO:2.2 [_item objectForKey:@"name"];
//        _lbAccountName.textColor = theme.textColorNormal;
//
//        _lbAmount.text = @"数量";
//        _lbAmount.textColor = theme.textColorNormal;
//
//        _lbDate.text = @"创建时间";
//        _lbDate.textColor = theme.textColorNormal;
//    }else{
        _lbAccountName.text = [_item objectForKey:@"account_name"];
        
        _lbAccountName.textColor = theme.textColorMain;
        
        //  TODO:asset name
        _lbAmount.text = [NSString stringWithFormat:@"%@ MINER", [_item objectForKey:@"slave_hold"]];
        _lbAmount.textColor = theme.textColorMain;
        
    _lbDate.text = @"2019-23-03 12:12:12";// [OrgUtils fmtFeedPublishDateString:[_item objectForKey:@"create_time"]];
        _lbDate.textColor = theme.textColorMain;
//    }
    
    _lbAccountName.frame = CGRectMake(xOffset, 0, fWidth * 0.3, fCellHeight);
    _lbAmount.frame = CGRectMake(xOffset + fWidth * 0.3, 0, fWidth * 0.3, fCellHeight);
    _lbDate.frame = CGRectMake(xOffset + fWidth * 0.6, 0, fWidth * 0.4, fCellHeight);
}

@end
