= 高度な使い方

== Hooks（フック）

Hooks は Claude Code のツール実行の前後にカスタムスクリプトを実行する仕組みです。
コード品質のチェックや自動フォーマットなどに活用できます。

=== フックの種類

- *PreToolUse*：ツール実行前に実行される
- *PostToolUse*：ツール実行後に実行される
- *Notification*：通知イベント時に実行される
- *SessionStart*：セッション開始時に実行される

=== 設定例

`.claude/settings.json` にフックを定義します：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write $CLAUDE_FILE_PATH"
          }
        ]
      }
    ]
  }
}
```

この例では、ファイルの書き込みや編集の後に自動的に Prettier でフォーマットします。

== ヘッドレスモード

CI/CD パイプラインやスクリプトから Claude Code を非対話的に実行できます：

```bash
claude -p "テストを実行して結果を報告して" \
  --output-format json \
  --max-turns 10
```

=== 出力フォーマット

- `text`：プレーンテキスト（デフォルト）
- `json`：JSON 形式で出力
- `stream-json`：ストリーミング JSON

== マルチターンのパイプライン

複数のプロンプトを連鎖させて複雑なワークフローを構築できます：

```bash
# 最初のプロンプト
claude -p "このプロジェクトの問題点を分析して" \
  --output-format json > analysis.json

# 結果を使って次のプロンプト
cat analysis.json | claude -p "この分析をもとに修正して" \
  --continue
```

== カスタムスラッシュコマンド

プロジェクト固有のスラッシュコマンドを定義できます。
`.claude/commands/` ディレクトリにマークダウンファイルを配置します：

```
.claude/commands/review.md
```

ファイルの内容がコマンドのプロンプトテンプレートになります：

```markdown
以下の観点でコードレビューを行ってください：
1. セキュリティ上の問題
2. パフォーマンスの問題
3. 可読性の改善点

対象: $ARGUMENTS
```

`/project:review src/auth.ts` のように呼び出せます。

== Claude Agent SDK

Claude Code の機能をプログラムから利用するための SDK です。
カスタムエージェントの構築に使用できます：

```typescript
import { Agent } from "claude-agent-sdk";

const agent = new Agent({
  model: "claude-sonnet-4-5-20250514",
});

const result = await agent.run("テストを実行して");
```
