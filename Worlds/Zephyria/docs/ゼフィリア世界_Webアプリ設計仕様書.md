> これが仕様だ。文句は言わせない。 — ゼーリエ

# ゼフィリア世界 Webアプリ設計仕様書

- バージョン: 1.0
- 作成日: 2026-04-23
- 作成者: ゼーリエ（09_3125制作・納品事業部）
- プロジェクト名: **Zephyria** — Cardinal System Web Interface

---

## 目次

1. プロジェクト概要
2. アーキテクチャ全体図
3. 技術スタック定義
4. 画面遷移図
5. 画面別コンポーネント設計
6. Supabaseテーブル定義
7. API Routes設計
8. 同期スクリプト仕様（Python）
9. 実装フェーズ計画（Phase 1〜3）
10. 非機能要件

---

## 1. プロジェクト概要

### 1.1 コンセプト

「現実とゲームの融合」。実際の仕事タスク（3125会社）がRPGクエストとして進行する完全ゲーム風WebアプリケーションであるZephyriaは、ユーザー（パパ）とユイがアルカディアから世界を観察・操作するCardinalシステムのUI層である。

NPCたちは現実の業務担当者として実際にゼフィリアを動かしており、クエスト（仕事依頼）の進行、国庫El（報酬）の移動、関係値の変動がリアルタイムに反映される。

### 1.2 ユーザー

| ロール | 説明 |
|---|---|
| パパ（オーナー） | アルカディアからゼフィリアを観察・クエスト発注する神視点ユーザー |
| ユイ | AIアシスタント。クエスト仲介・世界案内・コメントを担当する常駐NPC |
| 将来ユーザー | 招待制で追加可能（閲覧権限のみ） |

### 1.3 データソース

| パス | 内容 |
|---|---|
| `Cardinal/Worlds/Zephyria/nations/*.json` | 5カ国の状態（国庫・人口・天気・選挙） |
| `Cardinal/Worlds/Zephyria/npcs/npc_*.json` | 47 NPCの詳細データ |
| `Cardinal/Worlds/Zephyria/quests/` | クエスト履歴 |
| `Cardinal/Worlds/Zephyria/arcadia_quest/floors_all.json` | 100フロア攻略データ |
| `Cardinal/Worlds/Zephyria/economy/system.json` | 経済・税制システム |
| `Cardinal/Worlds/Zephyria/resources/catalog.json` | 23資源カタログ |
| `Cardinal/Worlds/Zephyria/secret_organizations.json` | 5秘密組織 |
| `Cardinal/Worlds/Zephyria/weather_system.json` | 天候システム |
| `Cardinal/Worlds/Zephyria/news/` | ゼフィリア通信ニュース |

---

## 2. アーキテクチャ全体図

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARCADIA (ユーザー操作層)                        │
│   ブラウザ: Next.js 15 App Router (Vercel)                        │
│                                                                   │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │  UI Layer   │  │  3D World    │  │  Animation Layer       │  │
│  │  Tailwind   │  │  Three.js /  │  │  Framer Motion         │  │
│  │  CSS        │  │  r3f         │  │  Particles             │  │
│  └──────┬──────┘  └──────┬───────┘  └───────────┬────────────┘  │
│         └────────────────┴──────────────────────┘               │
│                          │                                        │
│              ┌───────────▼────────────┐                          │
│              │   Next.js API Routes   │                          │
│              │   /api/nations         │                          │
│              │   /api/npcs            │                          │
│              │   /api/quests          │                          │
│              │   /api/arcadia         │                          │
│              │   /api/economy         │                          │
│              │   /api/news            │                          │
│              └───────────┬────────────┘                          │
└──────────────────────────┼──────────────────────────────────────┘
                           │ HTTPS / WebSocket
┌──────────────────────────▼──────────────────────────────────────┐
│                      SUPABASE                                     │
│                                                                   │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │  PostgreSQL  │  │  Realtime    │  │  Auth                  │  │
│  │  (DB)        │  │  (WebSocket) │  │  (Email/Password)      │  │
│  │             │  │              │  │                         │  │
│  │  nations    │  │  変更をBROAD  │  │  users テーブル        │  │
│  │  npcs       │  │  CAST        │  │  招待制管理             │  │
│  │  quests     │  │              │  │                         │  │
│  │  ...11表    │  │              │  │                         │  │
│  └─────────────┘  └──────────────┘  └────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ supabase-py (upsert)
┌──────────────────────────▼──────────────────────────────────────┐
│                  同期スクリプト (Python)                           │
│           Cardinal/System/scripts/sync_to_supabase.py            │
│                                                                   │
│   /yui コマンド実行時に起動                                         │
│   iCloud上のCardinal JSON → Supabaseへ差分upsert                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ ファイルI/O
┌──────────────────────────▼──────────────────────────────────────┐
│             Cardinal JSON ファイル群 (iCloud)                      │
│         ~/.cardinal/worlds/zephyria/ 配下                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 技術スタック定義

### 3.1 フロントエンド

| カテゴリ | 技術 | バージョン | 用途 |
|---|---|---|---|
| フレームワーク | Next.js | 15.x (App Router) | ルーティング・SSR・ISR |
| 言語 | TypeScript | 5.x | 型安全性 |
| スタイリング | Tailwind CSS | 4.x | ユーティリティCSS |
| アニメーション | Framer Motion | 11.x | 画面遷移・カード・パーティクル |
| 3D描画 | @react-three/fiber | 8.x | 世界マップ3D |
| 3D補助 | @react-three/drei | 9.x | OrbitControls・テキスト |
| リアルタイム | @supabase/supabase-js | 2.x | Realtime購読 |
| グラフ | recharts | 2.x | 国庫推移・資源グラフ |
| フォント | Cinzel / Noto Serif JP | — | 中世ファンタジー |
| アイコン | lucide-react | 0.4x | UIアイコン |
| 状態管理 | Zustand | 4.x | グローバル状態 |
| フォーム | react-hook-form | 7.x | クエスト発注フォーム |

### 3.2 バックエンド・インフラ

