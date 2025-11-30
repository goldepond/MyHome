# GitHub Actions 권한 오류 해결 방법

## 🔴 발생한 에러

```
remote: Permission to goldepond/MyHome.git denied to github-actions[bot].
fatal: unable to access 'https://github.com/goldepond/MyHome.git/': The requested URL returned error: 403
```

## ⚠️ 문제 분석

1. **에러 저장소**: `goldepond/MyHome.git`
2. **현재 저장소**: `goldepond/TESTHOME.git`
3. **에러 액션**: `peaceiris/actions-gh-pages@v3`

**문제**: 다른 저장소(`MyHome`)에 대한 권한 오류이거나, 오래된 워크플로우가 실행된 것 같습니다.

## ✅ 즉시 해결 방법

### 1. GitHub 저장소 설정 변경 (필수)

1. 저장소로 이동: https://github.com/goldepond/TESTHOME
2. **Settings** 클릭
3. 왼쪽 메뉴에서 **Actions** → **General** 클릭
4. **Workflow permissions** 섹션에서:
   - ✅ **Read and write permissions** 선택
   - ✅ **Allow GitHub Actions to create and approve pull requests** 체크
5. 맨 아래로 스크롤 → **Save** 클릭

### 2. GitHub Pages 설정 확인

1. **Settings** → **Pages** 클릭
2. **Source**에서:
   - **Deploy from a branch** 선택
   - **Branch**: `gh-pages` 또는 **GitHub Actions** 선택
3. **Save** 클릭

### 3. 환경(Environment) 확인

1. **Settings** → **Environments** 클릭
2. `github-pages` 환경이 있으면:
   - 클릭 → **Deployment branches** → **All branches** 선택

## 📝 현재 워크플로우 상태

현재 워크플로우 파일들은 올바르게 설정되어 있습니다:
- ✅ `actions/deploy-pages@v4` 사용 (최신 방식)
- ✅ 올바른 권한 설정 (`contents: write`, `pages: write`)

## 🔍 추가 확인사항

### 다른 저장소 확인
에러가 `goldepond/MyHome.git` 저장소에서 발생했다면:
1. 해당 저장소의 Settings 확인
2. Actions 권한 설정 확인
3. 또는 해당 저장소의 워크플로우를 현재 저장소와 동기화

### 워크플로우 파일 확인
`.github/workflows/` 폴더에 오래된 워크플로우가 있는지 확인:
- `peaceiris/actions-gh-pages` 사용하는 파일 찾기
- 있다면 삭제하거나 업데이트

## 🚀 다음 단계

1. 위의 설정 변경 완료
2. 새로운 커밋을 push하여 워크플로우 재실행
3. Actions 탭에서 실행 상태 확인: https://github.com/goldepond/TESTHOME/actions

## 📞 문제가 계속되는 경우

1. **Actions 로그 확인**: https://github.com/goldepond/TESTHOME/actions
2. **실패한 워크플로우 확인**: 어떤 워크플로우 파일이 실행되었는지 확인
3. **저장소 이름 확인**: `MyHome`과 `TESTHOME` 중 어떤 저장소인지 확인

