package bitshares

import com.btsplusplus.fowallet.BuildConfig
import com.fowallet.walletcore.bts.ChainObjectManager
import org.json.JSONArray
import org.json.JSONObject

class SettingManager {

    companion object {
        private var _spInstanceAppCacheMgr = SettingManager()
        fun sharedSettingManager(): SettingManager {
            return _spInstanceAppCacheMgr
        }
    }

    /**
     * 服务器配置(version.json)
     */
    //    "version" => "1.0",
    //    "force" => "0",
    //    "appURL" => "",
    //    "newVersionInfo" => "",
    //    "newVersionInfoEn" => "",
    //
    //    # btspp水龙头地址
    //    "faucetURL" => "",
    //
    //    # => 动态配置wss节点（可以根据语言分别设置）
    //    "wssNodes" => {
    //        # => 默认
    //        "default" => [
    //        "wss://btsapi.magicw.net/ws",
    //        "wss://api.bts.mobi/ws",
    //        ],
    //        # => 中文单独配置
    //        "cn" => [],
    //        # => 英文单独配置
    //        "en" => [],
    //    },
    var serverConfig: JSONObject? = null

    //  链上配置数据
    private var _haveOnChainAppSettings = false                             //  是否存在链上配置数据 默认: false
    private var _onChainAppSettings = JSONObject()                          //  链上设置数据

    constructor()

    /**
     * 获取记账单位 CNY、USD 等
     */
    fun getEstimateAssetSymbol(): String {
        val settings = _load_setting_hash()
        val value = settings.optString(kSettingKey_EstimateAssetSymbol)
        //  初始化默认值（CNY）
        if (value == null || value == "") {
            val default_value = ChainObjectManager.sharedChainObjectManager().getDefaultEstimateUnitSymbol()
            settings.put(kSettingKey_EstimateAssetSymbol, default_value)
            _save_setting_hash(settings)
            return default_value
        }

        //  REMARK：如果设置界面保存的计价货币 symbol 在配置的计价列表移除了，则恢复默认值。
        val currency = ChainObjectManager.sharedChainObjectManager().getEstimateUnitBySymbol(value)
        if (currency == null) {
            val default_value = ChainObjectManager.sharedChainObjectManager().getDefaultEstimateUnitSymbol()
            settings.put(kSettingKey_EstimateAssetSymbol, default_value)
            _save_setting_hash(settings)
            return default_value
        }
        assert(currency.getString("symbol") == value)
        return value
    }

    /**
     * 获取当前主题风格
     */
    fun getThemeInfo(): JSONObject {
        //  TODO:暂不支持
        return JSONObject()
    }


    /**
     *  获取K线指标参数配置信息
     */

    fun getKLineIndexInfos(): JSONObject {
        val settings = _load_setting_hash()
        val value = settings.optJSONObject(kSettingKey_KLineIndexInfo)
        if (value == null) {
            val default_kline_index = ChainObjectManager.sharedChainObjectManager().getDefaultParameters().getJSONObject("default_kline_index")
            settings.put(kSettingKey_KLineIndexInfo, default_kline_index)
            _save_setting_hash(settings)
            return default_kline_index
        }
        return value
    }

    /**
     *  (public) 是否启用横版交易界面。
     */
    fun isEnableHorTradeUI(): Boolean {
        val settings = _load_setting_hash()
        val value = settings.optString(kSettingKey_EnableHorTradeUI)
        //  初始化默认值（NO）
        if (value.isEmpty()) {
            settings.put(kSettingKey_EnableHorTradeUI, "0")
            _save_setting_hash(settings)
            return false
        }
        return (value.toLongOrNull() ?: 0) != 0L
    }

    /**
     *  (public) 获取当前用户节点，为空则随机选择。
     */
    fun getApiNodeCurrentSelect(): JSONObject? {
        val settings = _load_setting_hash()
        val value = settings.optJSONObject(kSettingKey_ApiNode)
        return value?.optJSONObject(kSettingKey_ApiNode_Current)
    }

    fun setUseConfig(key: String, value: Any) {
        val settings = _load_setting_hash()
        settings.put(key, value)
        _save_setting_hash(settings)
    }

    fun setUseConfigBoolean(key: String, value: Boolean) {
        setUseConfig(key, if (value) "1" else "0")
    }

    fun getUseConfig(key: String): Any? {
        return _load_setting_hash().opt(key)
    }

