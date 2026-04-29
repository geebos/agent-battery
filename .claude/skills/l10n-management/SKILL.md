---
name: l10n-management
description: 翻译文案维护规范，覆盖 YAML 文件格式、key 命名约定、合并脚本使用与冲突规则。当新增、修改或查询本地化文案（l10n、xcstrings、YAML 翻译文件）时使用。
when_to_use: 用户新增翻译 key、修改 YAML 文案、运行 make l10n、讨论 xcstrings 结构时加载。
user-invocable: false
---

# 翻译文案维护规范

## 文件结构
```
l10n/                        # 所有翻译源文件，纳入版本库
├── Basic.xcstrings          # 特殊 key（格式串、无前缀 key），手动维护
├── action.yaml
├── common.yaml
├── dashboard.yaml
├── dashboard/
│   ├── expense.yaml
│   └── ...
└── ...
ourpets/Shared/Localization/
└── Localizable.xcstrings    # 由脚本生成，不纳入版本库（已加入 .gitignore）
scripts/
└── merge_l10n.py            # 合并脚本
```

## Key 命名约定
- YAML 文件路径决定 key 前缀：`l10n/profile/pet.yaml` + yaml key `add` → xcstrings key `profile.pet.add`
- 无前缀或格式串 key（如 `%@ · %@`、`date`）放在 `Basic.xcstrings`

## YAML 文件格式
```yaml
add:
  en: "Add Pet"
  zh: "添加宠物"
edit:
  en: "Edit Pet"
  zh: "编辑宠物"
```
语言代码：`en`（英语）、`zh`（简体中文，自动映射为 xcstrings 的 `zh-Hans`）

## 新增翻译文案
1. 在 `l10n/` 对应目录的 yaml 文件中添加 key + 翻译
2. 运行合并脚本生成 `Localizable.xcstrings`：
   ```bash
   make l10n
   ```
3. 提交 yaml 文件变更（`Localizable.xcstrings` 不提交）

## 冲突规则
`Basic.xcstrings` 中的值优先级最高，YAML 只补充缺失的 key 或缺失语言的翻译。
