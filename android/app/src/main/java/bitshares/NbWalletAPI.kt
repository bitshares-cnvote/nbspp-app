package bitshares

import android.app.Activity
import com.btsplusplus.fowallet.R
import com.btsplusplus.fowallet.showToast
import com.fowallet.walletcore.bts.WalletManager
import org.json.JSONObject

class NbWalletAPI {

    companion object {

        private var _spInstanceAppCacheMgr: NbWalletAPI? = null
        fun sharedNbWalletAPI(): NbWalletAPI {
            if (_spInstanceAppCacheMgr == null) {
                _spInstanceAppCacheMgr = NbWalletAPI()
            }
            return _spInstanceAppCacheMgr!!
        }

    }

    /**
     *  (public) API - 获取API地址。
     */
    fun getApiBaseAddr(): String {
        val base_url = SettingManager.sharedSettingManager().getAppUrls("nbwallet_api_base") as String
        assert(base_url.isNotEmpty())
        return base_url
    }

    /**
     *  (public) API - 登录。
     */
    fun login(ctx: Activity, bts_account_name: String, active_private_key_wif: String): Promise {
        val url = String.format("%s%s", getApiBaseAddr(), "user/validateLogin")
        val sign_args = JSONObject().apply {
            put("accountName", bts_account_name)
            put("timestamp", Utils.now_ts())
        }
        sign_args.put("signature", _sign(sign_args, active_private_key_wif))

        val p = Promise()
        _queryApiCore(ctx, url, sign_args, headers = null, is_post = true).then {
            val data = it as JSONObject
            val account_id = data.optString("account_id", null) ?: data.optString("accountId", null)
            val auth = data.optString("auth", null)
            if (account_id == null || auth == null || auth.isEmpty()) {
                p.resolve(JSONObject().apply {
                    put("error", ctx.resources.getString(R.string.kMinerApiErrServerOrNetwork))
                })
            } else {
                _saveUserTokenCookie("1.2.$account_id", token = auth)
                p.resolve(JSONObject().apply {
                    put("data", data)
                })
            }
            return@then null
        }.catch { err ->
            p.resolve(JSONObject().apply {
                put("error", err ?: "")
            })
        }
        return p
    }

    /**
     *  (public) API - 查询推荐关系。
     */
    fun queryRelation(ctx: Activity, account_id: String, is_miner: Boolean): Promise {
        val url = String.format("%s%s", getApiBaseAddr(), if (is_miner) "bonus_app/relation_miner" else "bonus_app/relation_scny")
        val args = JSONObject().apply {
            put("account_id", account_id.split(".").last().toInt())
            put("auth", _loadUserTokenCookie(account_id) ?: "")
        }

        val p = Promise()
        _queryApiCore(ctx, url, args, headers = null, is_post = false).then { data ->
            p.resolve(JSONObject().apply {
                put("data", data)
            })
            return@then null
        }.catch { err ->
            p.resolve(JSONObject().apply {
                put("error", err ?: "")
            })
        }
        return p
    }

    /**
     *  (public) API - 水龙头账号注册。
     */
    fun registerAccount(ctx: Activity, name: String, invite_account_name: String?, owner_key: String, active_key: String, memo_key: String): Promise {
        val url = String.format("%s%s", getApiBaseAddr(), "user/beingwallet_register")
        val args = JSONObject().apply {
            put("name", name)
            put("owner_key", owner_key)
            put("active_key", active_key)
            put("memo_key", memo_key)
            put("invite_key", invite_account_name
                    ?: SettingManager.sharedSettingManager().getAppParameters("default_invite_account"))

            //  unused
            put("refcode", "")
            put("referrer", "")
            put("code", "ta")   //  temp
            put("codeStr", "ta")//  temp
        }

        val p = Promise()
        _queryApiCore(ctx, url, args, headers = null, is_post = true).then { data ->
            p.resolve(JSONObject().apply {
                put("data", data)
            })
            return@then null
        }.catch { err ->
            p.resolve(JSONObject().apply {
                put("error", err ?: "")
            })
        }
        return p
    }

