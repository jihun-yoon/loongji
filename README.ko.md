# Loongji — 바삭하게 완성하는 AI SDLC

Claude Code를 위한 AI 네이티브 SDLC 방법론. 스프린트 기반 프로젝트 관리와 반복적·병렬 코드 생성을 결합합니다.

**"가장 완벽하게 익은 코드만을 내놓는다."**

**Loong (龍)** — 500개의 서브에이전트가 병렬로 움직이는 용의 군단.
**Ji (누룽지)** — 바닥까지 제대로 눌러 붙여 만든 완성도 높은 결과물.

English version: [README.md](README.md)

## 철학

기존 SDLC: 사람이 계획 → 사람이 구현 → 사람이 테스트
Loongji SDLC: 사람이 범위 정의 → AI가 스펙 작성 → AI가 계획 → AI가 병렬 구현 → AI가 검증 → 사람이 머지

**핵심 원칙**: 사람은 *무엇*과 *왜*를 정의. AI는 *어떻게*를 반복적·병렬적으로 처리.

## Loongji 파이프라인

```
 +----------+    +----------+    +----------+    +----------+    +----------+
 |  DESIGN  |--->|   SPEC   |--->|   PLAN   |--->|  COOK    |--->|  SERVE   |
 | /lj-plan |    | 자동 생성 |    | 반복 정제 |    | 병렬 실행 |    | /lj-     |
 |          |    | from plan|    |          |    | workers  |    |  serve   |
 +----------+    +----------+    +----------+    +----------+    +----------+
   사람 -------------- AI ---------------------------------------- 사람
```

### 단계 1: 설계 (`/lj-plan`)
사람이 원하는 것을 설명하면, AI 에이전트 팀이 코드베이스를 조사하고 위험을 식별하여 PLAN 문서를 생성합니다.

### 단계 2: 스펙 (자동)
PLAN의 각 Phase가 Job To Be Done 프레임워크를 따르는 상세 스펙으로 변환됩니다:
- 기능 요구사항 (FR-1, FR-2, ...)
- 인수 조건
- 기술 노트

### 단계 3: 계획 (반복)
AI가 3회 이상 계획 반복을 수행하며, 최대 500개의 병렬 서브에이전트로 스펙과 기존 코드를 분석합니다. 의존성 정렬된, 병렬 안전한 태스크 체크리스트가 담긴 IMPLEMENTATION_PLAN.md를 생성합니다.

### 단계 4: 빌드 (`/lj-cook`)
여러 AI 워커가 git worktree를 통해 태스크를 병렬 실행합니다:
- 각 워커가 원자적으로 태스크를 클레임 (git 기반 잠금)
- 테스트 우선 워크플로우 (Red → Green → Refactor)
- 15개 가드레일이 AI 코딩 실수를 방지
- 워커가 결과를 피처 브랜치에 머지

### 단계 5: 서빙 (`/lj-serve`)
전체 검증 파이프라인, 자동 생성된 결과 문서, 워크트리 정리와 함께 main에 머지합니다.

## 설치

```bash
claude plugin install loongji
# 또는 로컬 개발용:
claude --plugin-dir ~/path/to/loongji
```

## 빠른 시작

```bash
/lj-plan "사용자별 토큰 쿼터 추가"      # 1. 계획 생성 (docs/plans/ 자동 부트스트랩)
/lj-sprint add token-quota             # 2. 스프린트 큐에 추가
/lj-worktree next                      # 3. 워크트리 + Claude 자동 실행
/lj-crisp                              # 4. 진행 상황 확인
/lj-serve feat/token-quota             # 5. 머지 + 검증 + Result 기록
```

상세 시나리오: [GUIDE.ko.md](GUIDE.ko.md) (그린필드, 브라운필드, 병렬 실행 등)

## 커맨드