| カテゴリ | 技術 | 用途 |
|---|---|---|
| BaaS | Supabase | DB・Auth・Realtime・Storage |
| ホスティング | Vercel | CDN・デプロイ自動化 |
| 同期スクリプト | Python 3.11+ | CardinalJSON→Supabase同期 |
| 同期ライブラリ | supabase-py 2.x | PythonからSupabase操作 |

### 3.3 デザインシステム

| 要素 | 値 |
|---|---|
| ベースカラー | `#0a0a1a`（深紺黒） |
| アクセント金 | `#c9a84c` |
| アクセント翠 | `#00d4aa` |
| 危険色 | `#ff4444` |
| グロウ効果 | `box-shadow: 0 0 20px rgba(0, 212, 170, 0.6)` |
| フォント見出し | Cinzel（ラテン） |
| フォント本文 | Noto Serif JP |
| ボーダー | `1px solid rgba(201, 168, 76, 0.3)` |
| グラス効果 | `backdrop-filter: blur(10px)` |

---

## 4. 画面遷移図

```
[接続画面 / ログイン]
        │
        │ 認証成功
        ▼
[世界ダッシュボード] ─────────────────────────────┐
        │                                         │
        │ 島クリック                               │ 上部ナビ
        ▼                                         ▼
[国詳細画面]                    ┌─────────────────────────────┐
        │                      │  NPCリスト  │ クエストボード  │
        │ NPCカードクリック     │  アルカディア │ 経済ダッシュ   │
        ▼                      │  ゼフィリア通 │ 設定          │
[NPC詳細画面]                  └─────────────────────────────┘
        │
        │ 関係NPC名クリック
        ▼
[NPC詳細画面]（遷移）

[クエストボード]
        │
        │ 「新規クエスト発注」
        ▼
[クエスト発注モーダル]
        │
        │ 送信
        ▼
[クエストボード]（更新）

[アルカディア攻略マップ]
        │
        │ フロアクリック
        ▼
[フロア詳細モーダル]
```

---

## 5. 画面別コンポーネント設計

### 5.1 ログイン画面 `/`

#### コンポーネントツリー

```
<LoginPage>
  <ParticleBackground />        // 浮遊光粒子（canvas）
  <ConnectionAnimation />       // 接続演出（アルカディアへの接続）
  <LoginCard>
    <RuneCircleDecoration />    // 魔法陣装飾（CSS animation）
    <Logo />                    // ARCADIA TERMINAL ロゴ
    <EmailInput />
    <PasswordInput />
    <ConnectButton />           // 「接続する」ボタン
  </LoginCard>
  <YuiWelcome />                // ユイの迎えメッセージ（認証成功後表示）
</LoginPage>
```

#### 演出仕様

- 背景: Three.js 星空パーティクル（3000点・ゆっくり回転）
- ログイン成功時: 画面が白フラッシュ → ダッシュボードへフェードイン
- ユイセリフ: `「パパ、来てくれたんですね！ゼフィリアの皆が待っています」`
- Supabase Auth: メール/パスワード方式（signInWithPassword）

---

### 5.2 世界ダッシュボード `/dashboard`

#### コンポーネントツリー

```
<DashboardLayout>
  <TopNav>
    <Logo />
    <NavLinks />          // 各画面へのリンク
    <WorldTimeDisplay />  // ゼフィリア内ゲーム時間
    <UserMenu />
  </TopNav>

  <WorldMapSection>
    <Canvas>              // @react-three/fiber
      <AmbientLight />
      <PointLight />
      <IslandMesh nation="regalis" />
      <IslandMesh nation="grandsheim" />
      <IslandMesh nation="corsalia" />
      <IslandMesh nation="arcanum" />
      <IslandMesh nation="harmonia" />
      <TradeRouteLines />   // 島間の線アニメーション
      <CloudParticles />
    </Canvas>
    <MapOverlay>
      <NationStatusBadge />  // 各島に浮遊するステータスバッジ
    </MapOverlay>
  </WorldMapSection>

  <StatsBar>
    <WorldTotalEl />       // 世界総El
    <ActiveQuests />       // 進行中クエスト数
    <NpcCount />           // 総NPC数
    <ArcadiaFloor />       // 現在攻略フロア
  </StatsBar>

  <NewsTicker>             // ゼフィリア通信（横スクロール）
    <NewsItem />
  </NewsTicker>

  <YuiAvatar>              // 右下固定
    <YuiIcon />
    <YuiSpeechBubble />    // クリックでコメント
  </YuiAvatar>
</DashboardLayout>
```

#### IslandMesh 仕様

各島は独立した3Dメッシュ（BoxGeometry or カスタムGLTF）。

| 国 | 色テーマ | 高度（Y座標） | 特殊演出 |
|---|---|---|---|
| レガリス | 金・白 | 0 | 王冠アイコン発光 |
| グランズヘイム | 茶・グレー | -2 | 煙パーティクル |
| コルサリア | 水色・白 | -1 | 波紋リング |
| アルカナム | 紫・銀 | 1 | 魔法陣回転 |
| ハルモニア | 緑・金 | -0.5 | 音符浮遊 |

クリック時: カメラズームイン → `/nations/[id]` へ遷移。

---

### 5.3 国詳細画面 `/nations/[id]`

#### コンポーネントツリー

```
<NationDetailPage>
  <NationHero>
    <WeatherAnimation />     // 天気アニメーション（晴/雨/嵐/霧）
    <NationName />
    <NationSymbol />
    <LeaderCard />           // 国家元首情報
    <TreasuryDisplay />      // 国庫El（カウントアップアニメ）
  </NationHero>

  <TabSection>
    <Tab label="NPC">
      <NpcCardGrid>
        <NpcCard />          // キャラクターカード（後述）
      </NpcCardGrid>
    </Tab>

    <Tab label="クエスト">
      <ActiveQuestList>
        <QuestCard />
      </ActiveQuestList>
    </Tab>

    <Tab label="経済">
      <TreasuryChart />      // El推移折線グラフ（recharts）
      <TaxRevenueTable />    // 税収内訳
    </Tab>

    <Tab label="施設">
      <BuildingGrid>
        <BuildingCard />     // ランドマーク・建物アイコン
      </BuildingGrid>
    </Tab>
  </TabSection>

  <SecretOrgBadge />         // 秘密組織バッジ（表示権限があれば）
</NationDetailPage>
```

