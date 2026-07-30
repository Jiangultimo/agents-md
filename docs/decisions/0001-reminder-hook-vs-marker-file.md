---
id: 0001
slug: reminder-hook-vs-marker-file
date: 2026-07-30
title: commit 前 flush 强制化：提醒式 hook 而非落盘 marker
status: Accepted
tags: [hooks, sop, harness]
supersedes: []
superseded_by:
---

## Status
Accepted

## Context
Pending snapshot 的 flush 完全依赖模型对规则文本的自觉遵守（概率性）。`git commit` 是 arc 的自然终点，也是最该保证 flush 发生的时刻。需要一个 harness 级的确定性保障，但 pending 状态只存在于对话上下文中，hook 进程无法直接读取。

## Decision
PreToolUse hook（Bash matcher）只做**确定性提醒**，不做语义判定：对 transcript 纯文本 grep `"Pending snapshot:"`，命中且本会话未提醒过 → 首次 `git commit` 以 exit 2 拦截一次并输出提醒；其余情况静默放行。「是否真的需要 flush」的判断留给模型——hook 补的只是「想起来判断」这一环。坏 JSON fail-open，hook 故障永不阻塞正常工作。

## Alternatives considered
- **落盘 marker 文件**（声明 pending 时写 marker，flush 时删除，hook 查文件存在性）：判定精确，但引入状态管理——会话崩溃后 marker 残留导致后续会话误报；需修改 SOP 增加每 arc 的落盘操作；与「不预写文件对冲丢失」的既定原则相抵。复杂度与收益不成比例，拒绝。
- **Stop hook 强制 flush**：Stop 在每次回复结束时触发，逼 flush 等于把 arc 制退化回 Step-4 时机，与 SOP 设计正面冲突。拒绝（并修正了此前评估中的这条建议）。
- **transcript 语义解析**（判断 pending 声明之后是否已出现对应 flush）：依赖 transcript 内部格式，脆弱且随版本漂移。拒绝。

## Consequences
- 正面：flush 遗忘从概率事件变为不可能（提醒必然发生）；无 pending 的会话零打扰；已 flush 后误提醒的代价上限为每会话一次。
- 负面：不是完美强制——模型收到提醒后仍可错误地无视（接受，语义判断本就该归模型）。
- 中性：该保障是 Claude Code 专有的（PreToolUse 机制）；Codex/opencode 仍只有规则文本约束。
