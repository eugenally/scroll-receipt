# 🧾 스크롤 영수증 (Scroll Receipt)

인스타그램을 보다가 화면에 떠 있는 🧾 버튼을 누르면
**오늘 본 광고·추천·친구 게시물·릴스 개수, 스크롤 거리, 이용 시간**이
영수증으로 출력되는 앱입니다.

```
        ★ SCROLL MART ★
     인스타그램 지점 · 2026.10.28
   - - - - - - - - - - - - - - - -
   이용 시간             1시간 12분
   스크롤 거리            347.2m
     (≈ 남산서울타워 1.5개)
   - - - - - - - - - - - - - - - -
   친구 게시물        4개    ₩400
   모르는 사람 추천   61개  ₩6,100
   광고               23개  ₩2,300
   릴스              38개  ₩3,800
   ════════════════════════════════
   총 소비한 인생      1시간 12분
```

- 모든 기록은 **폰 안에만** 저장되고 어디로도 전송되지 않습니다.
- 현재는 **Android** 버전 (iOS는 다이내믹 아일랜드 방식으로 추후 추가 예정)

## 동작 방식

| 부분 | 파일 | 역할 |
|---|---|---|
| 측정 | `android/.../ScrollTrackerService.kt` | 접근성 서비스. 인스타그램 화면의 광고/추천 표시, 스크롤 양, 좋아요 클릭을 센다 |
| 떠 있는 버튼 | `android/.../FloatingBubble.kt` | 인스타그램이 켜져 있을 때만 🧾 버튼 표시. 드래그 가능, 탭하면 영수증 |
| 저장 | `android/.../StatsStore.kt` | 날짜별 개수를 SharedPreferences에 저장 |
| 판별 기준 | `android/.../InstaSelectors.kt` | 인스타그램 view id / 문구. **인스타 업데이트로 숫자가 0이면 여기 수정** |
| 영수증 화면 | `lib/receipt/receipt_view.dart` | 영수증 디자인 |
| 드립 문구 | `lib/receipt/receipt_copy.dart` | 랜드마크 환산, 하단 문구 등 |
| 공유 | `lib/screens/receipt_screen.dart` | 영수증을 PNG로 캡처해 공유 |

## 처음 실행하기

이 저장소에는 직접 작성한 코드만 들어 있고, Gradle 설정 같은 Flutter 기본 파일은 없습니다.
아래 명령으로 기본 파일을 채운 뒤 실행하세요. (`flutter create`는 이미 있는 파일을 덮어쓰지 않습니다.)

```bash
git clone https://github.com/eugenally/scroll-receipt.git
cd scroll-receipt
flutter create --org com.eugenally --project-name scroll_receipt --platforms android .
flutter pub get
flutter run        # USB 디버깅을 켠 안드로이드 폰 연결
```

> `flutter create` 후 `android/app/src/main/kotlin/com/eugenally/scroll_receipt/MainActivity.kt`가
> 기본 내용으로 바뀌지 않았는지 확인하세요. (`git status`로 변경 여부 확인 → 바뀌었으면 `git checkout -- android/`)

### 폰에서 설정

1. 앱을 열고 **"접근성 설정 열기"** → 설치된 앱(또는 다운로드한 앱) → **스크롤 영수증** 켜기
   - Android 13 이상에서 APK로 직접 설치했다면 "제한된 설정" 때문에 회색으로 막힐 수 있어요.
     → 설정 > 애플리케이션 > 스크롤 영수증 > 오른쪽 위 ⋮ > **제한된 설정 허용** 후 다시 켜기
2. 인스타그램을 열면 오른쪽에 🧾 버튼이 뜹니다
3. 스크롤하면 버튼 안에 거리가 올라가고, 누르면 영수증이 나옵니다

## 숫자가 이상할 때 (판별 기준 조정)

인스타그램은 화면 구조를 자주 바꿉니다.

1. 인스타그램 피드에서 🧾 버튼을 **길게 누르기** → 현재 화면 구조가 logcat에 출력됨
2. `adb logcat -s ScrollReceipt` 로 확인
3. 게시물 작성자 이름의 `id=com.instagram.android:id/...` 값을 찾아 `InstaSelectors.kt`에 추가

## 로드맵

- [x] Android: 플로팅 버튼 + 접근성 측정 + 영수증 + 이미지 공유
- [ ] 주간/월간 누적 영수증
- [ ] 레딧 앱 지원
- [ ] iOS: 단축어 자동화 + 다이내믹 아일랜드 (이용 시간 기반)
- [ ] 구글 플레이 출시 (접근성 API 사용 고지)
