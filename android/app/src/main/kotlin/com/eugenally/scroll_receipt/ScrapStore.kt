package com.eugenally.scroll_receipt

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 사용자가 직접 고른 게시물 글귀를 SharedPreferences 에 JSON 배열로 저장한다. 서버 전송 없음.
 * 사용자가 스크랩 버튼을 눌러 저장한 것만 남는다.
 */
class ScrapStore(context: Context) {
    private val prefs = context.getSharedPreferences("scraps", Context.MODE_PRIVATE)

    private fun load(): JSONArray = runCatching { JSONArray(prefs.getString(KEY, "[]")) }.getOrElse { JSONArray() }

    fun add(text: String, author: String?) {
        val arr = load()
        arr.put(JSONObject().apply {
            put("id", System.currentTimeMillis())
            put("text", text)
            put("author", author ?: JSONObject.NULL)
            put("savedAt", System.currentTimeMillis())
        })
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    /** 최근에 저장한 것부터 */
    fun all(): List<Map<String, Any?>> {
        val arr = load()
        return (arr.length() - 1 downTo 0).map { i ->
            val o = arr.getJSONObject(i)
            mapOf(
                "id" to o.getLong("id"),
                "text" to o.getString("text"),
                "author" to if (o.isNull("author")) null else o.getString("author"),
                "savedAt" to o.getLong("savedAt"),
            )
        }
    }

    fun delete(id: Long) {
        val arr = load()
        val kept = JSONArray()
        for (i in 0 until arr.length()) arr.getJSONObject(i).let { if (it.getLong("id") != id) kept.put(it) }
        prefs.edit().putString(KEY, kept.toString()).apply()
    }

    companion object {
        private const val KEY = "items"
    }
}
