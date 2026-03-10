# Loongji 사용 가이드

## 시나리오 A: 그린필드 (새 프로젝트)

프로젝트가 막 시작됐거나 아직 계획 문서가 없는 상태.

### 전제 조건

1. Git 저장소 초기화 완료
2. `CLAUDE.md` 작성 (build/test/dev 명령어, 기술 스택)

```bash
git init my-project && cd my-project
# CLAUDE.md 작성 (프로젝트 개요, 명령어, 컨벤션)
```

### Step 1: 플러그인 설치

```bash
claude plugin install loongji
```

### Step 2: 첫 계획 생성

```bash
/lj-plan "사용자 인증 시스템 구현"
```

`/lj-plan`이 자동으로:
- `docs/plans/{done,planned,reference}/` 디렉토리 생성
- `docs/plans/README.md` (계획 인덱스) 생성
- `docs/plans/SPRINT.md` (스프린트 상태) 생성
- `PLAN-YYYYMMDD-user-auth.md` 작성

### Step 3: 스프린트에 추가

```bash
/lj-sprint add user-auth
```

### Step 4: 실행

```bash
/lj-worktree next     # 워크트리 생성 + Claude 자동 실행
/lj-crisp              # 진행 상황 확인
/lj-serve              # 완료 후 머지
```

### 그린필드 팁

- CLAUDE.md가 비어 있으면 `/lj-cook`이 빌드/테스트 명령어를 추론하기 어려움 → 최소한 명령어 섹션은 작성
- 첫 계획은 작게 시작 (2-3 Phase) → 워크플로우에 익숙해진 후 대형 계획 진행
- `.claude/loongji.local.md`는 처음엔 불필요 — 기본값으로 충분

---

## 시나리오 B: 브라운필드 (기존 프로젝트, Loongji 첫 도입)

이미 코드가 있지만 계획 문서 체계가 없는 상태.

### 전제 조건

1. Git 저장소에 코드가 있음
2. `CLAUDE.md` 존재 (또는 작성)

### Step 1: 플러그인 설치

```bash
claude plugin install loongji
```

### Step 2: (선택) 기존 작업을 계획으로 정리

기존 코드에 대한 계획 문서를 소급 작성할 필요는 없음. 앞으로의 작업부터 Loongji로 관리하면 됨.

기존 히스토리를 기록하고 싶다면:
```bash
mkdir -p docs/plans/done
# 기존 완료 작업에 대한 PLAN 파일 수동 작성 (선택)
```

### Step 3: 새 기능 계획

```bash
/lj-plan "기존 API에 rate limiting 추가"
```

자동 부트스트랩이 `docs/plans/` 구조를 생성. 에이전트 팀이 **기존 코드베이스를 분석**해서 계획에 반영.

### Step 4: 실행

그린필드와 동일:
```bash
/lj-sprint add rate-limiting
/lj-worktree next
```

### 브라운필드 팁

- `/lj-plan`의 에이전트 팀이 기존 코드 패턴을 분석하므로, 계획이 프로젝트 컨벤션에 맞게 생성됨
- 모노레포라면 `.claude/loongji.local.md`에 `build_shared` 명령어 설정 권장
- 기존 테스트 실패가 있다면 `post_merge.known_failures`에 등록해 `/lj-serve` 검증에서 무시

---

## 시나리오 C: 브라운필드 (기존 프로젝트, 이미 docs/plans/ 사용 중)

Loongji의 문서 구조를 이미 사용하고 있거나, 유사한 체계가 있는 상태.

### 기존 구조가 Loongji와 호환되는 경우

`docs/plans/` + `PLAN-*.md` + `SPRINT.md` 양식이 맞다면:

```bash
claude plugin install loongji
/lj-crisp   # 현재 상태 확인
```

바로 사용 가능. 부트스트랩은 기존 파일을 건드리지 않음.

### 기존 구조가 다른 경우

계획 문서가 다른 위치에 있다면 `.claude/loongji.local.md`로 경로 지정:

```yaml
---
plans_dir: my-docs/features
sprint_file: my-docs/features/CURRENT.md
plan_index: my-docs/features/INDEX.md
---
```

기존 문서 양식이 다르다면 (예: RFC, ADR 방식):
- Loongji는 `PLAN-YYYYMMDD-*.md` 양식을 기대함
- 기존 문서는 `reference/`에 보관하고, Loongji 양식으로 새 계획 작성

---

## 시나리오 D: 단일 기능 빠르게 구현 (스프린트 없이)

작은 버그 수정이나 단순 기능을 스프린트 관리 없이 바로 실행.

```bash
# 1. 계획 생성
/lj-plan "fix: 로그인 페이지 비밀번호 검증 버그"

# 2. 스프린트 건너뛰고 바로 워크트리 생성
/lj-worktree fix/login-validation

# 3. 완료 후 머지
/lj-serve fix/login-validation
```

`/lj-sprint`은 여러 계획을 관리할 때 유용. 단일 작업이면 생략 가능.

---

## 시나리오 E: 대형 기능 병렬 실행

여러 계획을 동시에 진행.

```bash
# 계획 3개 수립
/lj-plan "token quota system"
/lj-plan "storage quota system"
/lj-plan "fix ops dashboard bugs"

# 스프린트 큐에 추가 (의존성 분석 자동)
/lj-sprint add token-quota
/lj-sprint add storage-quota      # → token-quota 의존성 감지
/lj-sprint add ops-bugfix

# 병렬 가능한 것들 동시 실행
/lj-worktree all                  # 의존성 없는 것만 워크트리 생성

# 상태 확인
/lj-crisp

# 완료된 것부터 순차 머지
/lj-serve fix/ops-bugfix          # 독립적인 것 먼저
/lj-serve feat/token-quota        # 의존성 해소 → storage-quota 언블록
/lj-serve feat/storage-quota
```

### 병렬 실행 시 주의

- 최대 3-4개 워크트리 권장 (시스템 리소스)
- 같은 파일을 수정하는 계획은 순차 머지 필요 (SPRINT.md Merge Conflicts Risk 참고)
- `/lj-crisp`으로 전체 진행 상황 모니터링

---

## 시나리오 F: Worker 수 조절

계획 크기에 따른 worker 설정.

| 계획 규모 | Phase 수 | Task 수 | 권장 Worker |
|-----------|---------|---------|------------|
| Small | 1-2 | < 5 | 1 (순차) |
| Medium | 3-4 | 5-15 | 2 |
| Large | 5+ | 15+ | 3 |

`.claude/loongji.local.md`로 기본값 변경:
```yaml
---
loongji:
  max_workers: 3
  plan_iterations: 5
---
```

또는 `/lj-cook` 실행 시 loop.sh에 직접 전달:
```bash
./loop.sh --workers 3 30    # 3 workers, max 30 iterations each
```

---

## 커맨드 흐름 요약

```
/lj-plan ─── 계획 문서 생성
    │
    ▼
/lj-sprint ── 스프린트 큐 관리 (선택)
    │
    ▼
/lj-worktree ─ 워크트리 + Claude 실행
    │
    ▼ (자동)
/lj-cook ──── spec → plan iterations → parallel build
    │
    ├── /lj-crisp ── 진행 상황 확인 (아무 때나)
    │
    ▼
/lj-serve ─── 머지 + 검증 + Result 기록 + 정리
```
