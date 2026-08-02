---
date: 2026-08-02
slug: evidence-before-judgment-rule
title: 新增 Step 1.5「结论型交付物需先取证」并收窄 Step 1.4
tags: [agent-rules, readme, workflow]
related: []
---

## 背景 / 触发动机
用户反馈：agent 常常看到表层信号就匆忙下结论。核实本会话，找到两个实证：

1. 评估中建议「用 Stop hook 缓解 pending snapshot 丢失」——未查证 Stop 的触发语义就交付了这条建议。实施阶段才发现 Stop 在每次回复结束时触发，用它逼 flush 会把 arc 制退回 Step-4 时机，与 SOP 正面冲突。建议是错的，且已作为建议交付过。
2. hooks 脚本行数先后口述为「约 900 行」和「约 600 行」，语气都确定。实测（7117184）真实值 785 行，两次均为凭印象报数且方向相反。

共同点：从表层信号形成判断，并以确定语气交付。

## 关键决策
- **新增 Step 1.5「Evidence before judgment」**。划界依据不是「重要任务要仔细」这种不可判定的说法，而是一个真实的不对称：交付物是**改动**时，判断错会被 Step 4 验证抓住；交付物是**结论**时，判断错就是交付物本身，无任何后续环节能拦截。上述例 1 即该不对称的实例。
- **同步收窄 Step 1.4**（原文「cheapest clarification first / one grep」在鼓励浅尝辄止）。若只加新规则不改旧规则，就会造出一对互相拉扯的规则——正是本 repo 评估中列为 P0 的「双规则源冲突」问题。现 1.4 只管改动型交付物，结论型交付物由 1.5 接管。
- **给 1.5 写入停止条件**（每条要说的结论都有实际读过的东西支撑即止），否则该规则会退化成无止境调研，与 Prime Directive 第 3 条（避免 over-analysis）冲突。
- **只约束形成顺序，不约束呈现顺序**（用户拍板）。备选方案是同时要求输出「先列证据、后给结论」，被否决：它与 Claude Code harness 层「首句回答 what happened」的输出规范对冲，而本次问题的病根在「结论形成前没取证」，不在「结论放在了段落开头」。最终措辞为 "Presentation may still lead with the conclusion — but nothing may be asserted that was not read first."
- **Definitions 增补 "Judgment deliverable"**，沿用该文件既有的「给规则中的模糊词锚定义」惯例。

## 影响范围
仅 README.md：Step 1.4 改写、新增 1.5、Definitions 增一条；重编号导致 triage 由 1.5 变 1.6，两处交叉引用（Timing 节的 Surface fix、Definitions 的 Obvious / clear）同步更新。

该文件经 symlink 即为 Claude Code / Codex / opencode 的全局规则，改动即时生效，无需同步步骤。

## 已知遗留 / 后续待办
- P0 未解：README 与 `~/.claude/rules/common/*` 的哲学冲突（后者要求 TDD MANDATORY、每次改码跑 code-reviewer、新功能先出五件套文档）仍在，裁量权仍落在模型侧。
- `pre-commit-flush-reminder.sh` 的「每会话只提醒一次」设计意味着长会话中后续 arc 的 commit 不再收到提醒（本次 flush 即由规则自觉触发，hook 未介入）。这是当初为避免打扰而做的取舍，若后续发现漏 flush 频繁，可改为按 flush 事件重置 marker。
- 本条规则尚无反馈回路验证其是否真的改变了行为。

## 验证
grep 确认无残留 `Step 1.5 triage` / `Step 1.5 skip` 旧引用；Step 1 编号 1–7 连续；全文 `Step 1.N` 引用逐条核对指向正确条目。
