= カスタマイズ

NetBox は柔軟なカスタマイズ機能を提供しています。

== カスタムフィールド（Custom Fields）

標準フィールドにない情報を追加できます。

=== カスタムフィールドの作成

Customization > Custom Fields から作成します。

=== フィールドタイプ

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*タイプ*], [*説明*],
  ),
  [Text], [短いテキスト],
  [Long text], [長いテキスト（マークダウン対応）],
  [Integer], [整数],
  [Decimal], [小数],
  [Boolean], [真偽値（チェックボックス）],
  [Date], [日付],
  [Date & time], [日時],
  [URL], [URL],
  [JSON], [JSON データ],
  [Selection], [プルダウン選択（値は別途定義）],
  [Multiple selection], [複数選択],
  [Object], [別のNetBox オブジェクトへの参照],
  [Multiple objects], [複数オブジェクトへの参照],
)

=== 設定項目

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*設定*], [*説明*],
  ),
  [Name], [フィールド名（英数字・アンダースコア）],
  [Label], [UI 表示名],
  [Content Types], [適用するオブジェクト種別（複数可）],
  [Required], [必須入力にするか],
  [Default], [デフォルト値],
  [Filter Logic], [フィルタリングの挙動],
  [UI Visibility], [UI での表示方法],
  [Weight], [表示順（数値が大きいほど下位）],
  [Group Name], [グループ化の名前],
)

=== 活用例

```
カスタムフィールド名: lifecycle_end_date
ラベル: 保守期限
タイプ: Date
適用対象: Device, Virtual Machine
必須: No
```

```
カスタムフィールド名: monitoring_url
ラベル: 監視 URL
タイプ: URL
適用対象: Device, Virtual Machine
必須: No
```

== カスタム選択肢（Custom Field Choices）

Selection タイプのカスタムフィールドで使用する選択肢を管理します。

Customization > Custom Field Choice Sets から作成します。

例：
```
Choice Set: 運用フェーズ
  choices:
    - planning（計画中）
    - testing（テスト中）
    - production（本番稼働）
    - eol（EOL）
```

== カスタムリンク（Custom Links）

オブジェクト詳細画面に外部リンクや内部リンクを追加できます。

Customization > Custom Links から作成します。

=== 活用例

監視システムへのリンク：

```
Name: Zabbix（監視）
Content Types: Device
URL: https://zabbix.example.com/zabbix/hosts.php?filter_host={{ object.name }}
```

ドキュメントへのリンク：

```
Name: Confluence ドキュメント
Content Types: Device
URL: https://wiki.example.com/search?q={{ object.name }}
```

== エクスポートテンプレート（Export Templates）

オブジェクトの一覧を独自フォーマットでエクスポートできます。

Customization > Export Templates から Jinja2 テンプレートを作成します。

=== 活用例（Ansible インベントリの生成）

```jinja2
[all]
{% for device in queryset %}
{{ device.name }} ansible_host={{ device.primary_ip4.address | ansible.utils.ipaddr('address') }}
{% endfor %}

[{{ group_by }}]
{% for device in queryset %}
{{ device.name }}
{% endfor %}
```

== Webhook

オブジェクトの作成・変更・削除時に外部システムへ HTTP リクエストを送信できます。

Customization > Webhooks から作成します。

=== 主要設定

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*設定*], [*説明*],
  ),
  [Name], [Webhook 名],
  [Content Types], [対象オブジェクト種別],
  [Events], [作成・更新・削除のいずれかを選択],
  [URL], [送信先 URL],
  [HTTP Method], [POST / PUT / PATCH など],
  [HTTP Content Type], [application/json など],
  [Additional Headers], [追加 HTTP ヘッダー],
  [Body Template], [送信ボディの Jinja2 テンプレート],
  [Secret], [HMAC 署名用シークレット],
  [SSL Verification], [TLS 証明書の検証],
  [Conditions], [送信条件のフィルタ（JSON）],
)

=== 活用例

新しいデバイスが登録されたときに Slack へ通知：

```
URL: https://hooks.slack.com/services/XXX/YYY/ZZZ
Event: Created
Content Type: Device
Body Template:
{
  "text": "新しいデバイスが登録されました: {{ data.name }} @ {{ data.site.name }}"
}
```

== スクリプト（Scripts）

カスタム Python スクリプトを Web UI から実行できます。

Customization > Scripts からスクリプトを管理します。

=== スクリプトの例

一括でデバイスのステータスを変更するスクリプト：

```python
from netbox.scripts import Script, MultiObjectVar
from dcim.models import Device

class BulkStatusUpdate(Script):
    class Meta:
        name = "Bulk Device Status Update"
        description = "複数デバイスのステータスを一括変更"

    devices = MultiObjectVar(
        model=Device,
        description="対象デバイスを選択"
    )

    def run(self, data, commit):
        for device in data['devices']:
            device.status = 'active'
            device.save()
            self.log_success(f"{device.name} を Active に変更しました")
```

== 設定コンテキスト（Config Contexts）

デバイスや仮想マシンに構造化データ（JSON / YAML）を付与できます。
Ansible の group_vars や host_vars のような使い方が可能です。

Customization > Config Contexts から作成します。

=== 活用例

NTP サーバーの設定を地域ごとに付与：

```json
{
  "ntp": {
    "servers": [
      "ntp1.example.com",
      "ntp2.example.com"
    ],
    "timezone": "Asia/Tokyo"
  }
}
```

適用条件：Regions = Japan

デバイス詳細画面の「Config Context」タブで、
適用されたすべてのコンテキストがマージされた結果を確認できます。
