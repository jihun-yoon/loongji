# Loongji Backlog

> 사용 중 발견된 이슈 및 개선사항

---

## BUG-001: `/lj-cook` 브랜치→Plan 매칭 실패

**심각도**: High — 워크플로우 진행 불가

**증상**: SPRINT.md에 브랜치가 등록되어 있고 plan 파일도 존재하는데 "plan 파일이 없다"고 보고.

**재현**:
1. `/lj-plan` → plan 파일 생성
2. `/lj-sprint add` → SPRINT.md에 등록
3. `/lj-worktree next` → 워크트리 생성
4. 워크트리에서 `/lj-cook` → "plan 파일 없음" 에러

**원인 추정**: SPRINT.md 파싱 시 branch 컬럼의 백틱(`` `fix/session-reconnection` ``)을 strip하지 않거나, plan 컬럼의 markdown 링크(`[name](path)`)에서 파일 경로 추출 실패.

**수정 방향**: SPRINT.md 테이블 파싱 로직에서:
- 백틱 strip: `` `fix/xxx` `` → `fix/xxx`
- Markdown 링크 추출: `[name](planned/PLAN-xxx.md)` → `docs/plans/planned/PLAN-xxx.md`

---

## BUG-002: `/lj-worktree` 생성 시 최신 커밋 미반영

**심각도**: High — plan 파일 없는 워크트리 생성됨

**증상**: 워크트리가 이전 커밋에서 생성되어 plan 파일과 SPRINT.md 변경사항이 없음.

**재현**:
1. `/lj-plan` → plan 파일 생성 (uncommitted)
2. `/lj-sprint add` → SPRINT.md 수정 (uncommitted)
3. `/lj-worktree next` → `git branch + git worktree add` 실행
4. 워크트리에는 plan 파일 없음 (커밋 안 된 상태에서 브랜치 생성)

**원인**: `/lj-plan`과 `/lj-sprint`가 파일을 수정하지만 커밋하지 않음. `/lj-worktree`는 현재 HEAD에서 브랜치를 생성하므로, uncommitted 파일이 워크트리에 포함되지 않음.

**수정 방향**:
- Option A: `/lj-worktree`에서 uncommitted 변경 감지 시 자동 커밋 또는 경고
- Option B: `/lj-plan` 완료 시 자동 커밋 (plan + SPRINT.md + README.md)

---

## IMPROVE-001: Plan→Worktree→Cook 커밋 동기화 갭

**심각도**: Medium — 매번 수동 커밋 필요

**현재 워크플로우** (6단계, 수동 커밋 2회 필요):
```
/lj-plan → (수동 커밋) → /lj-sprint add → (수동 커밋) → /lj-worktree → /lj-cook
```

**개선 워크플로우** (3단계):
```
/lj-plan → /lj-worktree next → /lj-cook
```

**수정 방향**:
- `/lj-plan` 완료 시: plan 파일 + README.md + SPRINT.md 자동 커밋
- `/lj-sprint add`를 `/lj-plan`에 통합 (plan 생성 → 자동 sprint 등록)
- `/lj-worktree`에서 uncommitted docs/plans/ 변경 감지 → 자동 커밋 후 진행

---

## IMPROVE-002: `/lj-cook` Grep 기반 검색 개선

**심각도**: Low

**증상**: `/lj-cook`이 SPRINT.md에서 브랜치명을 Grep으로 검색하는데, 워크트리에서 실행 시 결과 0건.

**수정 방향**:
- `docs/plans/SPRINT.md` 경로를 직접 Read하도록 변경 (Grep 대신)
- git root 기준으로 상대 경로 해석

---

## IMPROVE-003: `/lj-plan` 자동 커밋 옵션

**심각도**: Low

**현재**: plan 파일만 생성하고 커밋은 사용자 책임
**개선**: plan 생성 완료 시 커밋 여부를 묻거나, `--auto-commit` 옵션 지원

```markdown
## Plan Created
...
Plan 파일과 README.md를 커밋할까요? [y/n]
```

---

## IMPROVE-004: `loop.sh` → Loop Skill 전환 (에이전트 팀 병렬 실행)

**심각도**: High — 핵심 아키텍처 변경

**현재 문제**: `loop.sh`가 `claude -p` (headless 외부 프로세스)를 spawn. 이 프로세스는 메인 세션의 Agent tool을 사용할 수 없어서, 독립 태스크를 병렬 실행하지 못하고 순차 작업. 13개 태스크를 하나의 iteration에서 순차 처리 → 30분+ 소요.

**목표**: `loop.sh` 대신 **메인 Claude 세션에서 실행되는 Skill**로 전환. Agent tool로 독립 태스크를 병렬 spawn.

**설계**:
```
/lj-build [max_iterations]

매 iteration:
1. IMPLEMENTATION_PLAN.md 읽기 → 미완료 태스크 파악
2. 독립 태스크 그룹핑 (같은 파일 수정 없는 것끼리)
3. Agent tool × N 병렬 spawn (worktree isolation)
4. 결과 수집 → IMPLEMENTATION_PLAN.md 업데이트 → 커밋 + 푸시
5. 전부 완료면 중단, 아니면 /compact 후 다음 iteration
```

**컨텍스트 관리**:
- 상태는 IMPLEMENTATION_PLAN.md (디스크)에 있으므로 compact해도 손실 없음
- 매 iteration 끝에 /compact로 컨텍스트 정리
- Agent tool 결과는 요약만 메인에 반환

**구현 방향**:
- `commands/lj-build.md` 스킬 생성 (현재 `/lj-cook`의 Step 4 대체)
- `loop.sh` 는 fallback으로 유지 (CI/headless 환경용)
- `/lj-cook`에서 Step 4를 `/lj-build` 호출로 변경

---

## BUG-003: `loop.sh` stdout이 `/lj-cook` Bash 도구에 삼켜짐

**심각도**: Medium — iteration 진행 확인 불가

**증상**: `loop.sh`의 `echo` 출력 (iteration 번호, 태스크 카운트, LOOP 구분선)이 `/lj-cook`의 Bash 도구 내에서 실행될 때 사용자 터미널에 표시되지 않음.

**원인**: `/lj-cook` → `Bash("./loop.sh 5")` → stdout이 Claude의 Bash 결과로 캡처 → pane에는 Claude UI만 표시.

**수정 방향**: `loop.sh`의 모든 `echo` 출력을 `tee`로 `progress.log`에도 동시 기록. 토큰 소모 없이 `progress.log`만 확인하면 됨.
```bash
echo "..." | tee -a "$PROGRESS_LOG"
```

