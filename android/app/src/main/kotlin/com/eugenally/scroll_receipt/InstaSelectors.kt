package com.eugenally.scroll_receipt

/**
 * 인스타그램 화면에서 게시물/광고/추천/릴스를 알아보는 기준.
 *
 * 인스타그램 앱이 업데이트되면 화면 구조(view id, 문구)가 바뀔 수 있다.
 * 영수증 숫자가 계속 0이면 여기를 고치면 된다.
 * 플로팅 버튼을 길게 누르면 현재 화면 구조가 logcat("ScrollReceipt" 태그)에 출력된다.
 */
object InstaSelectors {
    const val PACKAGE = "com.instagram.android"

    /**
     * 피드 게시물 헤더 view id (끝부분만 비교). 게시물마다 하나씩 있고,
     * 설명(content-desc)이 "apple posted a video October 20" 처럼 게시물마다 달라 중복 판별에 쓴다.
     * 광고/추천 표시와 팔로우 버튼이 모두 이 안에 들어 있다.
     */
    val feedHeaderIds = listOf("row_feed_profile_header")

    /** 헤더 안의 작성자 이름 (헤더 설명이 비어 있을 때 대신 쓴다) */
    const val FEED_AUTHOR_ID = "row_feed_photo_profile_name"

    /** 헤더 오른쪽 ⋯ 메뉴. 이게 있어야 헤더가 다 그려진 것 (그 전엔 광고/추천 표시가 빠져 있을 수 있다) */
    const val FEED_MENU_ID = "media_option_button"

    /** 팔로우하지 않은 계정의 게시물/릴스에 붙는 "팔로우" 버튼 */
    const val FOLLOW_BUTTON_ID = "inline_follow_button"

    /** 릴스 화면의 작성자 이름 view id */
    val reelAuthorIds = listOf("clips_author_username")

    /** 광고 표시 문구 */
    val adLabels = listOf("Ad", "Sponsored", "광고", "Paid partnership", "유료 광고")

    /** 팔로우하지 않은 계정 추천 표시 문구 */
    val suggestedLabels = listOf(
        "Suggested for you", "회원님을 위한 추천", "추천 게시물", "Suggested posts",
    )

    /** 좋아요 버튼 (누르기 전 상태의 설명 문구) */
    val likeButtonDescs = listOf("Like", "좋아요")

    fun idMatches(viewId: String?, candidates: List<String>): Boolean =
        viewId != null && candidates.any { viewId.endsWith(":id/$it") }

    // ───────── 스크랩 ─────────

    /** 접힌 캡션 끝에 붙는 "더 보기" 문구 (긴 것부터) */
    private val moreLabels = listOf("… 더 보기", "... 더 보기", "… more", "... more", "...more", "더 보기", "more")

    /** 글이 아니라 버튼·표시 문구라 스크랩 후보에서 뺀다 */
    private val uiLabels = adLabels + suggestedLabels + listOf(
        "Follow", "Following", "팔로우", "팔로잉", "Reply", "답글 달기",
        "See translation", "번역 보기", "Original audio", "원본 오디오",
    )

    /** "좋아요 1,234개", "12.3K", "3일 전" 같은 숫자·시간 표시 */
    private val countOrTime = Regex(
        """^(좋아요|조회수|댓글)?\s*[\d,.]+\s*(만|천|[KkMm])?\s*(개|회|명|likes?|views?|comments?)?$""" +
            """|^\d+\s*(초|분|시간|일|주)\s*전$|^\d+\s*(seconds?|minutes?|hours?|days?|weeks?)\s+ago$""",
        RegexOption.IGNORE_CASE,
    )

    private val sentenceEnd = Regex("""(?<=[.!?。])\s+""")

    /**
     * 화면에 보이던 글(위→아래 순서)을 고를 수 있는 문장 조각으로 나눈다.
     * 피드 캡션은 "작성자 본문" 형태라 앞의 작성자 이름을 떼어 낸다.
     */
    fun scrapPieces(texts: List<String>, author: String?): List<String> = texts.asSequence()
        .map { t -> moreLabels.fold(t.trim()) { s, m -> s.removeSuffix(m).trimEnd() } }
        .map { if (author != null && it.startsWith("$author ")) it.removePrefix("$author ") else it }
        .flatMap { it.split('\n').asSequence() }
        .flatMap { it.split(sentenceEnd).asSequence() }
        .map { it.trim() }
        .filter { s -> s.length >= 2 && s.any(Char::isLetter) && s != author }
        .filter { s -> uiLabels.none { s.equals(it, ignoreCase = true) } && !countOrTime.matches(s) }
        .distinct()
        .take(60)
        .toList()
}
