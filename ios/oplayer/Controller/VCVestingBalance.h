//
//  VCVestingBalance.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  Vesting Balance / 待解冻金额

#import "VCBase.h"

@interface VCVestingBalance : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (id)initWithOwner:(VCBase*)owner fullAccountInfo:(NSDictionary*)accountInfo;

/**
 *  (public) 计算已经解冻的余额数量。（可提取的）
 */
+ (unsigned long long)calcVestingBalanceAmount:(id)vesting;

/**
 *  (public) query user vesting balance
 */
- (void)queryVestingBalance;

/*
 *  (public) 是否是锁仓挖矿的特殊 vesting balance 对象判断。
 */
+ (BOOL)isLockMiningVestingObject:(id)vesting;

@end
