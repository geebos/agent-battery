---
name: l10n-management
description: 翻译文案维护规范，覆盖本项目的 YAML 翻译源、key 命名约定、xcstrings 生成流程、合并脚本使用与冲突规则。当新增、修改或查询本地化文案（l10n、xcstrings、YAML 翻译文件）时使用。
---

# 翻译文案维护规范

## 文件结构

```text
l10n/                                      # 翻译源文件，纳入版本库
├── formatter.yaml
├── displayMode.yaml
├── menu.yaml
└── ...
agent-battery/Shared/Localization/
└── Localizable.xcstrings                  # 由脚本生成，被 .gitignore 忽略
script/
└── merge_l10n.py                          # 合并脚本
Makefile                                   # make l10n 入口
```

## Key 命名约定

- YAML 文件路径决定 key 前缀：`l10n/formatter.yaml` + yaml key `resetPassed` -> xcstrings key `formatter.resetPassed`
- 嵌套目录同样参与前缀：`l10n/profile/pet.yaml` + yaml key `add` -> xcstrings key `profile.pet.add`
- 无前缀或特殊格式串 key 应优先放到 base/基础 xcstrings；如果当前项目没有基础文件，先确认是否需要新增基础文件，避免把结构性 key 混进普通 YAML。

## YAML 文件格式

```yaml
resetPassed:
  en: "Reset time passed"
  zh: "重置时间已过"
```

语言代码：

- `en`：英语
- `zh`：简体中文，会由合并脚本映射为 xcstrings 的 `zh-Hans`

## 新增或修改翻译文案

1. 在 `l10n/` 对应 YAML 文件中添加或修改 key 与翻译。
2. 运行合并脚本生成 `Localizable.xcstrings`：
   ```bash
   make l10n
   ```
3. 提交 YAML 文件变更。`agent-battery/Shared/Localization/Localizable.xcstrings` 通常不提交，因为它已被 `.gitignore` 忽略。
4. 如果本地构建需要立即验证生成结果，可保留工作区里的 `Localizable.xcstrings` 生成物，但不要把它当成源文件手动维护。

## 冲突规则

`merge_l10n.py` 以现有目标 xcstrings 或可选基础 xcstrings 作为优先来源。YAML 用于补充缺失 key 或缺失语言翻译；如果目标文件中已存在同一语言的值，脚本不会覆盖它。

## 工作习惯

- 优先编辑 `l10n/*.yaml`，不要直接编辑生成的 `Localizable.xcstrings`，除非用户明确要求临时同步生成物。
- 修改文案后，用 `rg -n "keyName|translation" l10n agent-battery` 确认调用点和 key 是否一致。
- 涉及 SwiftUI `Text("some.key")` 时，确认 key 在 YAML 中的完整名称包含文件前缀。
