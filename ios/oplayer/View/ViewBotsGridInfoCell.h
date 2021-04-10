//
//  ViewBotsGridInfoCell.h
//  oplayer
//
//  Created by SYALON on 13-12-28.
//
//

#import <UIKit/UIKit.h>
#import "UITableViewCellBase.h"

@interface ViewBotsGridInfoCell : UITableViewCellBase

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, strong) NSDictionary* item;
@property (nonatomic, strong) NSDictionary* ticker_data_hash;
@property (nonatomic, strong) NSDictionary* balance_hash;

@end
