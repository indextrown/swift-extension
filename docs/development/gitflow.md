# swift-extension Git 작업 흐름

> 이 저장소(`indextrown/swift-extension`)에서 확인한 규칙과 일반적인 작업 순서를 함께 적었어요. 규칙이 바뀌면 아래 표를 먼저 갱신해요.

## 먼저 저장소 규칙을 확인해요

작업하기 전에 다음 항목을 확인해요.

| 항목 | 이 프로젝트에서 확인한 규칙 | 확인할 곳 |
| --- | --- | --- |
| 기본 브랜치 | `main` | `git branch -a`, 원격 저장소 설정 |
| 원격 이름 | `origin` (`https://github.com/indextrown/swift-extension.git`) | `git remote -v` |
| 이슈 사용 여부 | 이슈를 만들지 않아요. 작업은 브랜치와 PR로만 관리해요. | 이 문서 |
| 작업 브랜치 이름 | `<유형>/<주제>` 예: `feature/ring-buffer` | 기존 브랜치, `.github/labels.json` |
| 커밋 메시지 형식 | `유형: 변경 내용` (개조식) 예: `feat: RingBuffer 추가` | 최근 커밋 `git log` |
| PR 제목 형식 | `[유형] 변경 내용` (해요체) 예: `[feature] RingBuffer를 추가했어요` | `.github/PULL_REQUEST_TEMPLATE.md` |
| PR 본문 형식 | 저장소 PR 템플릿의 섹션을 유지해요. | `.github/PULL_REQUEST_TEMPLATE.md` |
| 라벨 | `✨ feature`, `🔧 fix`, `🔥 hotfix`, `⚡ performance`, `⚙️ chore`, `🔨 refactor`, `✅ test`, `📃 docs` | `.github/labels.json` |
| 릴리즈 노트 분류 | 병합된 PR의 라벨로 자동 분류해요. | `.github/release-drafter.yml` |
| main 보호 | Ruleset `main protection`(active)이 걸려 있어요. | Settings → Rules → Rulesets |
| PR 리뷰·병합 조건 | PR 필수, 승인 0명, 필수 상태 체크는 아직 지정하지 않았어요. | 같은 Ruleset |

라벨은 브랜치 접두사와 릴리즈 노트 분류의 기준이에요. 이슈를 만들지 않으므로 라벨은 PR에 직접 붙여요. `.github/issue-branch.yml`은 이슈에서 브랜치를 자동 생성하는 설정이라 이 흐름에서는 동작하지 않아요.

`main`은 Ruleset `main protection`으로 보호해요. 우회 대상(bypass)이 비어 있어서 저장소 소유자에게도 그대로 적용돼요.

| 규칙 | 효과 |
| --- | --- |
| Require a pull request before merging | `main`에 직접 push할 수 없어요. 승인은 0명이라 본인이 만든 PR을 본인이 머지할 수 있어요. |
| Restrict deletions | `main`을 삭제할 수 없어요. |
| Block force pushes | `main`에 강제 push할 수 없어요. |
| Require status checks to pass | 규칙은 켜져 있지만 **필수 체크 목록이 비어 있어서 지금은 아무것도 막지 않아요.** `Build (debug)`, `Build (release)`, `Test`를 추가하면 CI 실패 시 머지가 막혀요. |

`Build`·`Test` 워크플로는 규칙과 상관없이 모든 PR에서 돌아요. 필수 체크로 지정하기 전까지는 결과를 사람이 확인해야 해요.

```bash
git remote -v
git log -20 --pretty=format:'%s'
```

아래 흐름은 기본 브랜치가 `main`이고 원격 이름이 `origin`인 경우예요. 실제 이름이 다르면 명령도 바꿔요.

## 한 작업을 PR로 보내는 흐름

```text
기본 브랜치 최신화 → 작업 브랜치 생성 → 변경·검증 → 커밋할 파일 선택 → 커밋 → push → PR 생성·리뷰 → 병합 후 정리
```

한 브랜치에는 하나의 목적만 담아요. **이 저장소에서는 이슈를 만들지 않아요.** 작업 배경과 범위는 PR 본문에 적어요. PR 템플릿에 `관련 이슈` 항목이 있다는 이유만으로 이슈를 만들지 않아요.

### 1. 기본 브랜치를 최신으로 맞춰요

커밋하지 않은 변경이 없는지 확인한 뒤 기본 브랜치를 최신화해요.

```bash
git status --short
git switch main
git pull --ff-only origin main
```

### 2. 작업 브랜치를 만들어요

