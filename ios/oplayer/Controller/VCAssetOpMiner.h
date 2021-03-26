//
//  VCAssetOpMiner.h
//  oplayer
//
//  Created by SYALON on 13-10-23.
//
//  一键挖矿/退出挖矿

#import "VCBase.h"
#import "ViewTextFieldAmountCell.h"

@interface VCAssetOpMiner : VCBase<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, ViewTextFieldAmountCellDelegate>

- (id)initWithMinerItem:(id)miner_item
      full_account_data:(id)full_account_data
         result_promise:(WsPromiseObject*)result_promise;

@end
