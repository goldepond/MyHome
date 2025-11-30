# 🔧 GitHub Actions 권한 오류 해결 가이드

## 문제 상황
```
remote: Permission to goldepond/MyHome.git denied to github-actions[bot].
fatal: unable to access 'https://github.com/goldepond/MyHome.git/': The requested URL returned error: 403
```

## ✅ 해결 방법

### 1단계: GitHub 저장소 설정 확인

#### A. Actions 권한 설정
1. GitHub 저장소로 이동: https://github.com/goldepond/TESTHOME
2. **Settings** (설정) 클릭
3. 왼쪽 메뉴에서 **Actions** → **General** 클릭
4. **Workflow permissions** 섹션에서:
   - ✅ **Read and write permissions** 선택
   - ✅ **Allow GitHub Actions to create and approve pull requests** 체크
5. 맨 아래로 스크롤하여 **Save** 클릭

#### B. GitHub Pages 설정
1. **Settings** → **Pages** 클릭
2. **Source** 섹션에서:
   - **Deploy from a branch** 선택
   - **Branch**: `gh-pages` 또는 **GitHub Actions** 선택
   - **Folder**: `/ (root)` 선택
3. **Save** 클릭

### 2단계: 환경(Environment) 확인

1. **Settings** → **Environments** 클릭
2. `github-pages` 환경이 있는지 확인
   - 없으면 자동 생성되므로 별도 설정 불필요
3. 있다면 클릭하여:
   - **Deployment branches**에서 **All branches** 선택

### 3단계: 워크플로우 파일 확인

현재 워크플로우 파일들은 이미 올바른 권한을 가지고 있습니다:
- ✅ `contents: read` - 코드 읽기
- ✅ `pages: write` - Pages 쓰기
- ✅ `id-token: write` - 인증 토큰

### 4단계: 오래된 워크플로우 확인

에러 메시지에서 `peaceiris/actions-gh-pages@v3`가 보이는데, 현재 코드베이스에는 해당 액션을 사용하는 워크플로우가 없습니다.

다음을 확인하세요:
1. https://github.com/goldepond/TESTHOME/actions 에서 실패한 워크플로우 확인
2. 어떤 워크플로우 파일이 실행되었는지 확인
3. 혹시 다른 저장소(`MyHome`)의 워크플로우가 실행된 것은 아닌지 확인

## 🔍 추가 확인사항

### 저장소 이름 확인
- 현재 저장소: `goldepond/TESTHOME`
- 에러의 저장소: `goldepond/MyHome`
- → 다른 저장소의 워크플로우일 가능성 있음

### 워크플로우 파일 목록
현재 활성화된 워크플로우:
- ✅ `.github/workflows/deploy.yml` - `actions/deploy-pages@v4` 사용
- ✅ `.github/workflows/flutter-gh-pages.yml` - `actions/deploy-pages@v4` 사용
- ❌ `peaceiris/actions-gh-pages@v3`를 사용하는 파일 없음

## 📝 권한 확인 체크리스트

- [ ] Settings → Actions → General → Workflow permissions = "Read and write"
- [ ] Settings → Pages → Source = "GitHub Actions" 또는 "gh-pages 브랜치"
- [ ] Settings → Environments → github-pages 환경 존재
- [ ] 워크플로우 파일에 올바른 permissions 설정됨
- [ ] 오래된 워크플로우 파일 삭제

## 🚨 문제가 계속되는 경우

1. **워크플로우 파일 강제 업데이트**
   - `.github/workflows/` 폴더의 모든 파일 확인
   - `peaceiris/actions-gh-pages` 사용하는 파일이 있으면 삭제

2. **Personal Access Token 사용** (임시 해결책)
   - GitHub → Settings → Developer settings → Personal access tokens
   - 토큰 생성 (repo 권한)
   - 저장소 → Settings → Secrets → `GH_PAGES_TOKEN` 추가
   - 워크플로우에서 토큰 사용 (현재는 불필요)

3. **GitHub Actions 캐시 삭제**
   - Settings → Actions → Caches
   - 모든 캐시 삭제