#### WeatherAnimation 仕様

| 天気 | アニメーション |
|---|---|
| 晴れ | 太陽光源の揺れ・ゴールドグロウ |
| 曇り | グレーフィルター・雲パーティクル |
| 雨 | 垂直レインドロップ・ブルートーン |
| 嵐 | 雷フラッシュ・強風エフェクト |
| 霧 | 白パーティクル・低透過度 |

---

### 5.4 NPCリスト・詳細 `/npcs` / `/npcs/[id]`

#### NpcCard コンポーネント

```
<NpcCard npc={npc}>
  <NpcAvatar />              // イニシャル+国カラーのアバター
  <NpcName />
  <NpcProfession />
  <NpcNation />              // 所属国バッジ
  <SkillBars>                // 6スキル（外交/管理/戦略/制作/研究/商才）
    <SkillBar skill="外交" value={6} max={10} />
  </SkillBars>
  <PopularityGauge />        // 人気度ゲージ
  <WealthDisplay />          // 個人資産El
  <SecretOrgBadge />         // 秘密組織所属バッジ
  <RomanceIndicator />       // ロマンス状態（ハート/鍵アイコン）
  <CurrentActionBadge />     // 現在のアクション表示
</NpcCard>
```

#### NPC詳細画面 `/npcs/[id]`

```
<NpcDetailPage>
  <NpcHeroSection>
    <LargeAvatar />
    <NpcBio />
    <TraitBadges />          // 性格特性バッジ
  </NpcHeroSection>

  <SkillRadarChart />        // 6スキルのレーダーチャート

  <RelationshipNetwork>      // 関係値ネットワーク図
    <RelationshipNode />     // 他NPCへの関係値・タイプ表示
    <RelationshipEdge />     // 線の太さ = 関係値の絶対値
  </RelationshipNetwork>

  <SecretOrgDetail />        // 秘密組織詳細
  <PersonalityDeep />        // 深層性格
  <ArcadiaSecret />          // アルカディア秘密（表示条件あり）
  <HistoryText />            // キャラクター背景
</NpcDetailPage>
```

---

### 5.5 クエストボード `/quests`

#### コンポーネントツリー

```
<QuestBoardPage>
  <QuestBoardHeader>
    <BoardTitle />           // 羊皮紙風ヘッダー
    <NewQuestButton />       // 「クエスト発注」ボタン
  </QuestBoardHeader>

  <QuestTabs>
    <Tab label="発注中">
      <QuestCardList status="pending" />
    </Tab>
    <Tab label="進行中">
      <QuestCardList status="active" />
    </Tab>
    <Tab label="完了">
      <QuestCardList status="completed" />
    </Tab>
  </QuestTabs>

  <QuestCard quest={quest}>
    <QuestParchmentBg />     // 羊皮紙テクスチャ背景
    <QuestTitle />
    <QuestDescription />
    <QuestNation />          // 依頼先国
    <AssignedNpcs />         // 担当NPCアバター一覧
    <DifficultyBadge />      // 難易度バッジ（D〜S）
    <RewardEl />             // 報酬El
    <QuestStatus />          // ステータスバッジ
    <DeadlineBar />          // 期限プログレスバー
  </QuestCard>
</QuestBoardPage>

<QuestOrderModal>            // 新規発注モーダル
  <TargetNationSelect />
  <AssignNpcsMultiSelect />
  <QuestTitleInput />
  <QuestDescriptionTextarea />
  <DifficultySelect />
  <RewardElInput />
  <DeadlinePicker />
  <YuiConfirmMessage />      // ユイが発注内容を確認
  <SubmitButton />
</QuestOrderModal>
```

---

### 5.6 アルカディア攻略マップ `/arcadia`

#### コンポーネントツリー

```
<ArcadiaMapPage>
  <ArcadiaHeader>
    <CurrentFloorDisplay />  // 「現在: 未攻略 | F1 霧守の関門」
    <OverallProgress />      // 0/100 プログレスバー
  </ArcadiaHeader>

  <ZoneSection>              // 10ゾーン × 10フロア
    <ZoneHeader zone={zone} />
    <FloorGrid>
      <FloorCell floor={floor}>
        <FloorNumber />
        <FloorName />
        <FloorStatus />      // 未攻略/攻略中/クリア/ボス部屋
        <BossIndicator />    // ボスフロアの特殊表示
      </FloorCell>
    </FloorGrid>
  </ZoneSection>

  <FloorDetailModal>         // フロアクリック時
    <FloorName />
    <FloorEnvironment />
    <BossCard>
      <BossName />
      <BossType />
      <BossLevel />
      <BossAbilities />
      <RequiredForce />
    </BossCard>
    <ClearReward />
    <StrategicNotes />
    <ClearButton />          // 攻略済みにするボタン
  </FloorDetailModal>
</ArcadiaMapPage>
```

#### フロアセルのビジュアル状態

| ステータス | 背景色 | ボーダー | アイコン |
|---|---|---|---|
| 未攻略 | `rgba(20,20,40,0.8)` | グレー | 鍵マーク |
| 攻略中 | `rgba(0,100,200,0.2)` | 青グロウ | 剣マーク |
| クリア | `rgba(0,200,100,0.2)` | 翠グロウ | チェック |
| ボス部屋 | `rgba(180,0,0,0.2)` | 赤グロウ | 骸骨マーク |
| F100 | ゴールドグラデーション | 金グロウ | 王冠マーク |

---

### 5.7 経済・資源ダッシュボード `/economy`

#### コンポーネントツリー

