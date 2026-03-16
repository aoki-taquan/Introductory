= API と自動化

NetBox は REST API と GraphQL API を提供しており、外部システムとの連携や自動化が容易です。

== API トークンの発行

=== Web UI からの発行

+ 右上のユーザーアイコン > *API Tokens* をクリック
+ 「+ Add a Token」をクリック
+ トークンの説明を入力して「Save」

=== API トークンの管理

#table(
  columns: (auto, auto),
  inset: 8pt,
  align: left,
  table.header(
    [*設定*], [*説明*],
  ),
  [Key], [トークン文字列（40 文字）],
  [Write Enabled], [書き込み権限の有無],
  [Expires], [有効期限（任意）],
  [Allowed IPs], [利用を許可する IP アドレス（任意）],
  [Description], [説明],
)

== REST API の基本

=== API ドキュメント

NetBox は Swagger UI を内蔵しています。
`http://<NetBox URL>/api/docs/` でインタラクティブなAPIドキュメントを確認できます。

=== 基本的なリクエスト

```bash
# デバイス一覧の取得
curl -H "Authorization: Token <your-token>" \
     -H "Content-Type: application/json" \
     http://netbox.example.com/api/dcim/devices/

# 特定デバイスの取得
curl -H "Authorization: Token <your-token>" \
     http://netbox.example.com/api/dcim/devices/?name=core-sw-01

# デバイスの作成
curl -X POST \
     -H "Authorization: Token <your-token>" \
     -H "Content-Type: application/json" \
     -d '{"name": "access-sw-01", "device_type": 1, "device_role": 2, "site": 3}' \
     http://netbox.example.com/api/dcim/devices/
```

=== フィルタリング

```bash
# サイトでフィルタ
GET /api/dcim/devices/?site=tokyo-dc

# ステータスでフィルタ
GET /api/dcim/devices/?status=active

# 複数条件（AND）
GET /api/dcim/devices/?site=tokyo-dc&role=switch

# 文字列検索
GET /api/dcim/devices/?q=core-sw
```

=== ページネーション

API レスポンスには `count`、`next`、`previous`、`results` が含まれます。

```bash
# 最初の 50 件（デフォルト）
GET /api/dcim/devices/

# 件数を変更
GET /api/dcim/devices/?limit=100&offset=0

# 全件取得（limit=0）
GET /api/dcim/devices/?limit=0
```

== Python からの API 利用

=== requests ライブラリを使う場合

```python
import requests

NETBOX_URL = "http://netbox.example.com"
TOKEN = "your-api-token"

headers = {
    "Authorization": f"Token {TOKEN}",
    "Content-Type": "application/json",
}

# デバイス一覧の取得
response = requests.get(
    f"{NETBOX_URL}/api/dcim/devices/",
    headers=headers,
    params={"site": "tokyo-dc", "status": "active"}
)
devices = response.json()["results"]

for device in devices:
    ip = device['primary_ip4']['address'] if device['primary_ip4'] else 'N/A'
    print(f"{device['name']}: {ip}")
```

=== pynetbox ライブラリ（推奨）

公式 Python クライアントライブラリ `pynetbox` を使うと、より簡潔に書けます。

```bash
pip install pynetbox
```

```python
import pynetbox

nb = pynetbox.api(
    url="http://netbox.example.com",
    token="your-api-token"
)

# デバイス一覧
devices = nb.dcim.devices.filter(site="tokyo-dc", status="active")
for device in devices:
    ip = device.primary_ip4.address if device.primary_ip4 else 'N/A'
    print(device.name, ip)

# デバイスの作成
device_type = nb.dcim.device_types.get(slug="catalyst-9300-48p")
device_role = nb.dcim.device_roles.get(slug="access-switch")
site = nb.dcim.sites.get(slug="tokyo-dc")

new_device = nb.dcim.devices.create(
    name="access-sw-02",
    device_type=device_type.id,
    device_role=device_role.id,
    site=site.id,
    status="active",
)
print(f"Created: {new_device}")

# IP アドレスの割り当て
ip = nb.ipam.ip_addresses.create(
    address="10.0.1.10/24",
    status="active",
    assigned_object_type="dcim.interface",
    assigned_object_id=new_device.interfaces()[0].id,
)
```

== GraphQL API

REST API に加え、GraphQL API も利用できます。

```
POST /graphql/
```

```graphql
query {
  device_list(site: "tokyo-dc", status: "active") {
    name
    primary_ip4 {
      address
    }
    interfaces {
      name
      enabled
      ip_addresses {
        address
      }
    }
  }
}
```

GraphQL はネストしたデータを 1 回のリクエストで取得でき、
過剰なデータ取得を防げます。

== Ansible との連携

=== netbox.netbox コレクション

Ansible Galaxy から NetBox 公式コレクションをインストールします。

```bash
ansible-galaxy collection install netbox.netbox
```

=== Dynamic Inventory（動的インベントリ）

```yaml
# inventory/netbox.yml
plugin: netbox.netbox.nb_inventory
api_endpoint: http://netbox.example.com
token: your-api-token
validate_certs: false
group_by:
  - site
  - device_roles
  - platforms
device_query_filters:
  - status: active
compose:
  ansible_host: primary_ip4.address | ipaddr('address')
```

```bash
ansible-inventory -i inventory/netbox.yml --list
```

=== Ansible モジュールの使用例

```yaml
- name: NetBox にデバイスを登録
  netbox.netbox.netbox_device:
    netbox_url: http://netbox.example.com
    netbox_token: "{{ netbox_token }}"
    data:
      name: "{{ inventory_hostname }}"
      device_type: "{{ device_type }}"
      device_role: "{{ device_role }}"
      site: "{{ site }}"
      status: active
    state: present
```

== Terraform との連携

```hcl
terraform {
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 3.0"
    }
  }
}

provider "netbox" {
  server_url = "http://netbox.example.com"
  api_token  = var.netbox_token
}

data "netbox_prefix" "management" {
  prefix = "10.0.2.0/24"
}

resource "netbox_available_ip_address" "vm_ip" {
  prefix_id   = data.netbox_prefix.management.id
  status      = "active"
  dns_name    = "web-server-03.example.com"
  description = "Terraform で割り当て"
}
```

== NAPALM 連携

NetBox は NAPALM と連携して、実機から設定情報を取得できます。

デバイスの Platform に NAPALM ドライバーを設定します：

- `ios`（Cisco IOS）
- `iosxr`（Cisco IOS-XR）
- `eos`（Arista EOS）
- `junos`（Juniper Junos）
- `nxos`（Cisco NX-OS）

デバイス詳細画面の「NAPALM」タブから以下の情報を取得できます：

- Facts（基本情報）
- Interfaces（インターフェース状態）
- ARP テーブル
- LLDP ネイバー
