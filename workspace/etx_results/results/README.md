# ETX Task Results

このディレクトリには、ETXで実行されたタスクの結果が一時的に保存されます。

## 構造

```
results/
└── <user>_<timestamp>/
    └── <task_name>_result.txt
```

## クリーンアップ

- ローカルで結果を取得後、自動的に削除されます
- GitHub Actions により3日後に自動削除されます
- ローカルアーカイブ: `../.archive/YYYYMM/` に永続保存
