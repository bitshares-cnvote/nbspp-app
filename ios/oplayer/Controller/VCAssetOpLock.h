//
//  VCAssetOpLock.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  资产锁仓界面

#import "VCBase.h"
#import "ViewTextFieldAmountCell.h"

@interface VCAssetOpLock : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewTextFieldAmountCellDelegate>

- (id)initWithCurrAsset:(id)curr_asset
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise;

@end
