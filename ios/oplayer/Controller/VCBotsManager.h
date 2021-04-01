//
//  VCBotsManager.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  机器人管理界面

#import "VCBase.h"

@interface VCBotsManager : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner fullAccountData:(id)fullAccountData;

/*
 *  (public) 计算机器人的 bots_key。
 */
+ (NSString*)calcBotsKey:(id)bots_args catalog:(NSString*)catalog account:(NSString*)account_id;

/*
 *  (public) 是否已授权服务器端处理量化交易判断。
 */
+ (BOOL)isAuthorizedToTheBotsManager:(id)latest_account_data;

@end
