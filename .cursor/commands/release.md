请按以下流程发布新版本，使用 Git 注解标签（annotated tag）携带更新说明，并自动递增版本号。

## 1. 确定上一次正式版本

- 通过 `git tag --list 'v*' --sort=-v:refname` 列出所有版本标签。
- 过滤掉包含 `beta`、`alpha`、`rc` 等预发布字样的标签，取第一个作为「上一次正式版本」`LAST_STABLE`。
- 若仓库尚无正式版本，提示用户并以 `v0.0.0` 作为基线。

## 2. 收集变更日志

- 用 `git log "$LAST_STABLE..HEAD" --no-merges --pretty=format:'%s'` 获取该范围内的全部 commit message（subject）。
- 若无任何提交，停止流程并告知用户。
- 按 Conventional Commit 的 type 归类（feat / fix / perf / refactor / docs / build / ci / chore / test / style / revert），生成简体中文的更新列表，例如：

  ```
  ## 新功能
  - feat(xxx): ...

  ## 修复
  - fix(xxx): ...

  ## 其他
  - chore: ...
  ```

- 仅保留对用户有意义的条目，可对 commit message 做轻度润色但不要伪造内容。

## 3. 自动递增版本号

- 解析 `LAST_STABLE`（形如 `vMAJOR.MINOR.PATCH`）。
- 根据收集到的 commit type 决定递增策略：
  - 含 `feat` → MINOR +1，PATCH 归零；
  - 仅有 `fix` / `perf` / `refactor` 等 → PATCH +1；
  - 含 `BREAKING CHANGE` 或 `!:` → MAJOR +1，MINOR/PATCH 归零。
- 得到新的 `NEW_TAG`（如 `v1.1.0`），并向用户确认是否使用该版本号，可让用户覆盖。

## 4. 创建注解标签

- 标签信息格式：

  ```
  <NEW_TAG>

  <第 2 步生成的更新列表>
  ```

- 推荐用 here-doc 写入，避免引号转义问题：

  ```bash
  git tag -a "$NEW_TAG" -F - <<EOF
  $NEW_TAG

  $RELEASE_NOTES
  EOF
  ```

- 创建后用 `git show "$NEW_TAG"` 让用户检查，必要时 `git tag -d "$NEW_TAG"` 后重新创建。

## 5. 推送标签

- 经用户确认后执行 `git push origin "$NEW_TAG"`，触发 `.github/workflows/release.yml` 中的发布流程。
- GitHub Action 会读取该注解标签的 description 作为 Release description，因此本地标签里的更新列表即最终展示给用户的发版说明。

## 注意事项

- 不要直接 `git tag <name>`（轻量标签无 description），必须使用 `-a` 创建注解标签。
- 默认操作当前 git 仓库；执行破坏性命令（删除/强推标签）前先与用户确认。
- 若用户传入参数，可作为新版本号或版本递增策略的覆盖值。
