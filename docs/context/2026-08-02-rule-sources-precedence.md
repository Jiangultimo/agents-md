---
date: 2026-08-02
slug: rule-sources-precedence
title: 用「按类别判定」解决多规则源冲突，并建立规则摩擦记录位
tags: [agent-rules, readme, ecc, hooks]
related: [evidence-before-judgment-rule]
---

## 背景 / 触发动机
`~/.claude/rules/common/`（ECC 安装，10 文件 538 行）每会话注入，与 README 存在对抗，此前记为 P0 未解。

逐文件通读 538 行后确认：冲突只有约 65 行，集中在三个主题——强制 TDD 与 80% 覆盖率、强制前置流程（先搜索 / 先出 PRD 五件套）、强制 agent 调用。其余约 470 行（安全检查清单、代码审查清单、AAA 测试结构、命名规范、文件行数阈值等）与 README 无对抗，是纯增量。用户明确要保留这部分，因此整包 `claudeMdExcludes` 排除的方案作废。

## 关键决策
- **按「类别」判定，不按「条目」枚举**。初版方案把三个冲突主题写死进 README，ECC 一更新或再装规则包就得重审，不通用。改为对任何外部注入源统一分三类：流程强制（本文件优先，外部版本默认关）、领域内容（自由采纳，让位于项目本地约定）、环境事实（用前必须验证）。538 行逐条套用无遗漏。
- **明令禁止就地修改 vendored 规则文件**。ECC 安装器 `scripts/lib/install-executor.js:273-277` 自己就 warn `files may be overwritten`，`rules/common` 是声明的递归复制目标——就地修必被覆盖且等于 fork 上游。正确做法是往上游报（`github.com/affaan-m/ECC`）。此点已写进 README 条款。
- **三分类刚好对应三种失败模式**：流程膨胀、内容浪费、事实腐烂。第三类是新增的防线——它能挡住下面「规则摩擦」记录的全部三条。
- **快照模板增设「规则摩擦」小节**，标注「无则整节删除」保持可选。这是规则淘汰的证据来源：此前规则只进不出，没有任何依据判断哪条该删，`rules/common` 就是该过程走到底的样子。

## 影响范围
- `README.md`：新增 `## Rule Sources` 节（Prime Directive 与 Step 1 之间）。经 symlink 即时生效于 Claude Code / Codex / opencode。
- `hooks/doc-types/context.sh`：快照模板新增「规则摩擦」小节，影响此后所有新建快照。
- `hooks/README.md`：同步 body sections 说明。
- 未改动 ECC 任何文件。

## 已知遗留 / 后续待办
- **token 成本未解**：538 行仍每会话注入。本方案只解对抗，不减体积；要减必须排除，与「保留一部分」的需求冲突。
- **三条错误事实仍在上游**：目前降级为「每次用前验证」，彻底修需向 ECC 提 issue/PR。尚未提。
- `~/.claude/rules/typescript/`（5 文件 319 行）存在于磁盘但本会话未被注入，原因未查清。已确认它由安装器按 `context.languages` 装入，但未注入的机制未验证。

## 规则摩擦
本轮验证出三条 `rules/common` 的错误环境事实，均已实测确认，构成首批条目：

1. **`hooks.md:7` — `**Stop**: When session ends (final verification)` 是错的。** Stop 在每次回复结束时触发，非会话结束。后果：我据此在 harness 评估中建议「用 Stop hook 缓解 pending snapshot 丢失」，该建议已作为结论交付给用户，实施阶段才自行发现语义不符并撤回。这是本仓库目前唯一一条已知的、由规则直接导致错误交付的记录。
2. **`agents.md:5` — `Located in ~/.claude/agents/`。** 实测该目录不存在；表格中的 agent 名（`planner`、`code-reviewer` 等）也缺 `ecc:` 前缀，按字面调用会失败。
3. **`git-workflow.md:12` — `Attribution disabled globally via ~/.claude/settings.json`。** 实测 settings.json 中无 `attribution` 亦无 `includeCoAuthoredBy` 键，该机制描述不成立。但该规则确实生效了：`git log` 确认三次 commit trailers 全空，即它压过了 harness 层「commit 追加 Co-Authored-By」的指令。结果可能符合用户意图，但理由是假的——这条同时证明 `rules/common` 并非摆设，会实际改变行为。

## 验证
`doc.sh context new` 实跑确认模板新小节出现在第 21 行；README 新节位置正确（Prime Directive 之后、Step 1 之前），未打断既有编号与交叉引用。三条摩擦条目均在本会话内实测取证：`test -d ~/.claude/agents` 返回不存在、`python3` 读 settings.json 确认无 attribution 键、`git log --format='%(trailers)'` 确认 trailers 为空、ECC 覆盖行为读自安装器源码。
