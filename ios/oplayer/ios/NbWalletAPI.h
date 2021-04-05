//
//  NbWalletAPI.h
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//  NB钱包推荐后台接口。

#import <Foundation/Foundation.h>
#import "WsPromise.h"

@class VCBase;

@interface NbWalletAPI : NSObject

+ (NbWalletAPI*)sharedNbWalletAPI;

/*
 *  (public) API - 登录。
 */
- (WsPromise*)login:(NSString*)bts_account_name active_private_key:(NSString*)active_private_key_wif;

/*
 *  (public) API - 查询推荐关系。
 */
- (WsPromise*)queryRelation:(NSString*)account_id is_miner:(BOOL)is_miner;

/*
 *  (public) API - 水龙头账号注册。
 */
- (WsPromise*)registerAccount:(NSString*)name
                   invite_key:(NSString*)invite_account_name
                        owner:(NSString*)owner_key
                       active:(NSString*)active_key
                         memo:(NSString*)memo_key;

/*
 *  (public) 显示错误信息。
 */
- (void)showError:(id)error;

@end
