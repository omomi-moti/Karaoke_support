# Project Constitution Template (UNCONFIGURED / 未設定)

> **Status: UNCONFIGURED TEMPLATE (未設定テンプレート)**  
> このファイルはプロジェクト固有の「憲法（Constitution）」を作成するための**テンプレート**です。  
> 角かっこ付きのプレースホルダ（例: `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]` など）は **未設定** であり、  
> 現時点ではこのファイルを実運用上のルールや自動チェックの唯一の根拠として **使用しないでください**。  
> `/speckit.plan` や `/speckit.analyze` などで本ファイルを利用する場合は、必ず全てのプレースホルダを  
> プロジェクト固有の内容に置き換えたうえで、チームの合意を得てから運用してください。

---

## テンプレートの使い方

1. `[PROJECT_NAME]` をこのリポジトリ／プロダクトの正式名称に置き換える。  
2. 各 `[PRINCIPLE_X_NAME]` と `[PRINCIPLE_X_DESCRIPTION]` に、チームで合意した原則と説明を書く。  
3. `[SECTION_2_NAME]`, `[SECTION_2_CONTENT]`, `[SECTION_3_NAME]`, `[SECTION_3_CONTENT]` を、  
   プロジェクトに必要な追加要件やワークフローに合わせて埋める。  
4. `[GOVERNANCE_RULES]` に、憲法の改訂手順や運用ルールを明記する。  
5. `[CONSTITUTION_VERSION]`, `[RATIFICATION_DATE]`, `[LAST_AMENDED_DATE]` を最新の値に更新する。  

すべてのプレースホルダが埋められ、レビュー／承認が完了したら、以下のように先頭のステータスを更新してください:

> `Status: ACTIVE CONSTITUTION`（テンプレートではなく、実運用の憲法であることを明記）

---

# [PROJECT_NAME] Constitution
<!-- Example: Spec Constitution, TaskFlow Constitution, etc. -->

## Core Principles

### [PRINCIPLE_1_NAME]
<!-- Example: I. Library-First -->
[PRINCIPLE_1_DESCRIPTION]
<!-- Example: Every feature starts as a standalone library; Libraries must be self-contained, independently testable, documented; Clear purpose required - no organizational-only libraries -->

### [PRINCIPLE_2_NAME]
<!-- Example: II. CLI Interface -->
[PRINCIPLE_2_DESCRIPTION]
<!-- Example: Every library exposes functionality via CLI; Text in/out protocol: stdin/args → stdout, errors → stderr; Support JSON + human-readable formats -->

### [PRINCIPLE_3_NAME]
<!-- Example: III. Test-First (NON-NEGOTIABLE) -->
[PRINCIPLE_3_DESCRIPTION]
<!-- Example: TDD mandatory: Tests written → User approved → Tests fail → Then implement; Red-Green-Refactor cycle strictly enforced -->

### [PRINCIPLE_4_NAME]
<!-- Example: IV. Integration Testing -->
[PRINCIPLE_4_DESCRIPTION]
<!-- Example: Focus areas requiring integration tests: New library contract tests, Contract changes, Inter-service communication, Shared schemas -->

### [PRINCIPLE_5_NAME]
<!-- Example: V. Observability, VI. Versioning & Breaking Changes, VII. Simplicity -->
[PRINCIPLE_5_DESCRIPTION]
<!-- Example: Text I/O ensures debuggability; Structured logging required; Or: MAJOR.MINOR.BUILD format; Or: Start simple, YAGNI principles -->

## [SECTION_2_NAME]
<!-- Example: Additional Constraints, Security Requirements, Performance Standards, etc. -->

[SECTION_2_CONTENT]
<!-- Example: Technology stack requirements, compliance standards, deployment policies, etc. -->

## [SECTION_3_NAME]
<!-- Example: Development Workflow, Review Process, Quality Gates, etc. -->

[SECTION_3_CONTENT]
<!-- Example: Code review requirements, testing gates, deployment approval process, etc. -->

## Governance
<!-- Example: Constitution supersedes all other practices; Amendments require documentation, approval, migration plan -->

[GOVERNANCE_RULES]
<!-- Example: All PRs/reviews must verify compliance; Complexity must be justified; Use [GUIDANCE_FILE] for runtime development guidance -->

**Version**: [CONSTITUTION_VERSION] | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]
<!-- Example: Version: 2.1.1 | Ratified: 2025-06-13 | Last Amended: 2025-07-16 -->
