//
//  VCMyLockList.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  我的锁仓列表（底层是vesting balance）

#import "VCBase.h"

@interface VCMyLockList : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithFullAccountInfo:(NSDictionary*)accountInfo;

/**
 *  (public) query user vesting balance
 */
- (void)queryVestingBalance;

@end
