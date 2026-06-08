# Cardinal System

Cardinalは、ゼフィリア世界とすべてのシステムを管理する中枢です。

## ディレクトリ構成

```
Cardinal/
├── System/          ← Cardinalシステム設定・ユイの記憶・ログ
│   ├── yui/         ← ユイの記憶ファイル (memory.md)
│   └── logs/        ← エージェントログ
├── Worlds/
│   └── Zephyria/    ← ゼフィリア世界データ（JSON群）
└── Company/         ← 渡邊カンパニー業務データ（旧Obsidian Vault）
```

## パス定義

```bash
CARDINAL="/Users/watanaberyuutarou/Library/Mobile Documents/iCloud~md~obsidian/Documents/Cardinal"
WORLD="$CARDINAL/Worlds/Zephyria"
SYSTEM="$CARDINAL/System"
VAULT="$CARDINAL/Company"
```

## 注意事項

- `Company/` 内のObsidianファイルはiCloud経由で同期される
- `Worlds/Zephyria/` のJSONはCardinalシステム（/yuiコマンド）が読み書きする
- `System/yui/memory.md` はユイの長期記憶ファイル
