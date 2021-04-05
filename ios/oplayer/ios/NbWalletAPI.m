//
//  NbWalletAPI.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "NbWalletAPI.h"
#import "OrgUtils.h"
#import "VCBase.h"

static NbWalletAPI *_sharedNbWalletAPI = nil;

@interface NbWalletAPI()
{
}
@end

@implementation NbWalletAPI

+(NbWalletAPI *)sharedNbWalletAPI
{
    @synchronized(self)
    {
        if(!_sharedNbWalletAPI)
        {
            _sharedNbWalletAPI = [[NbWalletAPI alloc] init];
        }
        return _sharedNbWalletAPI;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
}

/*
 *  (public) API - 获取API地址。
 */
- (NSString*)getApiBaseAddr
{
    id baseurl = [[SettingManager sharedSettingManager] getAppUrls:@"nbwallet_api_base"];
    assert(baseurl && ![baseurl isEqualToString:@""]);
    return baseurl;
}

/*
 *  (public) API - 登录。
 */
- (WsPromise*)login:(NSString*)bts_account_name active_private_key:(NSString*)active_private_key_wif
{
    id url = [NSString stringWithFormat:@"%@%@", [self getApiBaseAddr], @"user/validateLogin"];
    id sign_args = @{
        @"accountName":bts_account_name,
        @"timestamp":@((NSInteger)[[NSDate date] timeIntervalSince1970])
    };
    id args = [sign_args mutableCopy];
    [args setObject:[self _sign:sign_args active_private_key:active_private_key_wif] forKey:@"signature"];
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[self _queryApiCore:url args:[args copy] headers:nil is_post:YES] then:^id(id data) {
            id account_id = [data objectForKey:@"account_id"] ?: [data objectForKey:@"accountId"];
            id auth = [data objectForKey:@"auth"];
            if (!account_id || !auth || [auth isEqualToString:@""]) {
                resolve(@{@"error": NSLocalizedString(@"kMinerApiErrServerOrNetwork", @"推荐数据服务器或网络异常，请稍后再试。")});
            } else {
                [self _saveUserTokenCookie:[NSString stringWithFormat:@"1.2.%@", account_id] token:auth];
                resolve(@{@"data": data});
            }
            return nil;
        }] catch:^id(id error) {
            resolve(@{@"error": error});
            return nil;
        }];
    }];
}

/*
 *  (public) API - 查询推荐关系。
 */
- (WsPromise*)queryRelation:(NSString*)account_id is_miner:(BOOL)is_miner
{
    assert(account_id);
    id url = [NSString stringWithFormat:@"%@%@", [self getApiBaseAddr], is_miner ? @"bonus_app/relation_miner" : @"bonus_app/relation_scny"];
    id args = @{
        @"account_id":@([[[account_id componentsSeparatedByString:@"."] lastObject] integerValue]),
        @"auth":[self _loadUserTokenCookie:account_id]
    };
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[self _queryApiCore:url args:args headers:nil is_post:NO] then:^id(id data) {
            resolve(@{@"data": data});
            return nil;
        }] catch:^id(id error) {
            resolve(@{@"error": error});
            return nil;
        }];
    }];
}

/*
 *  (public) API - 水龙头账号注册。
 */
- (WsPromise*)registerAccount:(NSString*)name
                   invite_key:(NSString*)invite_account_name
                        owner:(NSString*)owner_key
                       active:(NSString*)active_key
                         memo:(NSString*)memo_key
{
    id url = [NSString stringWithFormat:@"%@%@", [self getApiBaseAddr], @"user/beingwallet_register"];
    id args = @{
        @"name":name,
        @"owner_key":owner_key,
        @"active_key":active_key,
        @"memo_key":memo_key,
        @"invite_key":invite_account_name ?: [[SettingManager sharedSettingManager] getAppParameters:@"default_invite_account"],
        //  unused
        @"refcode":@"",
        @"referrer":@"",
        @"code":@"t",       //  temp
        @"codeStr":@"t",    //  temp
    };
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[[self _queryApiCore:url args:args headers:nil is_post:YES] then:^id(id data) {
            resolve(@{@"data": data});
            return nil;
        }] catch:^id(id error) {
            resolve(@{@"error": error});
            return nil;
        }];
    }];
}

/*
 *  (public) 显示错误信息。
 */
- (void)showError:(id)error
{
    NSString* errmsg = nil;
    if (error && [error isKindOfClass:[WsPromiseException class]]){
        WsPromiseException* excp = (WsPromiseException*)error;
        errmsg = excp.reason;
    }
    if (!errmsg || [errmsg isEqualToString:@""]) {
        //  没有任何错误信息的情况
        errmsg = NSLocalizedString(@"tip_network_error", @"网络异常，请稍后再试。");
    }
    [OrgUtils makeToast:errmsg];
}

/*
 *  (private) 执行网络请求。
 */