`<유형>/<주제>` 형식으로 만들어요. 주제는 영문 소문자와 하이픈으로 적어요.

```bash
git switch -c feature/ring-buffer
```

접두사는 저장소 라벨과 맞춰요.

| 접두사 | 사용 시점 | 브랜치 예시 |
| --- | --- | --- |
| `feature/` | 자료구조나 공개 API 추가 | `feature/ring-buffer` |
| `fix/` | 잘못된 동작 수정 | `fix/stack-pop-crash` |
| `perf/` | 성능·메모리 개선 | `perf/stack-push-reserve` |
| `refactor/` | 동작을 유지하는 구조 개선 | `refactor/buffer-ownership` |
| `test/` | 테스트 추가·수정 | `test/stack-boundary` |
| `docs/` | 문서 변경 | `docs/gitflow-update` |
| `chore/` | 설정·유지보수 | `chore/gitignore` |

### 3. 변경과 검증 결과를 확인해요

```bash
git status --short
git diff
```

예상하지 못한 파일이 보이면 원인을 확인해요. `.build/`와 `.swiftpm/`은 `.gitignore`에 있으므로 커밋 대상에 들어오면 안 돼요. 코드나 문서를 바꿨다면 [테스트 문서](testing.md)의 `swift test`로 검증하고, 실행하지 못한 검증도 PR에 적어요.

### 4. 커밋할 파일을 선택하고 확인해요

파일 수정과 검증을 마친 뒤, 커밋하기 직전에 이번 커밋에 포함할 파일만 stage해요.

```bash
# 이번 커밋에 포함할 파일을 선택해요.
git add docs/development/gitflow.md

# 선택한 파일과 변경량을 요약해서 확인해요.
git diff --staged --stat

# 실제로 커밋될 내용을 자세히 확인해요.
git diff --staged
```

예시 경로는 실제로 수정한 파일로 바꾸어요. 이번 커밋에 필요한 경로만 추가하고, `git add .`이나 `git commit -a`를 기본 절차로 사용하지 않아요.

### 5. 커밋 규칙을 확인하고 커밋해요

커밋 규칙은 아래 순서로 확인해요.

1. `AGENTS.md`, `CONTRIBUTING.md`, `.github/CONTRIBUTING.md` 같은 저장소 문서를 읽어요.
2. `git log -20 --pretty=format:'%s'`로 최근 커밋 제목을 확인해요.
3. 문서와 최근 이력이 다르면 사용자에게 어떤 규칙을 따를지 물어요.

커밋 제목은 `유형: 변경 내용` 형식으로 적어요. 유형 뒤에 콜론과 공백 한 칸을 두고, 내용은 **개조식**으로 적어요. `추가`, `수정`, `정리`처럼 명사로 끝내고 마침표를 넣지 않아요. 이슈를 만들지 않으므로 제목에 이슈 번호를 적지 않아요.

```text
feat: RingBuffer 추가
chore: gitignore에 빌드 산출물 추가
```

문장으로 설명이 필요하면 제목이 아니라 본문에 적어요. 본문은 해요체로 적어요.

| 유형 | 사용 시점 | 브랜치 접두사 | PR 라벨 | 제목 예시 |
| --- | --- | --- | --- | --- |
| `feat` | 자료구조나 공개 API를 추가해요. | `feature/` | `✨ feature` | `feat: RingBuffer 추가` |
| `fix` | 잘못된 동작을 고쳐요. | `fix/` | `🔧 fix` | `fix: 빈 스택 pop 크래시 수정` |
| `perf` | 성능이나 메모리를 개선해요. | `perf/` | `⚡ performance` | `perf: push 재할당 횟수 감소` |
| `refactor` | 동작을 유지하면서 구조를 개선해요. | `refactor/` | `🔨 refactor` | `refactor: 버퍼 관리 코드 분리` |
| `test` | 테스트를 추가하거나 수정해요. | `test/` | `✅ test` | `test: Stack 경계값 테스트 추가` |
| `docs` | 문서만 변경해요. | `docs/` | `📃 docs` | `docs: API 설계 규칙 정리` |
| `chore` | 설정이나 유지보수 작업을 해요. | `chore/` | `⚙️ chore` | `chore: gitignore 정리` |
| `ci` | GitHub Actions와 저장소 자동화를 바꿔요. | `chore/` | `⚙️ chore` | `ci: 릴리즈 워크플로 정리` |

유형 이름은 커밋에서만 써요. 브랜치 접두사와 PR 라벨은 위 표의 대응 값을 그대로 써요. 예를 들어 공개 API를 추가하면 브랜치는 `feature/ring-buffer`, 커밋은 `feat: RingBuffer 추가`, PR 제목은 `[feature] RingBuffer를 추가했어요`가 돼요.

