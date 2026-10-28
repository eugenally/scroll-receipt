package com.eugenally.scroll_receipt

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
    private var inInstagram = false
    private var lastScanAt = 0L
    private var lastReelAuthor: String? = null

    /** 이미 센 게시물 (같은 게시물을 스크롤로 오가며 여러 번 세지 않도록) */
    private val seen = object : LinkedHashSet<String>() {
        fun addBounded(k: String): Boolean {
            val added = add(k)
            if (size > 400) remove(first())
            return added
        }
    }

    private val screenOff = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, i: Intent?) = leaveInstagram()
    }

    override fun onServiceConnected() {
        store = StatsStore(this)
        bubble = FloatingBubble(this, onTap = ::openReceipt, onLongPress = ::dumpTree)
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
                else -> leaveInstagram()        // 다른 앱 (영수증 화면 포함)
            }
        }
        if (pkg != InstaSelectors.PACKAGE) return

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
        bubble.update(store.meters())
    }

    private fun leaveInstagram() {
        if (!inInstagram) return
        inInstagram = false
        store.endSession()
        if (::bubble.isInitialized) bubble.hide()
    }

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
        bubble.update(store.meters())
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
                InstaSelectors.idMatches(id, InstaSelectors.feedAuthorIds) -> classifyFeedPost(node)
                InstaSelectors.idMatches(id, InstaSelectors.reelAuthorIds) -> classifyReel(node)
            }
        }
    }

    private fun classifyFeedPost(authorNode: AccessibilityNodeInfo) {
        val author = authorNode.text?.toString() ?: authorNode.contentDescription?.toString() ?: return
        // 작성자 이름 주변(헤더 영역)의 글자들을 모아서 광고/추천 표시를 찾는다
        val header = authorNode.parent?.parent ?: authorNode.parent ?: return
        val texts = collectTexts(header, maxDepth = 4)
        val kind = when {
            texts.any { t -> InstaSelectors.adLabels.any { t.equals(it, true) } } -> "ads"
            texts.any { t -> InstaSelectors.suggestedLabels.any { t.equals(it, true) } } -> "suggestedPosts"
            else -> "friendPosts"
        }
        if (seen.addBounded("feed|$author|$kind")) store.add(kind)
    }

    private fun classifyReel(authorNode: AccessibilityNodeInfo) {
        val author = authorNode.text?.toString() ?: authorNode.contentDescription?.toString() ?: return
        if (author == lastReelAuthor) return
        lastReelAuthor = author
        val container = authorNode.parent?.parent ?: authorNode
        val texts = collectTexts(container, maxDepth = 4)
        val isAd = texts.any { t -> InstaSelectors.adLabels.any { t.equals(it, true) } }
        store.add(if (isAd) "ads" else "reels")
    }

    // ───────── 트리 유틸 ─────────

    private fun walk(n: AccessibilityNodeInfo, depth: Int, f: (AccessibilityNodeInfo) -> Unit) {
        if (depth > 40) return
        f(n)
        for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1, f) }
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
