---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*)
description: 按照 Conventional Commit 规范生成中文 Git 提交信息并提交
---

请根据以下要求生成 Git 提交信息和提交命令：
1. 遵循 Conventional Commit 规范。
2. 使用简体中文描述。
3. 提交信息格式：
   <type>(<scope>): <subject>

   [可选 body]
   [可选 footer]

4. 各部分规则：
   - type：必须是以下之一
     feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert
   - scope：可选，表示影响范围，如模块/功能名，使用小写英文。
   - subject：简洁、清晰地描述修改，**不超过 50 个字符**，不用大写字母开头，不加句号。
   - body：可选，说明修改动机、变化的细节。每行不超过 72 字符。
   - footer：可选，用于 BREAKING CHANGE 或关联 issue（如 `Closes #123`）。

5. 包含多种类型的 type 时按照 4 中给的 type 顺序多次提交

## 执行步骤与命令规范

### 第一步：查看当前状态
```bash
git status
```
了解哪些文件有变更（已暂存 / 未暂存 / 未跟踪）。

### 第二步：查看具体变更内容
```bash
# 查看已暂存 + 未暂存的所有变更
git diff HEAD

# 若只想看未暂存的变更
git diff

# 若只想看已暂存的变更
git diff --cached
```

### 第三步：查看近期提交风格（可选）
```bash
git log --oneline -10
```
参考已有提交的 scope 写法，保持一致性。

### 第四步：暂存文件
按变更类型分批暂存，**不要使用 `git add -A` 或 `git add .`**，逐文件或逐目录指定，避免误提交无关文件（如 `.env`、生成物等）：
```bash
# 暂存单个文件
git add <file>

# 暂存某目录下所有变更
git add <directory>/

# 暂存多个文件
git add <file1> <file2>
```

### 第五步：提交
使用 HEREDOC 传入提交信息，确保多行格式正确：
```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<body（可选）>

<footer（可选）>
EOF
)"
```

### 第六步：确认提交结果
```bash
git status
```
确认工作区已清洁，无遗漏文件。

## tips
- 默认当前目录为工作目录
- 禁止使用 `--no-verify` 跳过 hooks
- 禁止 `git commit --amend`（除非用户明确要求）
- 若存在多种 type，按第 5 条顺序拆分为多次提交，每次只暂存对应文件