> 초기 커밋 중에는 `[#1] Algorithm과 Labs 모듈을 분리해 개별 import를 지원한다`처럼 이슈 번호와 `-다`체를 쓴 이력이 있어요. 지금 규칙은 위 표를 따라요.

한 커밋에는 하나의 논리적 변경만 담아요. 제목만으로 이유나 주의할 영향을 설명하기 어렵다면 본문을 추가해요. stage한 내용을 마지막으로 확인하고 커밋한 뒤, 생성된 커밋을 확인해요.

[AI 작성 표기 규칙](ai-attribution.md)에 따라 AI 공동 작성자 트레일러와 생성 문구를 넣지 않아요. 커밋 본문까지 확인하려면 `git log -1 --format=%B`를 사용해요.

```bash
git diff --staged
git commit -m "docs: Git 작업 흐름을 이슈 없는 PR 흐름으로 정리"
git log -1 --oneline
```

### 6. 커밋을 원격 저장소에 push해요

```bash
git push -u origin feature/ring-buffer
```

push가 완료되면 원격 저장소에 작업 브랜치가 생겨요. 첫 push 후에는 `-u`를 사용해 로컬과 원격 브랜치를 연결해요.

### 7. PR을 만들고 리뷰를 요청해요

#### GitHub CLI 사용을 먼저 검토해요

GitHub CLI(`gh`)를 사용하면 현재 저장소와 인증 상태를 확인하고, 터미널에서 제목·본문·대상 브랜치를 지정해 PR을 만들 수 있어요. 필수 도구는 아니지만 실수를 줄이고 같은 흐름을 반복하기 쉬워서 권장해요.

먼저 설치 여부를 확인해요.

```bash
gh --version
```

`gh`가 없다면 임의로 설치하지 말고 사용자에게 다음과 같이 물어요.

```text
GitHub CLI가 없어요. gh 방식으로 PR을 만들 수 있도록 설치할까요?
```

