package com.eugenally.scroll_receipt

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 하루치 기록을 SharedPreferences 에 저장한다. 서버 전송 없음.
 * 키 형식: "2026-10-28.ads" 처럼 날짜 + 항목.
 */
class StatsStore(context: Context) {
    private val prefs = context.getSharedPreferences("scroll_receipt", Context.MODE_PRIVATE)

    private fun todayStr() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    private fun key(name: String) = "${todayStr()}.$name"

    fun add(name: String, n: Int = 1) {
        prefs.edit().putInt(key(name), prefs.getInt(key(name), 0) + n).apply()
    }

    fun addMeters(m: Double) {
        val k = key("scrollMm")
        prefs.edit().putLong(k, prefs.getLong(k, 0) + (m * 1000).toLong()).apply()
    }

    fun count(name: String): Int = prefs.getInt(key(name), 0)

    fun meters(): Double = prefs.getLong(key("scrollMm"), 0) / 1000.0

    // ── 이용 시간: 세션 시작 시각을 저장해 두고, 끝날 때 누적 ──
    fun startSession() {
        if (prefs.getLong("sessionStart", 0) == 0L) {
            prefs.edit().putLong("sessionStart", System.currentTimeMillis()).apply()
        }
    }

    fun endSession() {
        val start = prefs.getLong("sessionStart", 0)
        if (start == 0L) return
        val k = key("usageMs")
        prefs.edit()
            .putLong(k, prefs.getLong(k, 0) + (System.currentTimeMillis() - start))
            .putLong("sessionStart", 0)
            .apply()
    }

    fun usageMs(): Long {
        val start = prefs.getLong("sessionStart", 0)
        val live = if (start == 0L) 0 else System.currentTimeMillis() - start
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
