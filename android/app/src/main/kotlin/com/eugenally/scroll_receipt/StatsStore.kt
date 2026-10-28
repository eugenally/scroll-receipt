package com.eugenally.scroll_receipt

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 하루치 기록을 SharedPreferences 에 저장한다. 서버 전송 없음.
 * 키 형식: "2026-10-28.ads" 처럼 날짜 + 항목.
 */
class StatsStore(context: Context) {
    private val prefs = context.getSharedPreferences("scroll_receipt", Context.MODE_PRIVATE)

    private fun dayStr(ms: Long) = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(ms))
    private fun todayStr() = dayStr(System.currentTimeMillis())
    private fun key(name: String) = "${todayStr()}.$name"

    /** 오늘 날짜 ("2026-10-28"). 날이 바뀌었는지 확인할 때 쓴다 */
    fun dayKey() = todayStr()

    private fun startOfDay(ms: Long): Long = Calendar.getInstance().apply {
        timeInMillis = ms
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun nextMidnight(ms: Long): Long = Calendar.getInstance().apply {
        timeInMillis = startOfDay(ms)
        add(Calendar.DAY_OF_MONTH, 1)
    }.timeInMillis

    fun add(name: String, n: Int = 1) {
        prefs.edit().putInt(key(name), prefs.getInt(key(name), 0) + n).apply()
    }

    fun addMeters(m: Double) {
        val k = key("scrollMm")
        prefs.edit().putLong(k, prefs.getLong(k, 0) + (m * 1000).toLong()).apply()
    }

    fun count(name: String): Int = prefs.getInt(key(name), 0)

    fun meters(): Double = prefs.getLong(key("scrollMm"), 0) / 1000.0

    // ── 이용 시간: 세션 시작 시각을 저장해 두고, 끝날 때 날짜별로 누적 ──
    fun startSession() {
        if (prefs.getLong("sessionStart", 0) == 0L) {
            val now = System.currentTimeMillis()
            prefs.edit().putLong("sessionStart", now).putLong("lastActive", now).apply()
        }
    }

    /** 인스타그램에서 활동이 있을 때 (몇 초에 한 번) 마지막 활동 시각을 남긴다 */
    fun touch() {
        prefs.edit().putLong("lastActive", System.currentTimeMillis()).apply()
    }

    /** 세션을 끝내고 이용 시간을 쌓는다. 자정을 넘긴 세션은 날짜별로 나눠 쌓는다 */
    fun endSession(end: Long = System.currentTimeMillis()) {
        var start = prefs.getLong("sessionStart", 0)
        if (start == 0L) return
        val e = prefs.edit()
        while (start < end) {
            val cut = minOf(nextMidnight(start), end)
            val k = "${dayStr(start)}.usageMs"
            e.putLong(k, prefs.getLong(k, 0) + (cut - start))
            start = cut
        }
        e.putLong("sessionStart", 0).apply()
    }

    /**
     * 서비스가 인스타그램을 보던 중에 죽으면 세션 시작 시각만 남는다.
     * 다음에 연결될 때 마지막 활동 시각에서 그 세션을 끝내, 그 사이 시간이 쌓이지 않게 한다.
     */
    fun endStaleSession() {
        val start = prefs.getLong("sessionStart", 0)
        if (start == 0L) return
        endSession(end = maxOf(start, prefs.getLong("lastActive", start)))
    }

    fun usageMs(): Long {
        val start = prefs.getLong("sessionStart", 0)
        val now = System.currentTimeMillis()
        // 진행 중인 세션은 오늘 0시 이후 부분만 오늘 이용 시간에 더한다
        val live = if (start == 0L) 0 else now - maxOf(start, startOfDay(now))
        return prefs.getLong(key("usageMs"), 0) + live
    }

    fun today(): Map<String, Any> = mapOf(
        "date" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date()),
        "usageMs" to usageMs(),
        "scrollMeters" to meters(),
        "friendPosts" to count("friendPosts"),
        "suggestedPosts" to count("suggestedPosts"),
        "ads" to count("ads"),
        "reels" to count("reels"),
        "likes" to count("likes"),
    )

    fun resetToday() {
        val prefix = "${todayStr()}."
        val e = prefs.edit()
        prefs.all.keys.filter { it.startsWith(prefix) }.forEach { e.remove(it) }
        e.putLong("sessionStart", 0).apply()
    }
}
