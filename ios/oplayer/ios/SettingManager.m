//
//  SettingManager.m
//  oplayer
//
//  Created by SYALON on 12/7/15.
//
//

#import "SettingManager.h"
#import "OrgUtils.h"
#import "AppCommon.h"

#import "ChainObjectManager.h"
#import "ThemeManager.h"

#import <sys/sysctl.h>

static SettingManager *_sharedSettingManager = nil;

@interface SettingManager()
{
}
@end

@implementation SettingManager

@synthesize serverConfig;

+(SettingManager *)sharedSettingManager
{
    @synchronized(self)
    {
        if(!_sharedSettingManager)
        {
            _sharedSettingManager = [[SettingManager alloc] init];
        }
        return _sharedSettingManager;
    }
}

- (BOOL)useHttpProxy
{
    SInt32 value;
    
    CFDictionaryRef dicRef = CFNetworkCopySystemProxySettings();
    if (!dicRef){
        return NO;
    }
    
    const CFNumberRef pEnableHttpProxy = (const CFNumberRef)CFDictionaryGetValue(dicRef, (const void*)kCFNetworkProxiesHTTPEnable);
    if (pEnableHttpProxy && CFNumberGetValue(pEnableHttpProxy, kCFNumberSInt32Type, &value)){
        if (value != 0){
            return YES;
        }
    }
    
    const CFStringRef pHttpProxyHostname = (const CFStringRef)CFDictionaryGetValue(dicRef, (const void*)kCFNetworkProxiesHTTPProxy);
    if (pHttpProxyHostname){
        return YES;
    }
    
    return NO;
}
- (BOOL)isDebuggerAttached {
    static BOOL debuggerIsAttached = NO;
    
    static dispatch_once_t debuggerPredicate;
    dispatch_once(&debuggerPredicate, ^{
        struct kinfo_proc info;
        size_t info_size = sizeof(info);
        int name[4];
        
        name[0] = CTL_KERN;
        name[1] = KERN_PROC;
        name[2] = KERN_PROC_PID;
        name[3] = getpid();
        
        if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
            NSLog(@"[HockeySDK] ERROR: Checking for a running debugger via sysctl() failed: %s", strerror(errno));
            debuggerIsAttached = false;
        }
        
        if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
            debuggerIsAttached = true;
    });
    
    return debuggerIsAttached;
}
- (id)init
{
    self = [super init];
    if (self)
    {
        self.serverConfig = [NSDictionary dictionary];
        _haveOnChainAppSettings = NO;
        _onChainAppSettings = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    self.serverConfig = nil;
    [_onChainAppSettings removeAllObjects];
    _onChainAppSettings = nil;
    _haveOnChainAppSettings = NO;
}

- (NSMutableDictionary*)loadSettingHash
{
    NSString* pFullPath = [OrgUtils makeFullPathByAppStorage:kAppCacheNameUserSettingByApp];
    NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:pFullPath];
    if (!settings){
        settings = [NSMutableDictionary dictionary];
    }
    return settings;
}

- (void)saveSettingHash:(NSMutableDictionary*)settings
{
    [OrgUtils writeFileAny:settings withFullPath:[OrgUtils makeFullPathByAppStorage:kAppCacheNameUserSettingByApp] withDirPath:nil];
}

/**
 *  获取记账单位 CNY、USD 等
 */
- (NSString*)getEstimateAssetSymbol
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSString* value = [settings objectForKey:kSettingKey_EstimateAssetSymbol];
    
    //  初始化默认值（CNY）
    if (!value || [value isEqualToString:@""]){
        id default_value = [[ChainObjectManager sharedChainObjectManager] getDefaultEstimateUnitSymbol];
        [settings setObject:default_value forKey:kSettingKey_EstimateAssetSymbol];
        [self saveSettingHash:settings];
        return default_value;
    }
    
    //  REMARK：如果设置界面保存的计价货币 symbol 在配置的计价列表移除了，则恢复默认值。
    id currency = [[ChainObjectManager sharedChainObjectManager] getEstimateUnitBySymbol:value];
    if (!currency){
        id default_value = [[ChainObjectManager sharedChainObjectManager] getDefaultEstimateUnitSymbol];
        [settings setObject:default_value forKey:kSettingKey_EstimateAssetSymbol];
        [self saveSettingHash:settings];
        return default_value;
    }
    
    //  返回
    assert([[currency objectForKey:@"symbol"] isEqualToString:value]);
    return value;
}

- (NSDictionary*)getThemeInfo
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_ThemeInfo];// kSettingKey_ThemeIndex
    //  初始化默认值
    if (!value){
        id themeInfo = [ThemeManager getDefaultThemeInfos];
        [settings setObject:themeInfo forKey:kSettingKey_ThemeInfo];
        [self saveSettingHash:settings];
        return themeInfo;
    }
    return value;
}

