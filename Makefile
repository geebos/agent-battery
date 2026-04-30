L10N_DIR     := l10n
LOCALIZABLE  := agent-battery/Shared/Localization/Localizable.xcstrings
MERGE_SCRIPT := script/merge_l10n.py

.PHONY: l10n

## l10n: 合并 l10n/ → agent-battery/Shared/Localization/Localizable.xcstrings
l10n:
	python3 $(MERGE_SCRIPT) $(L10N_DIR) $(LOCALIZABLE)
