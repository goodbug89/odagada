# GitHub Pages 배포 (초대 딥링크용)

Android App Links는 `assetlinks.json`이 **도메인 루트**에 있어야 하므로,
사용자 Pages 저장소(`goodbug89.github.io`)에 아래 내용을 그대로 올린다.

## 절차
1. GitHub에 **공개 저장소 `goodbug89.github.io`** 생성(이미 있으면 재사용).
2. 이 폴더의 파일을 저장소 루트에 그대로 복사:
   - `.well-known/assetlinks.json`
   - `.nojekyll`
   - `invite/index.html`
3. push 후 Settings → Pages에서 Source를 `main` 브랜치 루트로 설정.
4. 확인:
   - `https://goodbug89.github.io/.well-known/assetlinks.json` 이 JSON을 그대로 반환하는지
   - `https://goodbug89.github.io/invite/?t=TEST1234` 페이지에 코드 `TEST1234`가 보이는지

## 서명 지문
`assetlinks.json`의 지문은 **디버그 키스토어**(`~/.android/debug.keystore`) SHA256이다.
릴리스 서명으로 배포할 때는 릴리스 지문을 배열에 **추가**한다(둘 다 나열 가능):

    keytool -list -v -keystore <릴리스 키스토어> -alias <별칭>

## 검증 상태 확인(기기)
    adb shell pm get-app-links com.odagada.app
    adb shell pm verify-app-links --re-verify com.odagada.app
