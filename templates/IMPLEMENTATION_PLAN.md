# Implementation Plan

<!--
FORMAT: Parallel workers (Mode C) parse this file with regex. Follow this format exactly.

  Pending:    - [ ] Task description
  Complete:   - [x] Task description

STRUCTURE:
- Use section headers (##) to group related tasks.
- Order tasks by dependency within each section: foundational work first.
- Tasks in the same section at the same indent level are independent and safe for parallel execution.
- Below each checkbox line, add indented context (acceptance criteria, relevant files, notes).
  Workers read the full file for context even though they are assigned a single task.

EXAMPLE:
  ## Database
  - [ ] Add payments table schema
    Create payments and payment_methods tables.
    Acceptance: migration runs, typecheck passes.
    Files: src/db/schema.ts, src/db/migrations/

  ## API (depends on Database)
  - [ ] Create payment service module
    PaymentService with createPayment(), refund().
    Acceptance: unit tests pass.
    Files: src/services/payment.ts, src/services/payment.test.ts

  ## UI (independent of API — can run in parallel)
  - [ ] Add payment method selector component
    Dropdown component, no API calls yet — use mock data.
    Acceptance: component renders, storybook snapshot passes.
    Files: src/components/PaymentSelector.tsx

TASK SIZE: Each task should be completable in one iteration (one context window).
  If you cannot describe the change in 2-3 sentences, split it.
-->
