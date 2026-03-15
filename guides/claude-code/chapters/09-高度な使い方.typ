= 高度な使い方

== Hooks（フック）

Hooks は Claude Code のライフサイクルの特定のタイミングでカスタムスクリプトを実行する仕組みです。

=== フックイベントの種類

#table(
  columns: (auto, 1fr),
  align: (left, left),
  table.header([*イベント*], [*タイミング*]),
  [`SessionStart`], [セッション開始・再開時],
  [`UserPromptSubmit`], [ユーザーがプロンプトを送信した時],
  [`PreToolUse`], [ツール実行前],
  [`PostToolUse`], [ツール実行成功後],
  [`PostToolUseFailure`], [ツール実行失敗後],
  [`PermissionRequest`], [権限ダイアログ表示時],
  [`Notification`], [Claude が入力待ちの時],
  [`SubagentStart/Stop`], [サブエージェントのライフサイクル],
  [`Stop`], [Claude が応答を完了した時],
  [`PreCompact/PostCompact`], [コンテキスト圧縮の前後],
  [`ConfigChange`], [設定ファイル変更時],
)

=== フックの設定

`.claude/settings.json` にフックを定義します：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
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

この例ではファイル編集後に自動的に Prettier でフォーマットします。

=== フックの種類

- *Command*：シェルコマンドを実行
- *HTTP*：外部エンドポイントに POST
- *Prompt*：LLM で yes/no 判定
- *Agent*：ツール付きのマルチターン検証

== サブエージェント

サブエージェントは隔離されたコンテキストウィンドウで動作する特殊なエージェントです。

=== ビルトインエージェント

- *Explore*：読み取り専用、高速なコードベース探索
- *Plan*：実装計画の設計
- *General-purpose*：汎用的なタスク実行

=== カスタムサブエージェントの作成

`/agents` コマンドで独自のサブエージェントを作成できます：

+ スコープ（User / Project）を選択
+ 目的を記述
+ 利用可能なツールを選択
+ モデルを指定

各サブエージェントには独自のシステムプロンプト、ツール制限、モデル設定が可能です。

== ヘッドレスモード

CI/CD パイプラインやスクリプトから非対話的に実行できます：

```bash
claude -p "テストを実行して結果を報告して" \
  --output-format json \
  --max-turns 10
```

=== 出力フォーマット

- `text`：プレーンテキスト（デフォルト）
- `json`：JSON 形式
- `stream-json`：ストリーミング JSON

== マルチターンパイプライン

複数のプロンプトを連鎖させて複雑なワークフローを構築できます：

```bash
# 分析結果をファイルに保存
claude -p "このプロジェクトの問題点を分析して" \
  --output-format json > analysis.json

# 結果を使って次の処理
cat analysis.json | claude -p "この分析をもとに修正して" \
  --continue
```

== カスタムスラッシュコマンド

プロジェクト固有のスラッシュコマンドを定義できます。
`.claude/commands/` にマークダウンファイルを配置します：

```
.claude/commands/review.md
```

ファイルの内容がプロンプトテンプレートになります：

```markdown
以下の観点でコードレビューを行ってください：
1. セキュリティ上の問題
2. パフォーマンスの問題
3. 可読性の改善点

対象: $ARGUMENTS
```

`/project:review src/auth.ts` のように呼び出せます。

== 大規模変更（/batch）

`/batch` コマンドで大規模な並列変更を実行できます：

```
/batch src/ 以下の jQuery を React に移行して
```

Claude は並列プランを作成し、各サブエージェントがそれぞれの変更を担当します。

== 権限の細かい制御

権限ルールはグロブパターンや正規表現で細かく指定できます：

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Bash(npm run *)",
      "Edit(/src/**/*.ts)",
      "WebFetch(domain:github.com)",
      "Agent(Explore)"
    ],
    "deny": [
      "Bash(rm *)"
    ]
  }
}
```

== Claude Agent SDK

Claude Code の機能をプログラムから利用するための SDK です：

```typescript
import { Agent } from "claude-agent-sdk";

const agent = new Agent({
  model: "claude-sonnet-4-5-20250514",
});

const result = await agent.run("テストを実行して");
```