- (NSDictionary*)getKLineIndexInfos
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_KLineIndexInfo];
    //  初始化默认值
    if (!value){
        id default_kline_index = [[[ChainObjectManager sharedChainObjectManager] getDefaultParameters] objectForKey:@"default_kline_index"];
        assert(default_kline_index);
        [settings setObject:default_kline_index forKey:kSettingKey_KLineIndexInfo];
        [self saveSettingHash:settings];
        return default_kline_index;
    }
    return value;
}

/*
 *  (public) 是否启用横版交易界面。
 */
- (BOOL)isEnableHorTradeUI
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSString* value = [settings objectForKey:kSettingKey_EnableHorTradeUI];
    //  初始化默认值（NO）
    if (!value || [value isEqualToString:@""]){
        [settings setObject:@"0" forKey:kSettingKey_EnableHorTradeUI];
        [self saveSettingHash:settings];
        return NO;
    }
    return [value boolValue];
}

/*
 *  (public) 获取当前用户节点，为空则随机选择。
 */
- (NSDictionary*)getApiNodeCurrentSelect
{
    NSMutableDictionary* settings = [self loadSettingHash];
    NSDictionary* value = [settings objectForKey:kSettingKey_ApiNode];
    if (value) {
        return [value objectForKey:kSettingKey_ApiNode_Current];
    }
    return nil;
}

- (void)setUseConfig:(NSString*)key value:(BOOL)value
{
    NSMutableDictionary* settings = [self loadSettingHash];
    [settings setObject:value ? @"1" : @"0" forKey:key];
    [self saveSettingHash:settings];
}

- (void)setUseConfig:(NSString*)key obj:(id)value
{
    NSMutableDictionary* settings = [self loadSettingHash];
    [settings setObject:value forKey:key];
    [self saveSettingHash:settings];
}

- (id)getUseConfig:(NSString*)key
{
    NSMutableDictionary* settings = [self loadSettingHash];
    return [settings objectForKey:key];
}

- (NSDictionary*)getAllSetting
{
    return [[self loadSettingHash] copy];
}

#pragma mark app settings on chain

/*
 *  (public) 查询所有链上配置信息
 */
- (WsPromise*)queryAppSettingsOnChain
{
#ifdef kAppOnChainSettingsAccount
    if ([kAppOnChainSettingsAccount isEqualToString:@""]) {
        //  链上设置账号为空
        [self _queryAppSettingsOnChainResponsed:nil];
        return [WsPromise resolve:@(_haveOnChainAppSettings)];
    } else {
        //  已定义：链上设置账号，查询链上信息。
        return [[[ChainObjectManager sharedChainObjectManager] queryAccountStorageInfo:kAppOnChainSettingsAccount
                                                                               catalog:kAppStorageCatalogAppSetings] then:^id(id data_array) {
            //  account_storage_object 数组
            [self _queryAppSettingsOnChainResponsed:data_array];
            return @(_haveOnChainAppSettings);
        }];
    }
#else
    //  未定义：链上设置账号
    [self _queryAppSettingsOnChainResponsed:nil];
    return [WsPromise resolve:@(_haveOnChainAppSettings)];
#endif  //  kAppOnChainSettingsAccount
}

- (void)_queryAppSettingsOnChainResponsed:(id)data_array
{
    [_onChainAppSettings removeAllObjects];
    
    if (!data_array || [data_array count] <= 0) {
        _haveOnChainAppSettings = NO;
        return;
    }
    
    _haveOnChainAppSettings = YES;
    for (id item in data_array) {
        id key = [item objectForKey:@"key"];
        assert(key);
        [_onChainAppSettings setObject:item forKey:key];
    }
}

/*
 *  (public) 获取APP链上设置数据
 */
- (id)getOnChainAppSetting:(NSString*)key
{
    assert(key);
    if (_haveOnChainAppSettings) {
        id storage_object = [_onChainAppSettings objectForKey:key];
        if (storage_object) {
            return [storage_object objectForKey:@"value"];
        }
    }
    return nil;
}

#pragma mark- final settings

/*
 *  (public) 获取设置 - 智能币配置列表
 */
- (id)getAppMainSmartAssetList
{
    id list = [self getOnChainAppSetting:kAppStorageKeyAppSetings_AssetSmartMainList];
    if (list && [list count] > 0) {
        return list;
    }
    return [[ChainObjectManager sharedChainObjectManager] getMainSmartAssetList];
}

/*
 *  (public) 获取设置 - 已知网关资产发行账号列表
 */
- (id)getAppKnownGatewayAccounts
{
    id list = [self getOnChainAppSetting:kAppStorageKeyAppSetings_KnownGatewayAccounts];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

/*
 *  (public) 获取设置 - 已知交易所充值账号列表
 */
- (id)getAppKnownCexDepositAccounts
{
    id list = [self getOnChainAppSetting:kAppStorageKeyAppSetings_KnownCexDepositAccounts];
    if (list && [list count] > 0) {
        return list;
    }
    return @[];
}

@end
