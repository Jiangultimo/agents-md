---
date: 2026-07-30
slug: p1-model-neutral-rules-and-commit-hook
title: P1 落地：规则去模型名 + commit 前 flush 提醒 hook
tags: [hooks, harness, agent-rules]
related: [0001-reminder-hook-vs-marker-file]
---

## 背景 / 触发动机
对本 repo 的 agent-rules/harness 评估给出两条 P1：
1. `~/.claude/rules/common/performance.md` 硬编码了具体模型名——事实性内容随模型发布腐烂，且每会话注入。
2. 「commit 前 flush pending snapshot」只是规则祈使句，无 harness 强制。

## 关键决策
- 模型选择策略重写为三个能力层级（smallest capable / default-mid / highest reasoning），并新增守护规则：NEVER hardcode model names —— 具体型号在决策时通过 claude-api skill 或官方文档解析。全局扫描确认无其他模型名残留。
- 新增 `hooks/pre-commit-flush-reminder.sh`（PreToolUse/Bash，接线于用户级 settings.json）。设计取舍见 [[0001-reminder-hook-vs-marker-file]]：提醒式而非 marker 落盘，每会话最多拦一次。
- 不用 `if: "Bash(git *)"` 前缀过滤——会漏掉 `cd x && git commit` 复合命令；脚本足够轻，全量 matcher。
- `~/.agent-hooks` 命名保留：目录里现在有真 harness hook，评估中的改名建议作废。

## 影响范围
repo 内：`hooks/pre-commit-flush-reminder.sh`（新增）、`hooks/README.md`（Layout）。
repo 外：`~/.claude/rules/common/performance.md`（重写模型节）、`~/.claude/settings.json`（hooks.PreToolUse 接线）——均不受本 repo 版本管理。

## 已知遗留 / 后续待办
- performance.md 其余事实性内容（thinking token 上限、快捷键）同样会腐烂，未在本次范围。
- P0（README 与 rules/common 双规则源哲学冲突）未处理。
- hooks 脚本仍无自动化 smoke test。

## 验证
脚本层六路径单测（拦截/同会话放行/非 commit/无 pending/管道误报防护/坏 JSON fail-open）全过；接线后实弹验证：`git commit --help` 被真实拦截（settings 热加载生效），二次运行放行。
