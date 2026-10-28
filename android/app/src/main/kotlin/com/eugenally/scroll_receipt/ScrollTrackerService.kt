package com.eugenally.scroll_receipt

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Rect
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * 인스타그램을 보는 동안 게시물/광고/추천/릴스/스크롤 거리/좋아요를 센다.
 * 화면 글자를 서버로 보내지 않고, 개수만 폰에 저장한다.
 */
class ScrollTrackerService : AccessibilityService() {

    private lateinit var store: StatsStore
    private lateinit var bubble: FloatingBubble
    private lateinit var miniReceipt: MiniReceipt
    private lateinit var scrapSheet: ScrapSheet
    private var inInstagram = false
    private var lastScanAt = 0L
    private var lastTouchAt = 0L
    private var lastReelAuthor: String? = null

    /** seen 이 어느 날짜의 기록인지. 날이 바뀌면 비운다 */
    private var countedDay = ""

    /** 이미 센 게시물 → 그때 분류 (같은 게시물을 스크롤로 오가며 여러 번 세지 않도록) */
    private val seen = object : LinkedHashMap<String, String>() {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?) = size > 400
    }

    private val screenOff = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, i: Intent?) = leaveInstagram()
    }

    override fun onServiceConnected() {
        store = StatsStore(this)
        store.endStaleSession()
        miniReceipt = MiniReceipt(this, store, onOpenFull = ::openReceipt, onScrap = ::openScrap)
        scrapSheet = ScrapSheet(this, ScrapStore(this))
        bubble = FloatingBubble(this, onTap = { miniReceipt.toggle() }, onLongPress = ::dumpTree)
        registerReceiver(screenOff, IntentFilter(Intent.ACTION_SCREEN_OFF))
        instance = this
    }

    override fun onDestroy() {
        instance = null
        runCatching { unregisterReceiver(screenOff) }
        leaveInstagram()
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(e: AccessibilityEvent) {
        val pkg = e.packageName?.toString() ?: return

        if (e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            when {
                pkg == InstaSelectors.PACKAGE -> enterInstagram()
                isIgnorable(pkg) -> {}          // 상단바, 키보드 등은 무시
                // 버튼·미니 영수증 같은 우리 오버레이 창은 인스타 위에 뜬 것. 전체 영수증 화면만 이탈로 본다
                pkg == packageName && e.className != MainActivity::class.java.name -> {}
                else -> leaveInstagram()        // 다른 앱 (영수증 화면 포함)
            }
        }
        if (pkg != InstaSelectors.PACKAGE) return
        // 앱 업데이트 등으로 인스타그램이 이미 떠 있는 상태에서 연결되면 화면 전환 이벤트가 오지 않는다
        if (!inInstagram && rootInActiveWindow?.packageName == InstaSelectors.PACKAGE) enterInstagram()
        if (inInstagram) keepAlive()

        when (e.eventType) {
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                addScrollDistance(e)
                scanThrottled()
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> scanThrottled()
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                val desc = e.contentDescription?.toString() ?: e.text.joinToString()
                if (InstaSelectors.likeButtonDescs.any { desc.equals(it, ignoreCase = true) }) {
                    store.add("likes")
                }
            }
        }
    }

    // ───────── 세션 / 버튼 ─────────

    private fun enterInstagram() {
        if (inInstagram) return
        inInstagram = true
        store.startSession()
        bubble.show()
        refreshBubble()
    }

    private fun leaveInstagram() {
        if (!inInstagram) return
        inInstagram = false
        store.endSession()
        if (::miniReceipt.isInitialized) miniReceipt.hide()
        if (::scrapSheet.isInitialized) scrapSheet.hide()
        if (::bubble.isInitialized) bubble.hide()
    }

    /** 몇 초에 한 번: 마지막 활동 시각을 남기고, 날이 바뀌었으면 게시물 중복 기록을 비운다 */
    private fun keepAlive() {
        val now = SystemClock.uptimeMillis()
        if (now - lastTouchAt < 5000) return
        lastTouchAt = now
        store.touch()
        val day = store.dayKey()
        if (day != countedDay) {
            countedDay = day
            seen.clear()
            lastReelAuthor = null
            refreshBubble()
        }
    }

    private fun refreshBubble() = bubble.update(store.meters(), store.count("ads"))

    private fun isIgnorable(pkg: String) =
        pkg == "com.android.systemui" ||
            pkg.contains("inputmethod") ||
            pkg.contains("keyboard") ||
            pkg.contains("honeyboard")   // 삼성 키보드

    private fun openReceipt() {
        startActivity(
            Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_FROM_BUBBLE, true)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
        )
    }

    // ───────── 스크롤 거리 ─────────

    private fun addScrollDistance(e: AccessibilityEvent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return
        val dy = kotlin.math.abs(e.scrollDeltaY)
        if (dy <= 0 || dy > 5000) return   // 이상값 무시
        val dm = resources.displayMetrics
        val ydpi = if (dm.ydpi > 100) dm.ydpi else dm.densityDpi.toFloat()
        val meters = dy / ydpi * 0.0254    // px → inch → m
        store.addMeters(meters)
        refreshBubble()
    }

    // ───────── 게시물 분류 ─────────

    private fun scanThrottled() {
        val now = SystemClock.uptimeMillis()
        if (now - lastScanAt < 350) return
        lastScanAt = now
        val root = rootInActiveWindow ?: return
        scan(root)
    }

    private fun scan(root: AccessibilityNodeInfo) {
        walk(root, depth = 0) { node ->
            val id = node.viewIdResourceName
            when {
                // 미리 불러온 화면 밖 게시물·옆 릴스도 트리에 있다. 실제로 보이는 것만 센다
                !node.isVisibleToUser -> {}
                InstaSelectors.idMatches(id, InstaSelectors.feedHeaderIds) -> classifyFeedPost(node)
                InstaSelectors.idMatches(id, InstaSelectors.reelAuthorIds) -> classifyReel(node, root)
            }
        }
    }

    /** 게시물 헤더 안의 표시만 보고 분류한다. 헤더 밖을 보면 화면의 다른 게시물 표시까지 섞인다 */
    private fun classifyFeedPost(header: AccessibilityNodeInfo) {
        if (findById(header, InstaSelectors.FEED_MENU_ID) == null) return   // 아직 그리는 중. 다음 스캔에서 센다
        val post = header.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            ?: findById(header, InstaSelectors.FEED_AUTHOR_ID)?.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            ?: return
        val texts = collectTexts(header, maxDepth = 4)
        val kind = when {
            texts.any { t -> InstaSelectors.adLabels.any { t.equals(it, true) } } -> "ads"
            texts.any { t -> InstaSelectors.suggestedLabels.any { t.equals(it, true) } } -> "suggestedPosts"
            findById(header, InstaSelectors.FOLLOW_BUTTON_ID) != null -> "suggestedPosts"
            else -> "friendPosts"
        }
        val before = seen[post]
        // 광고/추천 표시는 헤더보다 늦게 뜰 때가 있다. 친구 게시물로 셌던 것만 옮겨 센다
        if (before == kind || (before != null && before != "friendPosts")) return
        seen[post] = kind
        before?.let { store.add(it, -1) }
        store.add(kind)
        if (kind == "ads") refreshBubble()
    }

    private fun classifyReel(authorNode: AccessibilityNodeInfo, root: AccessibilityNodeInfo) {
        val author = authorNode.text?.toString()?.trim()?.takeIf { it.isNotEmpty() } ?: return
        if (author == lastReelAuthor) return
        lastReelAuthor = author
        // 릴스 광고 표시는 작성자 옆이 아니라 화면 아래쪽에 따로 뜬다. 지금 보이는 화면 전체에서 찾는다
        var isAd = false
        walk(root, depth = 0) { n ->
            if (!isAd && n.isVisibleToUser) {
                val t = n.text?.toString()?.trim()
                isAd = t != null && InstaSelectors.adLabels.any { t.equals(it, true) }
            }
        }
        store.add(if (isAd) "ads" else "reels")
        if (isAd) refreshBubble()
    }

    // ───────── 스크랩 ─────────

    /**
     * 미니 영수증의 스크랩 버튼을 누른 순간 화면에 보이던 글을 모아 스크랩 창을 띄운다.
     * 사용자가 누를 때 한 번만 읽고, 사용자가 고른 문장만 폰에 저장한다.
     */
    private fun openScrap() {
        val root = rootInActiveWindow
        if (root?.packageName != InstaSelectors.PACKAGE) {
            android.widget.Toast.makeText(this, "인스타그램 화면에서 눌러 주세요", android.widget.Toast.LENGTH_SHORT).show()
            return
        }
        val mid = resources.displayMetrics.heightPixels / 2
        val texts = mutableListOf<Pair<Rect, String>>()
        val authors = mutableListOf<Pair<Int, String>>()
        walk(root, depth = 0) { n ->
            if (!n.isVisibleToUser || n.isEditable) return@walk   // 댓글 입력칸은 뺀다
            val t = n.text?.toString()?.trim()?.takeIf { it.isNotEmpty() } ?: return@walk
            val r = Rect().also(n::getBoundsInScreen)
            texts += r to t
            val id = n.viewIdResourceName
            if (id?.endsWith(":id/${InstaSelectors.FEED_AUTHOR_ID}") == true ||
                InstaSelectors.idMatches(id, InstaSelectors.reelAuthorIds)
            ) authors += r.top to t
        }
        // 화면 가운데를 차지한 게시물의 작성자: 가운데보다 위에 있는 작성자 중 가장 아래 것
        val author = authors.filter { it.first <= mid }.maxByOrNull { it.first }?.second
            ?: authors.minByOrNull { it.first }?.second
        val ordered = texts.sortedWith(compareBy({ it.first.top }, { it.first.left })).map { it.second }
        scrapSheet.show(InstaSelectors.scrapPieces(ordered, author), author)
    }

    // ───────── 트리 유틸 ─────────

    private fun walk(n: AccessibilityNodeInfo, depth: Int, f: (AccessibilityNodeInfo) -> Unit) {
        if (depth > 40) return
        f(n)
        for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1, f) }
    }

    /** n 아래(자신 포함)에서 view id 가 ":id/$id" 로 끝나는 첫 노드 */
    private fun findById(n: AccessibilityNodeInfo, id: String, depth: Int = 0): AccessibilityNodeInfo? {
        if (n.viewIdResourceName?.endsWith(":id/$id") == true) return n
        if (depth > 6) return null
        for (i in 0 until n.childCount) {
            n.getChild(i)?.let { c -> findById(c, id, depth + 1)?.let { return it } }
        }
        return null
    }

    private fun collectTexts(n: AccessibilityNodeInfo, maxDepth: Int): List<String> {
        val out = mutableListOf<String>()
        fun go(x: AccessibilityNodeInfo, d: Int) {
            x.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let(out::add)
            x.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let(out::add)
            if (d < maxDepth) for (i in 0 until x.childCount) x.getChild(i)?.let { go(it, d + 1) }
        }
        go(n, 0)
        return out
    }

    /** 버튼을 길게 누르면 현재 화면 구조를 logcat 에 출력 (InstaSelectors 조정용) */
    private fun dumpTree() {
        val root = rootInActiveWindow ?: return
        Log.d(TAG, "===== view tree dump =====")
        fun go(x: AccessibilityNodeInfo, d: Int) {
            if (d > 30) return
            Log.d(TAG, "  ".repeat(d) + "${x.className} id=${x.viewIdResourceName} " +
                "text=${x.text} desc=${x.contentDescription}")
            for (i in 0 until x.childCount) x.getChild(i)?.let { go(it, d + 1) }
        }
        go(root, 0)
        android.widget.Toast.makeText(this, "화면 구조를 logcat에 출력했어요", android.widget.Toast.LENGTH_SHORT).show()
    }

    companion object {
        const val TAG = "ScrollReceipt"
        var instance: ScrollTrackerService? = null
    }
}
