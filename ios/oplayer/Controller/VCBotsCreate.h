//
//  VCBotsCreate.h
//  oplayer
//
//  Created by SYALON on 14-1-13.
//
//

#import "VCBase.h"

@interface VCBotsCreate : VCBase<UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, UIScrollViewDelegate>

- (id)initWithResultPromise:(WsPromiseObject*)result_promise;

@end
