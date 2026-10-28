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
- 현재는 **Android** 버전. iOS는 단축어 자동화 + 화면 방송으로 측정하고, 🧾 버튼 대신 다이내믹 아일랜드에 뜸 (아래 [아이폰](#아이폰-준비-중) 참고)

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

## 아이폰 (준비 중)

아이폰은 다른 앱의 화면을 읽거나 그 위에 버튼을 띄울 수 없어서, 측정 방식을 새로 만들고 있습니다.
**이용 시간**은 단축어 자동화로, **광고·추천·친구 게시물·릴스 개수와 스크롤 거리**는 화면 방송을 켠 동안
화면 글자를 기기 안에서 읽어(Vision 문자 인식) 셉니다. 좋아요는 알 수 없어 영수증에서 드립 문구로 나옵니다.

| 부분 | 파일 | 역할 |
|---|---|---|
| 채널 | `ios/Runner/TrackerChannel.swift` | 안드로이드 `MainActivity.kt`와 같은 메서드 이름으로 Dart에 답한다 |
| 이용 시간 | `ios/Runner/InstagramIntents.swift` | 단축어 동작 "인스타그램 시작 기록" / "인스타그램 종료 기록" |
| 측정 | `ios/ScrollBroadcast/SampleHandler.swift` | 화면 방송 확장. 0.5초에 한 장 화면 글자를 읽는다 (프레임·글자는 저장 안 함) |
| 분류 | `ios/ScrollBroadcast/FeedAnalyzer.swift` | 글줄 위치로 게시물 헤더/광고/추천/릴스를 가리고, 같은 글줄이 밀린 양으로 스크롤 거리를 잰다 |
| 판별 기준 | `ios/ScrollBroadcast/InstaOCRRules.swift` | 문구와 위치 기준. **숫자가 이상하면 여기 수정** |
| 🧾 버튼 | `ios/ReceiptWidget/ReceiptLiveActivity.swift`, `ios/Runner/ReceiptActivity.swift` | 인스타그램을 보는 동안 다이내믹 아일랜드·잠금 화면에 오늘 이용 시간을 띄우고, 누르면 영수증 |
| 저장 | `ios/Runner/StatsStore.swift`, `ScrapStore.swift` | 안드로이드와 같은 키 형식. App Group(`group.com.eugenally.scrollReceipt`) 공유 저장소 |

실행하려면 Mac + Xcode가 필요합니다.

```bash
flutter pub get
open ios/Runner.xcworkspace
```

Xcode에서 Runner 타깃 → Signing & Capabilities → 팀을 고르고, App Groups에
`group.com.eugenally.scrollReceipt`가 체크돼 있는지 확인합니다. **ScrollBroadcast 타깃도 똑같이** 팀과 App Group을,
**ReceiptWidget 타깃**은 팀을 확인한 뒤 실기기로 `flutter run` 하세요. (iOS 17 이상, 시뮬레이터에서는 화면 방송이 안 됩니다)

### 아이폰에서 설정 (이용 시간)

단축어 앱 → 자동화 → 새로운 자동화 → 앱 → Instagram 에서 두 개를 만듭니다.

1. **열릴 때** · 즉시 실행 → 동작 추가 → "인스타그램 시작 기록"
2. **닫힐 때** · 즉시 실행 → 동작 추가 → "인스타그램 종료 기록"

"닫힐 때" 자동화가 빠져도 시간이 끝없이 쌓이지 않도록, 한 세션은 최대 3시간까지만 셉니다.

자동화가 돌면 다이내믹 아일랜드(없는 기종은 잠금 화면)에 🧾 와 오늘 이용 시간이 뜨고, 누르면 영수증이 열립니다.
안 뜨면 설정 > 스크롤 영수증 > 실시간 현황이 켜져 있는지 확인하세요.

### 아이폰에서 설정 (개수·거리)

앱의 **"화면 방송 시작"** 을 누르고 시스템 창에서 "방송 시작"을 누르면 상단에 빨간 표시가 뜨며 측정이 시작됩니다.
위의 단축어 자동화가 있어야 인스타그램이 열려 있을 때만 셉니다. 끌 때는 빨간 표시 → 중단.

숫자가 이상하면 Mac의 Console 앱에서 아이폰을 고르고 `ScrollBroadcast`로 걸러 보세요.
프레임마다 인식된 글과 위치(`x,y 글`)가 찍힙니다. 이걸 보고 `InstaOCRRules.swift`의 위치·문구를 고칩니다.

## 숫자가 이상할 때 (판별 기준 조정)

인스타그램은 화면 구조를 자주 바꿉니다.

1. 인스타그램 피드에서 🧾 버튼을 **길게 누르기** → 현재 화면 구조가 logcat에 출력됨
2. `adb logcat -s ScrollReceipt` 로 확인
3. 게시물 작성자 이름의 `id=com.instagram.android:id/...` 값을 찾아 `InstaSelectors.kt`에 추가

## 로드맵

- [x] Android: 플로팅 버튼 + 접근성 측정 + 영수증 + 이미지 공유
- [ ] 주간/월간 누적 영수증
- [ ] 레딧 앱 지원
- [x] iOS 1단계: 뼈대 + 같은 채널의 Swift 구현 + App Group 저장소
- [x] iOS 2단계: 단축어 자동화로 이용 시간 기록
- [x] iOS 3단계: 화면 방송(ReplayKit) + 문자 인식으로 광고·추천·릴스·스크롤 거리 측정
- [x] iOS 4단계: 다이내믹 아일랜드(Live Activity)로 🧾 버튼 대체
- [ ] iOS 5단계: 문자 인식 결과로 스크랩
- [ ] 구글 플레이 출시 (접근성 API 사용 고지)
