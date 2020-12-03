package com.btsplusplus.fowallet

import android.os.Bundle
import android.os.Handler
import android.os.Message
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import bitshares.*
import com.fowallet.walletcore.bts.ChainObjectManager
import com.sunfusheng.marqueeview.MarqueeView
import kotlinx.android.synthetic.main.activity_index_markets.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.*
import kotlin.collections.ArrayList

class ActivityIndexMarkets : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()

    private var _tickerRefreshTimer: Timer? = null
    private var _notify_handler: Handler? = null
    private var _viewAppNotice: MarqueeView<String>? = null
    private var _currAppNotice: JSONArray? = null

    /**
     * 重载 - 返回键按下
     */
    override fun onBackPressed() {
        goHome()
    }

    //  事件：将要进入后台
    override fun onPause() {
        _notify_handler?.let { handler -> NotificationCenter.sharedNotificationCenter().removeObserver(kBtsSubAppAnnouncementNewData, handler) }
        super.onPause()
        //  停止计时器
        stopTickerRefreshTimer()
        //  处理逻辑
        AppCacheManager.sharedAppCacheManager().saveToFile()
    }

    //  事件：已经进入前台
    override fun onResume() {
        super.onResume()
        _notify_handler?.let { handler -> NotificationCenter.sharedNotificationCenter().addObserver(kBtsSubAppAnnouncementNewData, handler) }
        //  回到前台检测是否需要重新连接。
        GrapheneConnectionManager.sharedGrapheneConnectionManager().reconnect_all()
        //  自选市场可能发生变化，重新加载。
        onRefreshFavoritesMarket()
        //  添加Ticker刷新定时器
        startTickerRefreshTimer()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAutoLayoutContentView(R.layout.activity_index_markets, navigationBarColor = R.color.theme01_tabBarColor)

        //  动态初始化TabItem
        findViewById<TabLayout>(R.id.tablayout).let { tab ->
            tab.addTab(tab.newTab().apply {
                text = resources.getString(R.string.kLabelMarketFavorites)
            })
            ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos().forEach { market ->
                tab.addTab(tab.newTab().apply {
                    text = market.getJSONObject("base").getString("name")
                })
            }
        }

        //  初始化公告
        val latestAppAnnouncement = ScheduleManager.sharedScheduleManager().latestAppAnnouncement
        if (latestAppAnnouncement != null) {
            findViewById<LinearLayout>(R.id.layout_app_announcement).visibility = View.VISIBLE

            _viewAppNotice = findViewById(R.id.tv_app_announcement_title)

            refreshAppAnnouncementMessage(latestAppAnnouncement)

            //  公告 点击事件
            _viewAppNotice!!.setOnItemClickListener { position, _ ->
                val url = _currAppNotice?.optJSONObject(position)?.optString("url", null)
                if (url != null && url.isNotEmpty()) {
                    openURL(url)
                }
            }

            //  监听：新的公告
            _notify_handler = object : Handler() {
                override fun handleMessage(msg: Message?) {
                    super.handleMessage(msg)
                    if (msg != null) {
                        onSubAppAnnouncementNewData(msg)
                    }
                }
            }
        } else {
            findViewById<LinearLayout>(R.id.layout_app_announcement).visibility = View.GONE
        }

        //  设置 fragment
        setFragments()
        setViewPager(1, R.id.view_pager, R.id.tablayout, fragmens)
        setTabListener(R.id.tablayout, R.id.view_pager)

        // 监听 + 按钮事件
        setAddBtnListener()

        // 设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        // 设置底部导航栏样式
        setBottomNavigationStyle(0)
    }

    /**
     *  刷新公告信息
     */
    private fun refreshAppAnnouncementMessage(data: JSONArray?) {
        val messages = ArrayList<String>()
        _currAppNotice = data
        _currAppNotice?.forEach<JSONObject> {
            messages.add(it!!.getString("title"))
        }
        _viewAppNotice?.startWithList(messages)
    }

    /**
     * 接收到订阅消息
     */
    private fun onSubAppAnnouncementNewData(msg: Message) {
        val userinfo = msg.obj as? JSONObject
        val data = userinfo?.optJSONArray("data")
        if (data == null || data.length() <= 0) {
            return
        }
        refreshAppAnnouncementMessage(data)
    }

    /**
     * 启动定时器：刷新Ticker数据用
     */
    private fun startTickerRefreshTimer() {
        if (_tickerRefreshTimer == null) {
            _tickerRefreshTimer = Timer()
            _tickerRefreshTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    delay_main {
                        onTimerTickerRefresh()
                    }
                }
            }, 300, 1000)
        }
    }

    /**
     * 停止定时器
     */
    private fun stopTickerRefreshTimer() {
        if (_tickerRefreshTimer != null) {
            _tickerRefreshTimer!!.cancel()
            _tickerRefreshTimer = null
        }
    }

    /**
     * 定时器 tick 执行逻辑
     */
    private fun onTimerTickerRefresh() {
        if (TempManager.sharedTempManager().tickerDataDirty) {
            TempManager.sharedTempManager().tickerDataDirty = false
            for (fragment in fragmens) {
                val fr = fragment as FragmentMarketInfo
                fr.onRefreshTickerData()
            }
        }
    }

    /**
     *  (private) 事件 - 刷新自选(关注、收藏)市场
     */
    private fun onRefreshFavoritesMarket() {
        if (TempManager.sharedTempManager().favoritesMarketDirty) {
            //  重新构建各市场分组信息
            ChainObjectManager.sharedChainObjectManager().buildAllMarketsInfos()
            //  清除标记
            TempManager.sharedTempManager().favoritesMarketDirty = false
            //  刷新
            for (fragment in fragmens) {
                val fr = fragment as FragmentMarketInfo
                fr.onRefreshFavoritesMarket()
            }
            //  自定义交易对发生变化，重新刷新ticker更新任务。
            ScheduleManager.sharedScheduleManager().autoRefreshTickerScheduleByMergedMarketInfos()
        }
    }

//    fun getTitleStringArray(): MutableList<String> {
//        var ary = mutableListOf<String>(resources.getString(R.string.kLabelMarketFavorites))
//        ary.addAll(ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos().map { market: JSONObject ->
//            market.getJSONObject("base").getString("name")
//        })
//        return ary
//    }
//
//    fun getTitleDefaultSelectedIndex(): Int {
//        //  REMARK：默认选中第二个市场（第一个是自选市场）
//        return 2
//    }

    private fun setAddBtnListener() {
        button_add.setOnClickListener { goTo(ActivityTradingPairMgr::class.java, true) }
    }

    private fun setFragments() {
        //  REMARK：marketInfo 参数为 nil，说明为自选市场。
        fragmens.add(FragmentMarketInfo().initialize(null))
        //  非自选市场
        ChainObjectManager.sharedChainObjectManager().getMergedMarketInfos().forEach { market: JSONObject ->
            fragmens.add(FragmentMarketInfo().initialize(market))
        }
    }

}