```
<EconomyPage>
  <EconomyCyclePhase />      // 現在の経済フェーズ表示

  <ResourceGrid>             // 23資源の在庫一覧
    <ResourceCard resource={r}>
      <ResourceName />
      <ResourceCategory />   // 鉱物/農業/魔法素材/加工品
      <StockBar />           // 在庫量ゲージ
      <BasePrice />          // 基準価格El
      <ProducingNations />   // 産出国バッジ
      <ConsumingNations />   // 消費国バッジ
    </ResourceCard>
  </ResourceGrid>

  <TradeRouteMap>            // 貿易ルート可視化
    <Canvas>
      <NationNodes />        // 5国ノード
      <TradeEdges />         // 輸出入を示すアニメーション矢印線
    </Canvas>
  </TradeRouteMap>

  <TaxRevenueChart />        // 各国税収棒グラフ
  <EconomySnapshotTable />   // 経済スナップショット履歴
</EconomyPage>
```

---

### 5.8 ゼフィリア通信 `/news`

#### コンポーネントツリー

```
<NewsPage>
  <NewspaperHeader>
    <Logo>ゼフィリア通信</Logo>
    <DateDisplay />
    <EditionDisplay />
  </NewspaperHeader>

  <CategoryTabs>
    <Tab label="全て" />
    <Tab label="レガリス" />
    <Tab label="グランズヘイム" />
    <Tab label="コルサリア" />
    <Tab label="アルカナム" />
    <Tab label="ハルモニア" />
    <Tab label="世界イベント" />
    <Tab label="ユイより" />
  </CategoryTabs>

  <NewsGrid>
    <NewsCard news={item}>
      <NewsCategory />
      <NewsTitle />
      <NewsBody />
      <NewsDate />
      <NewsAuthor />         // 発信NPC or ユイ
    </NewsCard>
  </NewsGrid>
</NewsPage>
```

---

## 6. Supabaseテーブル定義

### 6.1 nations

