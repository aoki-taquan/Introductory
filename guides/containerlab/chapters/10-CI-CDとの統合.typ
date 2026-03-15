= CI/CD との統合

== GitHub Actions での利用

Containerlab はシングルバイナリで動作するため、CI/CD パイプラインとの統合が容易です。

=== 基本的なワークフロー

```yaml
name: Network Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  network-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install containerlab
        run: |
          bash -c "$(curl -sL https://get.containerlab.dev)"

      - name: Deploy lab
        run: |
          sudo containerlab deploy --topo lab.clab.yml

      - name: Run tests
        run: |
          # ノードへの疎通確認
          docker exec clab-lab-srl1 \
            ip netns exec srbase ping -c 3 192.168.1.2
          # 自動化テストの実行
          python -m pytest tests/

      - name: Destroy lab
        if: always()
        run: |
          sudo containerlab destroy --topo lab.clab.yml
```

=== 公式 GitHub Action

Containerlab は公式の GitHub Action も提供しています：

```yaml
- name: Deploy containerlab
  uses: srl-labs/containerlab-action@v1
  with:
    topo: lab.clab.yml
```

== GitLab CI での利用

```yaml
network-test:
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - bash -c "$(curl -sL https://get.containerlab.dev)"
  script:
    - containerlab deploy --topo lab.clab.yml
    - python -m pytest tests/
  after_script:
    - containerlab destroy --topo lab.clab.yml
```

== ネットワークテストの自動化

=== Robot Framework との組み合わせ

```bash
# ラボデプロイ後にテストを実行
sudo containerlab deploy --topo lab.clab.yml
robot --outputdir results tests/
sudo containerlab destroy --topo lab.clab.yml
```

=== pytest によるテスト

```python
import subprocess

def test_bgp_neighbor():
    """BGP ネイバーが確立されていることを確認"""
    result = subprocess.run(
        ["docker", "exec", "clab-lab-srl1",
         "sr_cli", "show", "network-instance",
         "default", "protocols", "bgp", "neighbor"],
        capture_output=True, text=True
    )
    assert "established" in result.stdout.lower()

def test_reachability():
    """エンドツーエンドの疎通を確認"""
    result = subprocess.run(
        ["docker", "exec", "clab-lab-client",
         "ping", "-c", "3", "10.0.0.1"],
        capture_output=True, text=True
    )
    assert result.returncode == 0
```

== ネットワーク変更の検証パイプライン

ネットワーク設定の変更を PR ベースで管理し、自動テストで検証するフローです：

+ エンジニアが設定ファイルを変更し PR を作成
+ CI がラボをデプロイし、変更後の設定を適用
+ 自動テスト（疎通確認、BGP 状態、ルーティングテーブル検証）を実行
+ テスト合格後にマージ、本番環境に適用

このアプローチにより、ネットワーク変更の品質を自動的に担保できます。
