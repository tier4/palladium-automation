# Task Results (Legacy)

**注意**: このディレクトリは現在使用されていません。

## 現在の結果保存先

SSH同期実行方式では、結果は以下に直接保存されます：

```
workspace/etx_results/.archive/YYYYMM/
└── <user>_<timestamp>_<task_name>_result.txt
```

## レガシー構造（参考）

以前のGitHub非同期モード（未実装）では以下の構造を想定していました：

```
results/
└── <user>_<timestamp>/
    └── <task_name>_result.txt
```

## 詳細

- SSH同期実行方式の詳細: `../../docs/ssh_direct_retrieval_test.md`
- レガシー実装計画: `../../docs/.legacy/github_integration_plan.md`