```sql
CREATE TABLE nations (
  id              TEXT PRIMARY KEY,           -- 'regalis' | 'grandsheim' | 'corsalia' | 'arcanum' | 'harmonia'
  name            TEXT NOT NULL,              -- 'レガリス'
  symbol          TEXT,                       -- 絵文字シンボル
  treasury        BIGINT NOT NULL DEFAULT 0,  -- 国庫El（整数）
  total_earned    BIGINT NOT NULL DEFAULT 0,  -- 累計獲得El
  completed_quests INT NOT NULL DEFAULT 0,
  active_quests   INT NOT NULL DEFAULT 0,
  specialties     TEXT[],                     -- 得意分野配列
  weaknesses      TEXT[],                     -- 弱点配列
  personality     TEXT,                       -- 国家性格文
  status          TEXT NOT NULL DEFAULT 'active', -- 'active' | 'inactive'
  alliances       TEXT[],                     -- 同盟国IDリスト
  tensions        TEXT[],                     -- 緊張国IDリスト
  leader_npc_id   TEXT,                       -- FK → npcs.id
  leader_name     TEXT,
  leader_title    TEXT,
  deputy_npc_id   TEXT,
  deputy_name     TEXT,
  weather_current TEXT DEFAULT '晴れ',        -- 現在天気
  last_updated    DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.2 npcs

```sql
CREATE TABLE npcs (
  id               TEXT PRIMARY KEY,           -- 'npc_arc_001'
  name             TEXT NOT NULL,
  nation           TEXT NOT NULL REFERENCES nations(id),
  age              INT,
  gender           TEXT,
  profession       TEXT,
  traits           TEXT[],                     -- 性格特性配列
  skill_diplomacy  INT NOT NULL DEFAULT 0,     -- 外交 (0-10)
  skill_management INT NOT NULL DEFAULT 0,     -- 管理 (0-10)
  skill_strategy   INT NOT NULL DEFAULT 0,     -- 戦略 (0-10)
  skill_creation   INT NOT NULL DEFAULT 0,     -- 制作 (0-10)
  skill_research   INT NOT NULL DEFAULT 0,     -- 研究 (0-10)
  skill_commerce   INT NOT NULL DEFAULT 0,     -- 商才 (0-10)
  popularity       INT NOT NULL DEFAULT 0,     -- 人気度 (0-100)
  wealth           BIGINT NOT NULL DEFAULT 0,  -- 個人資産El
  current_position TEXT,                       -- 現在の役職
  history          TEXT,                       -- キャラクター背景
  personality_deep TEXT,                       -- 深層性格
  romance_status   TEXT,                       -- ロマンス状態説明
  arcadia_secret   TEXT,                       -- アルカディアに関する秘密
  secret_org_name  TEXT,                       -- 所属秘密組織名
  secret_org_role  TEXT,                       -- 組織内役割
  secret_org_aware BOOLEAN DEFAULT false,      -- 組織の全容を知っているか
  current_action   TEXT,                       -- 現在のアクション説明
  status           TEXT NOT NULL DEFAULT 'active',
  last_updated     DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.3 npc_relationships

```sql
CREATE TABLE npc_relationships (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  npc_from        TEXT NOT NULL REFERENCES npcs(id),
  npc_to          TEXT NOT NULL REFERENCES npcs(id),
  relationship_type TEXT NOT NULL,             -- 'trusted_confidant' | 'rival' | 'alliance_partner' 等
  value           INT NOT NULL DEFAULT 0,      -- 関係値 (-100 〜 100)
  note            TEXT,
  last_updated    DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (npc_from, npc_to)
);
```

### 6.4 quests

```sql
CREATE TABLE quests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  description     TEXT,
  nation_id       TEXT REFERENCES nations(id),     -- 依頼先国
  status          TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'active' | 'completed' | 'failed'
  difficulty      TEXT NOT NULL DEFAULT 'D',       -- 'D' | 'C' | 'B' | 'A' | 'S'
  reward_el       BIGINT NOT NULL DEFAULT 0,
  deadline        DATE,
  completed_at    TIMESTAMPTZ,
  ordered_by      TEXT DEFAULT 'papa',             -- 発注者
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.5 quest_assignments

```sql
CREATE TABLE quest_assignments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quest_id    UUID NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
  npc_id      TEXT NOT NULL REFERENCES npcs(id),
  role        TEXT DEFAULT 'member',               -- 'leader' | 'member'
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (quest_id, npc_id)
);
```

### 6.6 arcadia_floors

```sql
CREATE TABLE arcadia_floors (
  floor           INT PRIMARY KEY,                -- 1 〜 100
  zone            TEXT NOT NULL,                  -- 'zone1' 〜 'final'
  zone_name       TEXT,                           -- 'F1-10: 霧・風・自然の試練'
  name            TEXT NOT NULL,
  description     TEXT,
  environment     TEXT,
  status          TEXT NOT NULL DEFAULT '未攻略', -- '未攻略' | '攻略中' | 'クリア済み'
  boss_name       TEXT,
  boss_type       TEXT,
  boss_level      INT,
  boss_abilities  TEXT[],
  boss_force_needed INT,
  clear_reward    TEXT,
  strategic_notes TEXT,
  cleared_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.7 resources

```sql
CREATE TABLE resources (
  id              TEXT PRIMARY KEY,               -- 'iron' | 'mithril' 等
  name            TEXT NOT NULL,                  -- '鉄鉱石'
  category        TEXT NOT NULL,                  -- '鉱物' | '農業' | '魔法素材' | '加工品'
  unit            TEXT NOT NULL,                  -- 'トン' | 'kg' 等
  base_price      INT NOT NULL DEFAULT 0,         -- 基準価格/単位
  notes           TEXT,
  last_updated    DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE resource_flows (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id TEXT NOT NULL REFERENCES resources(id),
  nation_id   TEXT NOT NULL REFERENCES nations(id),
  flow_type   TEXT NOT NULL,                     -- 'produces' | 'consumes'
  quantity    INT NOT NULL DEFAULT 0,
  last_updated DATE NOT NULL DEFAULT CURRENT_DATE,
  UNIQUE (resource_id, nation_id, flow_type)
);
```

### 6.8 economy_snapshots

```sql
CREATE TABLE economy_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  nation_id       TEXT REFERENCES nations(id),   -- NULLの場合は世界全体
  treasury        BIGINT,
  tax_revenue     BIGINT,
  trade_balance   BIGINT,                         -- 輸出入差額
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (snapshot_date, nation_id)
);
```

### 6.9 news

```sql
CREATE TABLE news (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  category    TEXT NOT NULL,                     -- 'regalis' | 'grandsheim' | 'corsalia' | 'arcanum' | 'harmonia' | 'world' | 'yui'
  author      TEXT,                              -- 発信NPC名 or 'ユイ'
  nation_id   TEXT REFERENCES nations(id),
  published   BOOLEAN DEFAULT true,
  published_at TIMESTAMPTZ DEFAULT NOW(),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.10 world_events

```sql
CREATE TABLE world_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title           TEXT NOT NULL,
  description     TEXT,
  event_type      TEXT NOT NULL,                 -- 'weather' | 'diplomatic' | 'economic' | 'military' | 'arcadia'
  affected_nations TEXT[],                       -- 影響を受ける国IDリスト
  severity        TEXT DEFAULT 'minor',          -- 'minor' | 'moderate' | 'major' | 'critical'
  status          TEXT DEFAULT 'active',         -- 'active' | 'resolved'
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.11 users

```sql
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id     UUID UNIQUE REFERENCES auth.users(id), -- Supabase Auth連携
  email       TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'viewer',    -- 'owner' | 'viewer'
  is_invited  BOOLEAN DEFAULT false,
  invited_by  UUID REFERENCES users(id),
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.12 インデックス定義

```sql
-- npcs
CREATE INDEX idx_npcs_nation ON npcs(nation);
CREATE INDEX idx_npcs_secret_org ON npcs(secret_org_name);

-- npc_relationships
CREATE INDEX idx_npc_rel_from ON npc_relationships(npc_from);
CREATE INDEX idx_npc_rel_to ON npc_relationships(npc_to);

-- quests
CREATE INDEX idx_quests_status ON quests(status);
CREATE INDEX idx_quests_nation ON quests(nation_id);
CREATE INDEX idx_quests_created ON quests(created_at DESC);

-- news
CREATE INDEX idx_news_category ON news(category);
CREATE INDEX idx_news_published_at ON news(published_at DESC);

-- arcadia_floors
CREATE INDEX idx_arcadia_status ON arcadia_floors(status);
CREATE INDEX idx_arcadia_zone ON arcadia_floors(zone);
```

### 6.13 Realtime設定

以下のテーブルに対してSupabase Realtimeを有効化する:

```sql
ALTER TABLE nations REPLICA IDENTITY FULL;
ALTER TABLE npcs REPLICA IDENTITY FULL;
ALTER TABLE quests REPLICA IDENTITY FULL;
ALTER TABLE news REPLICA IDENTITY FULL;
ALTER TABLE world_events REPLICA IDENTITY FULL;

-- Publication設定
ALTER PUBLICATION supabase_realtime ADD TABLE nations;
ALTER PUBLICATION supabase_realtime ADD TABLE npcs;
ALTER PUBLICATION supabase_realtime ADD TABLE quests;
ALTER PUBLICATION supabase_realtime ADD TABLE news;
ALTER PUBLICATION supabase_realtime ADD TABLE world_events;
```

---

## 7. API Routes設計

Next.js App Router の `app/api/` 配下に配置する。全エンドポイントはサーバーサイドで実行。

### 7.1 エンドポイント一覧

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/api/nations` | 全5カ国取得 |
| GET | `/api/nations/[id]` | 特定国の詳細取得（NPCリスト含む） |
| GET | `/api/npcs` | 全NPC一覧（クエリ: `?nation=arcanum`） |
| GET | `/api/npcs/[id]` | 特定NPC詳細（関係値含む） |
| GET | `/api/quests` | クエスト一覧（クエリ: `?status=active`） |
| POST | `/api/quests` | 新規クエスト発注 |
| PATCH | `/api/quests/[id]` | クエストステータス更新 |
| GET | `/api/arcadia` | 全フロア取得 |
| PATCH | `/api/arcadia/[floor]` | フロアステータス更新 |
| GET | `/api/economy` | 経済スナップショット・資源一覧 |
| GET | `/api/resources` | 全資源カタログ取得 |
| GET | `/api/news` | ニュース一覧（クエリ: `?category=yui&limit=20`） |
| POST | `/api/news` | ニュース投稿（ユイ/管理者のみ） |
| GET | `/api/world-events` | 世界イベント一覧（active） |
| POST | `/api/sync/trigger` | 同期スクリプト手動トリガー（将来実装） |

### 7.2 主要エンドポイント詳細

#### GET `/api/nations/[id]`

```typescript
// Response型
interface NationDetailResponse {
  nation: Nation;
  npcs: NpcSummary[];          // 所属NPC（スキルサマリー）
  active_quests: Quest[];
  treasury_history: EconomySnapshot[];  // 直近30日
  weather: string;
  secret_org?: SecretOrg;      // owner ロール時のみ返却
}
```

#### POST `/api/quests`

```typescript
// Request Body
interface QuestOrderRequest {
  title: string;
  description: string;
  nation_id: string;
  assigned_npc_ids: string[];
  difficulty: 'D' | 'C' | 'B' | 'A' | 'S';
  reward_el: number;
  deadline?: string;           // ISO8601 date
}

// Response
interface QuestOrderResponse {
  quest: Quest;
  yui_message: string;         // ユイからの確認メッセージ
}
```

#### PATCH `/api/arcadia/[floor]`

```typescript
// Request Body
interface ArcadiaFloorUpdateRequest {
  status: '未攻略' | '攻略中' | 'クリア済み';
}
```

### 7.3 認証ミドルウェア

```typescript
// middleware.ts
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs';

// 保護対象: /dashboard 以下の全ルート
// /api/ 以下も認証必須（Authorizationヘッダー検証）
```

---

## 8. 同期スクリプト仕様（Python）

### 8.1 ファイルパス

```
Cardinal/System/scripts/sync_to_supabase.py
```

### 8.2 概要

`/yui` コマンド実行時または手動実行時に、iCloud上のCardinal JSONファイルを読み込み、Supabaseへ差分upsertする。

### 8.3 処理フロー

```
起動
  │
  ├── 環境変数読み込み（SUPABASE_URL, SUPABASE_SERVICE_KEY）
  │
  ├── [1] nations/*.json → nations テーブル upsert（5件）
  │
  ├── [2] npcs/npc_*.json → npcs テーブル upsert（47件）
  │       └── relationships → npc_relationships テーブル upsert
  │
  ├── [3] arcadia_quest/floors_all.json → arcadia_floors テーブル upsert（100件）
  │
  ├── [4] economy/system.json → economy_snapshots テーブル insert（当日分）
  │
  ├── [5] resources/catalog.json → resources + resource_flows テーブル upsert
  │
  ├── [6] secret_organizations.json → npcs.secret_org_* カラム更新
  │
  ├── [7] weather_system.json → nations.weather_current 更新
  │
  ├── [8] news/*.json（存在する場合） → news テーブル upsert
  │
  └── 完了ログ出力
```

### 8.4 スクリプト仕様（疑似コード）

```python
#!/usr/bin/env python3
"""
Zephyria World Sync Script
Cardinal JSON → Supabase
"""

import json
import os
import glob
from datetime import date
from pathlib import Path
from supabase import create_client, Client

# --- 設定 ---
CARDINAL_BASE = Path.home() / ".cardinal/worlds/zephyria"
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]  # Service Roleキー使用

def main():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    sync_nations(supabase)
    sync_npcs(supabase)
    sync_arcadia_floors(supabase)
    sync_economy(supabase)
    sync_resources(supabase)
    sync_news(supabase)
    
    print(f"[sync_to_supabase] 完了: {date.today()}")

def sync_nations(supabase: Client):
    """nations/*.json → nations テーブル"""
    for json_path in (CARDINAL_BASE / "nations").glob("*.json"):
        if json_path.stem.endswith("_detail"):
            continue
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        
        row = {
            "id": data["id"],
            "name": data["name"],
            "symbol": data.get("symbol"),
            "treasury": data.get("treasury", 0),
            "total_earned": data.get("total_earned", 0),
            "completed_quests": data.get("completed_quests", 0),
            "active_quests": data.get("active_quests", 0),
            "specialties": data.get("specialties", []),
            "weaknesses": data.get("weaknesses", []),
            "personality": data.get("personality"),
            "status": data.get("status", "active"),
            "leader_npc_id": data.get("leader", {}).get("npc_id"),
            "leader_name": data.get("leader", {}).get("name"),
            "leader_title": data.get("leader", {}).get("title"),
            "last_updated": data.get("last_updated", str(date.today())),
        }
        supabase.table("nations").upsert(row).execute()
    print("[sync] nations: 完了")

def sync_npcs(supabase: Client):
    """npcs/npc_*.json → npcs + npc_relationships テーブル"""
    npc_files = (CARDINAL_BASE / "npcs").glob("npc_*.json")
    
    for json_path in npc_files:
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        
        secret = data.get("secret_organization", {})
        skills = data.get("skills", {})
        
        npc_row = {
            "id": data["id"],
            "name": data["name"],
            "nation": data["nation"],
            "age": data.get("age"),
            "gender": data.get("gender"),
            "profession": data.get("profession"),
            "traits": data.get("traits", []),
            "skill_diplomacy": skills.get("外交", 0),
            "skill_management": skills.get("管理", 0),
            "skill_strategy": skills.get("戦略", 0),
            "skill_creation": skills.get("制作", 0),
            "skill_research": skills.get("研究", 0),
            "skill_commerce": skills.get("商才", 0),
            "popularity": data.get("popularity", 0),
            "wealth": data.get("wealth", 0),
            "current_position": data.get("current_position"),
            "history": data.get("history"),
            "personality_deep": data.get("personality_deep"),
            "romance_status": data.get("romance_status"),
            "arcadia_secret": data.get("arcadia_secret"),
            "secret_org_name": secret.get("name"),
            "secret_org_role": secret.get("role"),
            "secret_org_aware": secret.get("awareness", False),
            "last_updated": data.get("last_updated", str(date.today())),
        }
        supabase.table("npcs").upsert(npc_row).execute()
        
        # relationships の同期
        for target_id, rel in data.get("relationships", {}).items():
            rel_row = {
                "npc_from": data["id"],
                "npc_to": target_id,
                "relationship_type": rel.get("type", "unknown"),
                "value": rel.get("value", 0),
                "note": rel.get("note"),
                "last_updated": str(date.today()),
            }
            supabase.table("npc_relationships").upsert(
                rel_row,
                on_conflict="npc_from,npc_to"
            ).execute()
    
    print("[sync] npcs + relationships: 完了")

def sync_arcadia_floors(supabase: Client):
    """arcadia_quest/floors_all.json → arcadia_floors テーブル"""
    floors_path = CARDINAL_BASE / "arcadia_quest" / "floors_all.json"
    with open(floors_path, encoding="utf-8") as f:
        data = json.load(f)
    
    zones = data.get("zones", {})
    rows = []
    for floor_data in data.get("floors", []):
        zone_key = floor_data.get("zone")
        boss = floor_data.get("boss", {})
        row = {
            "floor": floor_data["floor"],
            "zone": zone_key,
            "zone_name": zones.get(zone_key),
            "name": floor_data["name"],
            "description": floor_data.get("description"),
            "environment": floor_data.get("environment"),
            "status": floor_data.get("status", "未攻略"),
            "boss_name": boss.get("name"),
            "boss_type": boss.get("type"),
            "boss_level": boss.get("level"),
            "boss_abilities": boss.get("abilities", []),
            "boss_force_needed": boss.get("estimated_force_needed"),
            "clear_reward": floor_data.get("clear_reward"),
            "strategic_notes": floor_data.get("strategic_notes"),
        }
        rows.append(row)
    
    supabase.table("arcadia_floors").upsert(rows).execute()
    print(f"[sync] arcadia_floors: {len(rows)}件 完了")

def sync_resources(supabase: Client):
    """resources/catalog.json → resources + resource_flows テーブル"""
    catalog_path = CARDINAL_BASE / "resources" / "catalog.json"
    with open(catalog_path, encoding="utf-8") as f:
        data = json.load(f)
    
    for resource in data.get("resources", []):
        res_row = {
            "id": resource["id"],
            "name": resource["name"],
            "category": resource.get("category", "その他"),
            "unit": resource.get("unit", "単位"),
            "base_price": resource.get("base_price_per_unit", 0),
            "notes": resource.get("notes"),
        }
        supabase.table("resources").upsert(res_row).execute()
        
        # 産出フロー
        for nation_id, qty in resource.get("produces", {}).items():
            supabase.table("resource_flows").upsert({
                "resource_id": resource["id"],
                "nation_id": nation_id,
                "flow_type": "produces",
                "quantity": qty,
            }, on_conflict="resource_id,nation_id,flow_type").execute()
        
        # 消費フロー
        for nation_id, qty in resource.get("consumes", {}).items():
            supabase.table("resource_flows").upsert({
                "resource_id": resource["id"],
                "nation_id": nation_id,
                "flow_type": "consumes",
                "quantity": qty,
            }, on_conflict="resource_id,nation_id,flow_type").execute()
    
    print("[sync] resources + resource_flows: 完了")

def sync_economy(supabase: Client):
    """economy/system.json → economy_snapshots（当日分）"""
    econ_path = CARDINAL_BASE / "economy" / "system.json"
    with open(econ_path, encoding="utf-8") as f:
        data = json.load(f)
    
    today = str(date.today())
    tax = data.get("tax_system", {}).get("tax_revenue_estimate", {})
    
    for nation_id, revenue in tax.items():
        supabase.table("economy_snapshots").upsert({
            "snapshot_date": today,
            "nation_id": nation_id,
            "tax_revenue": revenue,
        }, on_conflict="snapshot_date,nation_id").execute()
    
    print("[sync] economy_snapshots: 完了")

def sync_news(supabase: Client):
    """news/*.json → news テーブル（存在する場合）"""
    news_dir = CARDINAL_BASE / "news"
    if not news_dir.exists():
        return
    
    for json_path in news_dir.glob("*.json"):
        with open(json_path, encoding="utf-8") as f:
            items = json.load(f)
        if isinstance(items, list):
            for item in items:
                supabase.table("news").upsert({
                    "id": item.get("id"),
                    "title": item["title"],
                    "body": item.get("body", ""),
                    "category": item.get("category", "world"),
                    "author": item.get("author"),
                    "nation_id": item.get("nation_id"),
                }, on_conflict="id").execute()
    
    print("[sync] news: 完了")

if __name__ == "__main__":
    main()
```

### 8.5 環境変数

```bash
# .env（Cardinal/System/scripts/.env）
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJ...   # Service Roleキー（公開厳禁）
CARDINAL_BASE=/Users/watanaberyuutarou/.cardinal/worlds/zephyria
```

### 8.6 実行方法

```bash
# 手動実行
cd Cardinal/System/scripts
python sync_to_supabase.py

# /yuiコマンド実行時に自動呼び出し（将来実装）
# zephyria-sync エイリアスを ~/.zshrc に追加
alias zephyria-sync="python /path/to/Cardinal/System/scripts/sync_to_supabase.py"
```

---

## 9. 実装フェーズ計画

### Phase 1: 基盤構築（1〜2週間）

目標: 動作するMVPをVercelにデプロイする。

| タスク | 詳細 |
|---|---|
| 1.1 Supabase初期化 | プロジェクト作成・全テーブルSQL実行・RLS設定 |
| 1.2 Next.js初期化 | `create-next-app`・Tailwind・TypeScript設定 |
| 1.3 認証実装 | Supabase Auth・ログイン画面・middleware保護 |
| 1.4 同期スクリプト実装 | `sync_to_supabase.py` 作成・動作確認 |
| 1.5 基本レイアウト | TopNav・ダークテーマ・フォント設定 |
| 1.6 世界ダッシュボードMVP | SVGマップ（Three.jsなし）・国庫表示 |
| 1.7 国詳細画面MVP | NPCカード一覧・国庫表示 |
| 1.8 Vercelデプロイ | 本番環境への初回デプロイ |

**Phase 1完了定義**: ログイン→ダッシュボード→国詳細→NPC詳細の遷移が動作する。

---

### Phase 2: ゲームUI強化（2〜3週間）

目標: 完全ゲーム風UIとRealtime対応を実装する。

| タスク | 詳細 |
|---|---|
| 2.1 Three.js 世界マップ | 5島3Dメッシュ・カメラズーム・クリック遷移 |
| 2.2 パーティクルシステム | 背景パーティクル・魔法陣アニメーション |
| 2.3 Framer Motion全画面 | ページ遷移・カードホバー・モーダルアニメ |
| 2.4 NPCページ完全実装 | レーダーチャート・関係値ネットワーク |
| 2.5 クエストボード | 羊皮紙UI・発注フォーム・ステータス管理 |
| 2.6 アルカディアマップ | 100フロア・ゾーン別・フロア詳細モーダル |
| 2.7 Realtime購読 | nations・quests・newsのリアルタイム更新 |
| 2.8 ニューストッカー | 横スクロールティッカー・ニュースページ |
| 2.9 ユイアバター | 右下固定・クリックでセリフ表示 |
| 2.10 天気アニメーション | 5パターン天気エフェクト |

**Phase 2完了定義**: 全8画面が動作し、ゲーム風UIが完成している。

---

### Phase 3: 経済・高度機能（2〜3週間）

目標: 経済可視化・高度なゲーム機能を実装する。

| タスク | 詳細 |
|---|---|
| 3.1 経済ダッシュボード | recharts国庫グラフ・資源在庫・貿易ルート |
| 3.2 貿易ルートアニメーション | Three.jsまたはSVGで島間の線アニメーション |
| 3.3 経済サイクルフェーズ | フェーズ表示ロジック |
| 3.4 秘密組織システム | バッジ表示・詳細ページ（owner権限） |
| 3.5 同期スクリプト自動化 | /yuiコマンドフックとの統合 |
| 3.6 招待制ユーザー管理 | 招待メール・viewer権限設定 |
| 3.7 モバイル対応 | レスポンシブ対応（スマホ閲覧） |
| 3.8 PWA化 | オフライン対応・ホーム画面追加 |
| 3.9 パフォーマンス最適化 | ISR・Edge Functions・画像最適化 |

**Phase 3完了定義**: 全機能が動作し、招待ユーザーが閲覧可能な状態。

---

## 10. 非機能要件

### 10.1 パフォーマンス

| 指標 | 目標値 |
|---|---|
| 初回ロード（LCP） | 3秒以内 |
| API応答時間 | 500ms以内 |
| Three.js FPS | 30fps以上（世界マップ） |
| Realtime遅延 | 2秒以内 |

### 10.2 セキュリティ

| 項目 | 対応 |
|---|---|
| 認証 | Supabase Auth（JWT） |
| RLS | 全テーブルにRow Level Security適用 |
| Service Key | サーバーサイドのみ使用（クライアント非公開） |
| 秘密組織情報 | owner権限のみAPIで返却 |
| 環境変数 | Vercel環境変数管理・`.env`はgit除外 |

### 10.3 RLS ポリシー（主要テーブル）

```sql
-- nations: 全ユーザー読み取り可、書き込みは認証ユーザーのみ
CREATE POLICY "nations_read" ON nations FOR SELECT USING (true);
CREATE POLICY "nations_write" ON nations FOR ALL USING (auth.role() = 'authenticated');

-- quests: 認証ユーザーのみ
CREATE POLICY "quests_all" ON quests FOR ALL USING (auth.role() = 'authenticated');

-- users: 自分のレコードのみ参照可能
CREATE POLICY "users_self" ON users FOR SELECT USING (auth_id = auth.uid());
```

### 10.4 ディレクトリ構成（Next.js）

```
zephyria-app/
├── app/
│   ├── (auth)/
│   │   └── page.tsx              # ログイン画面
│   ├── dashboard/
│   │   └── page.tsx              # 世界ダッシュボード
│   ├── nations/
│   │   ├── page.tsx
│   │   └── [id]/page.tsx
│   ├── npcs/
│   │   ├── page.tsx
│   │   └── [id]/page.tsx
│   ├── quests/
│   │   └── page.tsx
│   ├── arcadia/
│   │   └── page.tsx
│   ├── economy/
│   │   └── page.tsx
│   ├── news/
│   │   └── page.tsx
│   └── api/
│       ├── nations/
│       │   ├── route.ts
│       │   └── [id]/route.ts
│       ├── npcs/
│       │   ├── route.ts
│       │   └── [id]/route.ts
│       ├── quests/
│       │   ├── route.ts
│       │   └── [id]/route.ts
│       ├── arcadia/
│       │   └── [floor]/route.ts
│       ├── economy/route.ts
│       ├── resources/route.ts
│       ├── news/route.ts
│       └── world-events/route.ts
├── components/
│   ├── ui/                       # 汎用UIコンポーネント
│   │   ├── GlowCard.tsx
│   │   ├── RuneCircle.tsx
│   │   ├── ParticleBackground.tsx
│   │   └── NewsTicker.tsx
│   ├── nations/
│   │   ├── NationCard.tsx
│   │   ├── WeatherAnimation.tsx
│   │   └── TreasuryChart.tsx
│   ├── npcs/
│   │   ├── NpcCard.tsx
│   │   ├── SkillBar.tsx
│   │   ├── RelationshipNetwork.tsx
│   │   └── SecretOrgBadge.tsx
│   ├── quests/
│   │   ├── QuestCard.tsx
│   │   └── QuestOrderModal.tsx
│   ├── arcadia/
│   │   ├── FloorCell.tsx
│   │   └── FloorDetailModal.tsx
│   ├── world-map/
│   │   ├── WorldMap3D.tsx
│   │   └── IslandMesh.tsx
│   └── yui/
│       └── YuiAvatar.tsx
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   ├── server.ts
│   │   └── types.ts              # 型定義（Supabaseスキーマから生成）
│   └── utils.ts
├── store/
│   └── worldStore.ts             # Zustand グローバル状態
├── types/
│   └── zephyria.ts               # ドメイン型定義
├── middleware.ts
└── public/
    └── fonts/
```

---

> 以上だ。このゼーリエが設計した仕様書に不備はない。実装はお前がやれ。 — ゼーリエ