    private fun _load_setting_hash(): JSONObject {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameUserSettingByApp)
        var settings = OrgUtils.load_file_as_json(fullname)
        if (settings == null) {
            settings = JSONObject()
        }
        return settings
    }

    private fun _save_setting_hash(setting: JSONObject) {
        val fullname = OrgUtils.makeFullPathByAppStorage(kAppCacheNameUserSettingByApp)
        OrgUtils.write_file_from_json(fullname, setting)
    }

    //  app settings on chain

    /**
     *  (public) 查询所有链上配置信息
     */
    fun queryAppSettingsOnChain(): Promise {
        if (BuildConfig.kAppOnChainSettingsAccount.isEmpty()) {
            //  链上设置账号为空
            _queryAppSettingsOnChainResponsed(null)
            return Promise._resolve(_haveOnChainAppSettings)
        } else {
            //  已定义：链上设置账号，查询链上信息。
            return ChainObjectManager.sharedChainObjectManager().queryAccountStorageInfo(BuildConfig.kAppOnChainSettingsAccount, kAppStorageCatalogAppSetings).then {
                _queryAppSettingsOnChainResponsed(it as? JSONArray)
                return@then _haveOnChainAppSettings
            }
        }
    }

    private fun _queryAppSettingsOnChainResponsed(data_array: JSONArray?) {
        _onChainAppSettings = JSONObject()

        if (data_array == null || data_array.length() <= 0) {
            _haveOnChainAppSettings = false
            return
        }

        _haveOnChainAppSettings = true
        data_array.forEach<JSONObject> { item ->
            val key = item!!.getString("key")
            _onChainAppSettings.put(key, item)
        }
    }

    /**
     *  (public) 获取APP链上设置数据
     */
    fun getOnChainAppSetting(key: String): Any? {
        if (_haveOnChainAppSettings) {
            val storage_object = _onChainAppSettings.optJSONObject(key)
            return storage_object?.opt("value")
        }
        return null
    }

    /**
     *  (public) 获取设置 - 智能币配置列表
     */
    fun getAppMainSmartAssetList(): JSONArray {
        val list = getAppCommonSettings("asset_smart_mainlist") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return ChainObjectManager.sharedChainObjectManager().getMainSmartAssetList()
    }

    /**
     *  (public) 获取设置 - 网关列表信息
     */
    fun getAppKnownGatewayList(): JSONArray {
        val list = getAppCommonSettings("gateways") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return JSONArray()
    }

    /**
     *  (public) 获取设置 - 已知网关资产发行账号列表
     */
    fun getAppKnownGatewayAccounts(): JSONArray {
        val list = getAppCommonSettings("known_gateway_accounts") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return JSONArray()
    }

    /**
     *  (public) 获取设置 - 已知交易所充值账号列表
     */
    fun getAppKnownCexDepositAccounts(): JSONArray {
        val list = getAppCommonSettings("known_cex_deposit_accounts") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return JSONArray()
    }

    /**
     *  (public) 获取设置 - 是否启用网格机器人模块
     */
    fun isAppEnableModuleGridBots(): Boolean {
        val grid_bots_trader = getAppParameters("grid_bots_trader") as? String
        if (grid_bots_trader == null || grid_bots_trader.isEmpty()) {
            return false
        }
        return true
    }

    /**
     *  (public) 获取设置 - 获取网格机器人授权账号
     */
    fun getAppGridBotsTraderAccount(): String {
        assert(isAppEnableModuleGridBots())
        return getAppParameters("grid_bots_trader") as String
    }

    /**
     *  (public) 获取设置 - 获取真锁仓挖矿的资产列表
     */
    fun getAppLockAssetList(): JSONArray {
        val list = getAppCommonSettings("lock_list") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return JSONArray()
    }

    /**
     *  (public) 获取设置 - 真锁仓挖矿条目
     */
    fun getAppAssetLockItem(asset_id: String?): JSONObject? {
        for (lock_item in getAppLockAssetList().forin<JSONObject>()) {
            if (asset_id != null && asset_id == lock_item!!.optString("asset_id")) {
                return lock_item
            }
        }
        return null
    }

    /**
     *  (public) 获取设置 - 挖矿资产列表（快速兑换列表）
     */
    fun getAppAssetMinerList(): JSONArray {
        val list = getAppCommonSettings("miner_list") as? JSONArray
        if (list != null && list.length() > 0) {
            return list
        }
        return JSONArray()
    }

    /**
     *  (public) 获取设置 - 挖矿配置条目
     */
    fun getAppAssetMinerItem(asset_id: String?): JSONObject? {
        for (miner_item in getAppAssetMinerList().forin<JSONObject>()) {
            if (asset_id != null && asset_id == miner_item!!.getJSONObject("price").getJSONObject("amount_to_sell").getString("asset_id")) {
                return miner_item
            }
        }
        return null
    }

    /**
     *  (public) 获取设置 - 读取通用配置
     */
    fun getAppCommonSettings(common_key: String): Any? {
        val common_hash = getOnChainAppSetting(kAppStorageKeyAppSetings_CommonVer01) as? JSONObject
        if (common_hash == null || common_hash.length() <= 0) {
            return null
        }
        return common_hash.opt(common_key)
    }

    /**
     *  (public) 获取设置 - 读取URL配置
     */
    fun getAppUrls(url_key: String): String? {
        val urls = getAppCommonSettings("urls") as? JSONObject
        if (urls == null || urls.length() <= 0) {
            return null
        }
        return urls.optString(url_key, null)
    }

    /**
     *  (public) 获取设置 - 读取动态参数
     */
    fun getAppParameters(parameter_key: String): Any? {
        val parameters = getAppCommonSettings("parameters") as? JSONObject
        if (parameters == null || parameters.length() <= 0) {
            return null
        }
        return parameters.opt(parameter_key)
    }

    /**
     *  (public) 获取设置 - 读取动态参数 - 是否 TRUE 判断
     */
    fun isAppParametersTrue(parameter_key: String): Boolean {
        val parameters = getAppCommonSettings("parameters") as? JSONObject
        if (parameters == null || parameters.length() <= 0) {
            return false
        }
        return parameters.isTrue(parameter_key)
    }
}