| 커맨드 | 단계 | 설명 |
|--------|------|------|
| `/lj-plan <feature>` | 설계 | 에이전트 팀 분석으로 계획 생성 |
| `/lj-sprint [action]` | 큐 | 스프린트 큐 관리 (add, status, reorder) |
| `/lj-worktree [target]` | 실행 | 워크트리 생성 + 실행 시작 |
| `/lj-cook` | 빌드 | (자동) 스펙 → 계획 반복 → 병렬 빌드 |
| `/lj-crisp` | 확인 | 활성 워커, 진행 상황, 큐 표시 |
| `/lj-serve [branch]` | 서빙 | 머지 + 검증 + 결과 문서 + 정리 |

## 문서 관리

Loongji는 프로젝트에 `docs/plans/` 디렉토리 구조를 기대합니다:

```
docs/plans/
├── README.md           ← 계획 인덱스 (Done / Planned / Reference 테이블)
├── SPRINT.md           ← 현재 스프린트 상태 (Active / Queue / Done)
├── done/               ← 완료된 계획
├── planned/            ← 예정된 계획
├── in-progress/        ← 현재 실행 중 (선택)
└── reference/          ← 분석 문서, 아키텍처 노트
```

### 계획 파일 규칙

**네이밍**: `PLAN-YYYYMMDD-<feature-name>.md` (날짜 = 생성일)

**필수 헤더** (제목 다음 3-4줄):
```markdown
# PLAN: 기능 제목

> **Status**: Planned | In Progress | Done | Deferred
> **Type**: feature | bugfix | infra | refactor
> Branch: `feat/feature-name`
```

### 초기 설정

`/lj-plan` 또는 `/lj-sprint`을 처음 실행하면 자동으로 부트스트랩됩니다. 수동 설정 불필요.

## 설정

Loongji는 세 계층에서 프로젝트 컨텍스트를 읽습니다:

1. **`CLAUDE.md`** — 빌드/테스트/개발 명령어, 프로젝트 구조 (Claude가 자동으로 읽음)
2. **`docs/plans/`** — 계획 인덱스 + 스프린트 상태 (Loongji 커맨드가 관리)
3. **`.claude/loongji.local.md`** — 선택적 명시적 오버라이드 ([SETTINGS.md](SETTINGS.md))

대부분의 프로젝트는 `CLAUDE.md`만 있으면 됩니다. 설정 파일은 모노레포, 비표준 경로, 워커 수 조정에 유용합니다.

## 요구사항

- Claude Code (플러그인 지원)
- Git 2.20+ (worktree용)
- tmux (pane 관리용)
- CLAUDE.md와 docs/plans/ 구조를 가진 프로젝트

## 영감 & 크레딧

Loongji는 다음 프로젝트들의 아이디어와 기법을 기반으로 합니다:

- **[Augmented Coding: Beyond the Vibes](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes)** (Kent Beck) — "바이브 코딩"과 "증강 코딩"의 구분: AI 능력을 활용하면서도 코드 품질, TDD 규율, 아키텍처 감독을 유지. Loongji의 테스트 우선 가드레일과 human-in-the-loop 설계 철학에 직접적 영향.

- **[Claude's C Compiler](https://github.com/anthropics/claudes-c-compiler)** (Anthropic) — 명확한 테스트 주도 스펙만으로 Claude가 복잡한 시스템(완전한 C 컴파일러)을 자율적으로 구현할 수 있음을 증명. Loongji의 스펙 주도, 테스트 우선 워커 실행 모델이 이 패턴을 따름.

- **[The Ralph Technique](https://github.com/ghuntley/how-to-ralph-wiggum)** (Geoffrey Huntley) — 루프 기반 실행 방법론: bash 스크립트가 매 반복마다 새로운 컨텍스트 윈도우로 Claude에 지시를 전달하고, 디스크의 영구 계획 파일에서 현재 상태를 읽음. Loongji의 `loop.sh`/`worker.sh` 아키텍처, JTBD 기반 스펙 생성, AGENTS.md 운영 학습, 테스트를 통한 배압 접근방식이 이 기법에서 직접 파생.

## 라이선스

MIT