    /**
     *  (public) 显示错误信息。
     */
    fun showError(ctx: Activity, error: Any?) {
        var errmsg: String? = null
        if (error != null && error is Promise.WsPromiseException) {
            errmsg = error.message
        }
        if (errmsg == null || errmsg.isEmpty()) {
            errmsg = ctx.resources.getString(R.string.tip_network_error)
        }
        ctx.showToast(errmsg!!)
    }

    /**
     *  (private) 执行网络请求。
     */
    private fun _queryApiCore(ctx: Activity, url: String, args: JSONObject, headers: JSONObject? = null, is_post: Boolean): Promise {
        val request_promise = if (is_post) {
            //  POST
            OrgUtils.asyncPost_jsonBody(url, args, headers)
        } else {
            //  GET
            OrgUtils.asyncJsonGet(url, args, timeout = 3 * 1000)
        }
        //  REMARK：处理返回值
        return _handle_server_response(ctx, request_promise)
    }

    /**
     *  (private) 处理返回值。
     *  request_promise - 实际的网络请求。
     */
    private fun _handle_server_response(ctx: Activity, request_promise: Promise): Promise {
        val p = Promise()

        request_promise.then {
            if (it == null) {
                p.reject(ctx.resources.getString(R.string.kMinerApiErrServerOrNetwork))
                return@then null
            }
            if (it is JSONObject) {
                //  JSON OBJECT
                val responsed = it
                if (!responsed.has("code") || responsed.getInt("code") == 1000 || responsed.getInt("code") == 1005) {
                    p.resolve(responsed)
                } else {
                    var err = responsed.optString("msg")
                    if (err.isEmpty()) {
                        err = ctx.resources.getString(R.string.kMinerApiErrServerOrNetwork)
                    }
                    p.reject(err)
                }
            } else {
                //  JSON ARRAY or OTHER DATA TYPE
                p.resolve(it)
            }
            return@then null
        }.catch {
            p.reject(ctx.resources.getString(R.string.kMinerApiErrServerOrNetwork))
        }

        return p
    }

    /**
     *  (private) token信息管理
     */
    private fun _genUserTokenCookieName(bts_account_id: String): String {
        //  TODO:3.0 token key config
        return "_bts_nb123_token_$bts_account_id"
    }

    private fun _loadUserTokenCookie(bts_account_id: String): String? {
        return AppCacheManager.sharedAppCacheManager().getPref(_genUserTokenCookieName(bts_account_id)) as? String
    }

    private fun _delUserTokenCookie(bts_account_id: String) {
        AppCacheManager.sharedAppCacheManager().deletePref(_genUserTokenCookieName(bts_account_id)).saveCacheToFile()
    }

    private fun _saveUserTokenCookie(bts_account_id: String, token: String?) {
        if (token != null) {
            AppCacheManager.sharedAppCacheManager().setPref(_genUserTokenCookieName(bts_account_id), token).saveCacheToFile()
        }
    }

    /**
     *  (private) 生成待签名之前的完整字符串。
     */
    private fun _gen_sign_string(args: JSONObject): String {
        val keys = mutableListOf<String>()
        args.keys().forEach { keys.add(it) }
        val pArray = mutableListOf<String>()
        keys.sorted().forEach { key ->
            pArray.add("$key=${args.getString(key)}")
        }
        return pArray.joinToString(",")
    }

    /**
     *  (private) 执行签名。
     */
    private fun _sign(args: JSONObject, active_private_key_wif: String): String? {
        val sign_str = _gen_sign_string(args)

        //  签名
        val public_key = OrgUtils.genBtsAddressFromWifPrivateKey(active_private_key_wif)!!
        val signs = WalletManager.sharedWalletManager().signTransaction(sign_str.utf8String(), jsonArrayfrom(public_key), JSONObject().apply {
            put(public_key, active_private_key_wif)
        })!!

        return (signs.get(0) as ByteArray).hexEncode()
    }

}