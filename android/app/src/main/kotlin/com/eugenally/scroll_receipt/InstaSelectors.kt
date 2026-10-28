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

    /** 피드 게시물 상단의 작성자 이름 view id (끝부분만 비교) */
    val feedAuthorIds = listOf(
        "row_feed_photo_profile_name",
        "row_feed_profile_header",
    )

    /** 릴스 화면의 작성자 이름 view id */
    val reelAuthorIds = listOf(
        "clips_author_username",
        "clips_author_info_component",
    )

    /** 광고 표시 문구 */
    val adLabels = listOf("Sponsored", "광고", "Paid partnership", "유료 광고")

    /** 팔로우하지 않은 계정 추천 표시 문구 */
    val suggestedLabels = listOf(
        "Suggested for you", "회원님을 위한 추천", "추천 게시물", "Suggested posts", "팔로우", "Follow",
    )

    /** 좋아요 버튼 (누르기 전 상태의 설명 문구) */
    val likeButtonDescs = listOf("Like", "좋아요")

    fun idMatches(viewId: String?, candidates: List<String>): Boolean =
        viewId != null && candidates.any { viewId.endsWith(":id/$it") }
}