사용자가 동의하면 [GitHub CLI 공식 설치 안내](https://github.com/cli/cli#installation)에 따라 설치하고 `gh auth login`으로 인증해요. 설치를 원하지 않으면 push 결과의 GitHub 링크나 웹 화면에서 PR을 만들어요.

`gh`가 설치되어 있다면 인증과 현재 저장소를 확인한 뒤 PR을 만들어요.

```bash
gh auth status
gh repo view
gh pr create \
  --base main \
  --head feature/ring-buffer \
  --title "[feature] RingBuffer를 추가했어요" \
  --body-file /absolute/path/pr-body.md
```

#### PR 제목을 작성해요

PR 제목은 저장소 PR 템플릿을 따라 `[유형] 변경 결과` 형식으로 적고 **해요체**로 끝내요. 이미 끝난 작업을 설명하므로 `~했어요`처럼 과거형으로 적어요.

```text
[feature] RingBuffer를 추가했어요
[fix] 빈 스택에서 pop이 크래시하는 문제를 고쳤어요
[performance] push의 재할당 횟수를 줄였어요
```

커밋 제목과 형식도 문체도 달라요. 헷갈리지 않게 아래 대응을 확인해요.

| 위치 | 형식 | 문체 | 예시 |
| --- | --- | --- | --- |
| 커밋 제목 | `유형: 내용` | 개조식 | `feat: RingBuffer 추가` |
| PR 제목 | `[유형] 내용` | 해요체 | `[feature] RingBuffer를 추가했어요` |
| PR 본문 | 템플릿 섹션 | 해요체 | `push가 재할당하는 횟수를 줄였어요.` |

PR에는 유형에 맞는 라벨을 붙여요. 라벨이 릴리즈 노트의 분류와 버전 증가 기준이 돼요.

PR을 올리면 `Build`와 `Test` 워크플로가 자동으로 돌아요. 결과를 확인하고, 실패하면 고친 뒤에 리뷰를 요청해요. 워크플로가 하는 일은 [테스트 문서](testing.md)에 있어요.

#### PR 본문은 저장소 템플릿을 따라요

본문에 **무엇을 어떤 순서로 적는지**(커밋별 소절, 문제 → 원인 → 해결 → 검증, 기존 방식과 새 API 비교, 영상 표, 쌓인 PR의 base)는 [PR 작성 가이드](pr-writing.md)에 있어요. 여기서는 템플릿과 문체 규칙만 확인해요.

다음 경로에서 PR 템플릿을 찾아요.

```text
.github/PULL_REQUEST_TEMPLATE.md
.github/pull_request_template.md
.github/PULL_REQUEST_TEMPLATE/*.md
.github/pull_request_template/*.md
```

템플릿이 있으면 섹션과 순서를 유지해요. 확인한 체크리스트만 표시하고, 새로 작성하는 문장은 해요체로 통일해요. 변경 이유, 영향 범위와 실제 검증 결과를 적어요.

```text
# Preferred
Stack의 pop이 빈 상태에서 크래시하는 문제를 고쳤어요.
Release 구성에서 10만 개 요소로 측정했고, 중앙값이 12% 줄었어요.

# Avoid
Stack의 pop이 빈 상태에서 크래시하는 문제를 고쳤다.
성능이 크게 개선되었음.
```

읽는 사람이 판단할 수 있게 사실만 적어요. 측정하지 않은 성능 개선이나 확인하지 않은 검증을 적지 않아요. 문장을 다듬을 때는 [한국어 윤문 원칙](korean-editing.md)을 따라요.

이 저장소의 템플릿에는 `자료구조·알고리즘 영향` 섹션이 있어요. 시간·공간 복잡도, 메모리 소유권과 기존 API 호환성을 비워 두지 않고 적어요. 해당 없는 항목에는 `없음`이라고 적어요.

템플릿이 없으면 파일을 임의로 만들지 말고 사용자에게 `PR 템플릿이 없어요. 이 저장소에 새 템플릿을 만들까요?`라고 물어요. 사용자가 원하지 않으면 현재 PR 본문만 작성해요.

PR을 만들기 위해 이슈를 새로 만들지 않아요. 템플릿의 `관련 이슈` 항목에는 `없음`이라고 적어요. 이슈에 담았을 배경과 목적은 `변경 내용` 섹션에 적어요.

### 8. 병합 후 브랜치를 정리해요

PR이 병합됐는지 확인한 뒤 기본 브랜치를 최신화해요. 브랜치를 다른 사람이 사용하지 않는지 확인한 경우에만 삭제해요.

```bash
git switch main
git pull --ff-only origin main
git branch -d feature/ring-buffer
git push origin --delete feature/ring-buffer
```

#### 쌓인 PR은 아래부터 병합해요

다른 기능 브랜치를 base로 둔 PR(stacked PR)은 **아래 PR을 먼저 `main`에 병합하고, 위 PR의 base를 `main`으로 바꾼 뒤** 병합해요. 아래 PR을 `main`에 병합한 다음 위 PR을 옛 base에 병합하면, 위 PR의 커밋은 `main`에 들어가지 않아요. 본문에 base를 적는 방법은 [PR 작성 가이드](pr-writing.md#쌓인-pr은-base를-본문에-적어요)에 있어요.

```bash
gh pr edit <번호> --base main
```

## 커밋·PR 전 체크리스트

- [ ] 현재 브랜치와 대상 기본 브랜치가 작업에 맞아요.
- [ ] stage한 파일이 모두 이번 작업과 관련 있어요.
- [ ] 비밀값, 개인 설정과 다른 작업의 변경을 제외했어요.
- [ ] 커밋 제목은 `유형: 내용` 개조식, PR 제목과 본문은 해요체로 적었어요.
- [ ] [AI 작성 표기 규칙](ai-attribution.md)에 따라 커밋 메시지와 PR 본문의 AI 공동 작성자·생성 문구·세션 링크를 제외했어요.
- [ ] `swift test`를 실행했거나 실행하지 못한 이유를 기록했어요.
- [ ] PR의 `Build`·`Test` 워크플로가 통과했어요.
- [ ] 공개 API를 바꿨다면 호환성 영향과 복잡도를 PR에 적었어요.
- [ ] PR 템플릿을 확인하고 변경 이유, 영향 범위와 검증 결과를 적었어요.
- [ ] PR에 유형에 맞는 라벨을 붙였어요.
- [ ] 이슈를 새로 만들지 않았고, `관련 이슈`에는 `없음`이라고 적었어요.

## 안전하게 작업해요

- `git reset --hard`, `git checkout -- <파일>`, `git restore <파일>`은 커밋하지 않은 변경을 잃게 할 수 있어요. 복구 대상을 확인하지 않고 실행하지 않아요.
- 기본 브랜치나 공유 브랜치에 `git push --force`를 사용하지 않아요.
- 비밀키, 토큰과 개인 설정 파일을 커밋하지 않아요.
- `.build/`, `.swiftpm/`, `DerivedData/` 같은 빌드 산출물을 커밋하지 않아요.