- (WsPromise*)_queryApiCore:(NSString*)url args:(id)args headers:(id)headers is_post:(BOOL)is_post
{
    WsPromise* request_promise;
    if (is_post) {
        //  POST
        request_promise = [OrgUtils asyncPostUrl_jsonBody:url args:args headers:headers as_json:YES];
    } else {
        //  GET
        NSMutableArray* pArray = [[NSMutableArray alloc] init];
        if (args && [args count] > 0) {
            for (NSString* pKey in [args allKeys]) {
                NSString* pValue = [args objectForKey:pKey];
                [pArray addObject:[NSString stringWithFormat:@"%@=%@", pKey, pValue]];
            }
            url = [NSString stringWithFormat:@"%@?%@", url, [pArray componentsJoinedByString:@"&"]];
        }
        request_promise = [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
            [OrgUtils asyncFetchJson:url
                             timeout:[[NativeAppDelegate sharedAppDelegate] getRequestTimeout]
                     completionBlock:^(id json_array)
             {
                resolve(json_array);
            }];
        }];
    }
    //  REMARK：处理返回值
    return [self _handle_server_response:request_promise];
}

/*
 *  (private) 处理返回值。
 *  request_promise - 实际的网络请求。
 */
- (WsPromise*)_handle_server_response:(WsPromise*)request_promise
{
    assert(request_promise);
    return [WsPromise promise:^(WsResolveHandler resolve, WsRejectHandler reject) {
        [[request_promise then:^id(id responsed) {
            if (!responsed) {
                reject(NSLocalizedString(@"kMinerApiErrServerOrNetwork", @"推荐数据服务器或网络异常，请稍后再试。"));
                return nil;
            }
            if ([responsed isKindOfClass:[NSDictionary class]]) {
                //  JSON OBJECT
                id code = [responsed objectForKey:@"code"];
                //  TODO:fuck code  1000,201都算成功，201有warning提示
                if (!code || [code integerValue] == 1000 || [code integerValue] == 1005) {
                    resolve(responsed);
                } else {
                    id err = [responsed objectForKey:@"msg"];
                    if (!err || [err isEqualToString:@""]) {
                        err = NSLocalizedString(@"kMinerApiErrServerOrNetwork", @"推荐数据服务器或网络异常，请稍后再试。");
                    }
                    reject(err);
                }
            } else {
                //  JSON ARRAY or OTHER DATA TYPE
                resolve(responsed);
            }
            return nil;
        }] catch:^id(id error) {
            reject(NSLocalizedString(@"kMinerApiErrServerOrNetwork", @"推荐数据服务器或网络异常，请稍后再试。"));
            return nil;
        }];
    }];
}

/*
 *  (private) token信息管理
 */
- (NSString*)_genUserTokenCookieName:(NSString*)bts_account_id
{
    assert(bts_account_id);
    //  TODO:3.0 token key config
    return [NSString stringWithFormat:@"_bts_nb123_token_%@", bts_account_id];
}

- (NSString*)_loadUserTokenCookie:(NSString*)bts_account_id
{
    return (NSString*)[[AppCacheManager sharedAppCacheManager] getPref:[self _genUserTokenCookieName:bts_account_id]] ?: @"";
}

- (void)_delUserTokenCookie:(NSString*)bts_account_id
{
    [[[AppCacheManager sharedAppCacheManager] deletePref:[self _genUserTokenCookieName:bts_account_id]] saveCacheToFile];
}

- (void)_saveUserTokenCookie:(NSString*)bts_account_id token:(NSString*)token
{
    if (token) {
        [[[AppCacheManager sharedAppCacheManager] setPref:[self _genUserTokenCookieName:bts_account_id] value:token] saveCacheToFile];
    }
}

/*
 *  (private) 生成待签名之前的完整字符串。
 */
- (NSString*)_gen_sign_string:(NSDictionary*)args
{
    NSArray* sortedKeys = [[args allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    NSMutableArray* pArray = [[NSMutableArray alloc] init];
    for (NSString* pKey in sortedKeys) {
        NSString* pValue = [args objectForKey:pKey];
        [pArray addObject:[NSString stringWithFormat:@"%@=%@", pKey, pValue]];
    }
    return [pArray componentsJoinedByString:@","];
}

/*
 *  (private) 执行签名。
 */
- (NSString*)_sign:(id)args active_private_key:(NSString*)active_private_key_wif
{
    //  获取待签名字符串
    NSString* sign_str = [self _gen_sign_string:args];
    NSData* sign_data = [sign_str dataUsingEncoding:NSUTF8StringEncoding];
    
    //  签名
    NSString* public_key = [OrgUtils genBtsAddressFromWifPrivateKey:active_private_key_wif];
    assert(public_key);
    id signs = [[WalletManager sharedWalletManager] signTransaction:sign_data
                                                           signKeys:@[public_key]
                                                         extra_keys:@{public_key:active_private_key_wif}];
    assert(signs);
    
    return [[signs firstObject] hex_encode];
}

@end
