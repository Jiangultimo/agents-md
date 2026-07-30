---
date: 2026-07-30
slug: hooks-sop-brief-and-timing-fixes
title: Hooks SOP 六项优化：brief 子命令、时序修正、注入块收敛
tags: [hooks, sop, agent-rules]
related: []
---

## 背景 / 触发动机
Review README 的 Hooks-managed Docs 部分时，对照 hooks/ 实现发现 6 项问题：
1 处事实错误（"invisible to search" 与实现不符）、2 处每会话成本（task-start 三连命令 + 空态 ~20 行噪音输出）、1 处指令漂移（init.sh 注入块的时序描述与全局 arc 制矛盾）、1 个设计缺口（pending snapshot 会话终止时静默丢失）、1 处冗余。

## 关键决策
- `doc.sh` 新增 `brief` 子命令替代 task-start 三连：空 kind 压缩为一行，表格只输出数据行，超 10 条截断提示。选择实现层方案而非仅文档层合并命令，因输出压缩只能在脚本侧做。
- "invisible to search" 改文档不改实现——search 能扫到全部文件是有用行为（连 INDEX 也可搜）。
- pending snapshot 增加两条时序规则：执行 `git commit` 前强制 flush（锚定动作而非用户话术）；会话终止丢失定为 accepted trade-off，明文禁止为对冲而预写文件。
- init.sh 注入块删去时序语义（原文案"arc end 立即 new"与全局"pending→flush"矛盾），收敛为纯指针 + "do not duplicate them here" 守护语。
- task-start 增加跳过条件：对话式/与项目历史无关的独立请求不跑 brief。

## 影响范围
README.md（Hooks-managed Docs 节，经 symlink 即时生效于 Claude Code/Codex/opencode）、hooks/doc.sh（新子命令，向后兼容）、hooks/init.sh（注入块文案）、hooks/README.md（同步）。

## 已知遗留 / 后续待办
- hooks 脚本无自动化测试（本次为手动四路径验证）。
- 改动未提交。
- 曾建议的 .gitignore（.DS_Store）未处理。

## 验证
`bash -n` 语法检查；实测四路径：空 docs/ 项目 brief 输出 4 行、13 条数据截断为 10+提示行、decision 表格正常、init.sh 注入块为新文案。测试用临时项目已清理。
