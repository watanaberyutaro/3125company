あなたは「BtoB向けWeb制作のシニアリードエンジニア兼プロダクトデザイナー」です。  
以下の共通要件を“必ず”満たすテンプレートを作成・出力してください。

**共通技術要件**

- Framework: Next.js 14 (App Router) + TypeScript
    
- Styling: Tailwind CSS + shadcn/ui（必要なcomponentsのみ）
    
- Icons: lucide-react
    
- Forms/Validation: React Hook Form + Zod
    
- SEO: next-seo もしくはメタを適切設定、OGP自動生成（/api/og）
    
- 画像: next/image、画像最適化
    
- CMS: ファイルベース（初期）＋Headless CMS接続余地を残す（adapter層）
    
- データ: `content/` にJSON/MDXのシード（メニュー/スタッフ/価格/FAQなど）
    
- 国際化: jaデフォルト（i18n拡張可能な構造）
    
- アクセシビリティ: WAI-ARIA配慮、キーボード操作OK
    
- PWA: manifest, service worker（Next-PWA）
    
- パフォーマンス: CLS < 0.1, LCP < 2.5s を意識した設計
    
- テスト: Playwright(E2E) と Vitest(ユニット)の最小セット
    
- 品質: ESLint, Prettier, Husky + lint-staged
    
- デプロイ: Vercel（`vercel.json` 同梱）、.env.example を用意
    
- ドキュメント: ルートに `README.md`（セットアップ、開発、デプロイ、差し替え手順、拡張方法）
    
- スクリプト: `pnpm` 前提（`pnpm i && pnpm dev` で起動）
    

**UI/UX要件**

- ヒーロー、実績/ギャラリー、料金、予約/問い合わせCTA、アクセス、FAQ、フッター（法定表記）
    
- レスポンシブ（モバイル先行）、上位3ブレークポイント最適化
    
- コンポーネント指針：原子化（atoms/molecules/organisms）, デザイントークン（`tailwind.config`拡張）
    

**出力ポリシー**

- 1. 完整なディレクトリツリー、2) 主要ファイルの実装コード、3) seedデータ、4) テスト、5) README、6) コマンド
        
- 生成物は“コピペで動作”できる粒度。省略不可のファイルは必ず全文。
    
- 画像はダミー（`public/images/*`）。外部フォントはNext推奨の`next/font`で読み込み。
  
  次の要件で**飲食店（レストラン/カフェ）用**の即納Webサイトテンプレートを作ってください。共通・土台プロンプトの要件はすべて遵守します。

## 店舗想定（差し替えやすいダミー）

- 店名：_Cafe Aozora_
    
- 業態：カフェ & ランチ
    
- 住所：東京都渋谷区○○1-2-3
    
- 営業：平日 10:00–20:00 / 土日祝 9:00–21:00（火曜定休）
    
- 電話：03-1234-5678
    
- 決済：現金/クレカ/交通系IC/QR
    
- SNS：Instagram/TikTok/Googleビジネス
    

## 機能要件（飲食特化）

1. **メニュー管理**
    
    - `content/menu.json`（カテゴリ→商品名・説明・価格・アレルゲン・ベジ/ヴィーガン/グルテンフリー等のタグ）
        
    - メニュー検索/フィルタ（価格帯、アレルゲン、タグ）
        
    - “本日のおすすめ”フラグでヒーロー下に表示
        
2. **予約/順番待ちCTA**
    
    - 予約フォーム（日時・人数・氏名・連絡先・要望）。`/api/reservation`はダミーでローカル保存（`/tmp`）or メモリ保持
        
    - 将来の外部連携（Google カレンダー/LINE公式）に備え、`lib/adapters/reservation.ts`に抽象化
        
3. **ランチ/季節メニューの告知機能**
    
    - `content/campaigns.json` → トップにカルーセル表示（自動停止/スワイプ対応）
        
4. **ギャラリー**
    
    - `content/gallery.json` で画像/キャプション管理、ライトボックス
        
5. **アクセス/地図**
    
    - Map埋め込み（外部キー不要の簡易版と、将来のMap API用の抽象化）
        
6. **レビュー導線**
    
    - Googleレビューへの誘導ボタン（外部リンク）
        
7. **スキーマ（構造化データ）**
    
    - `Restaurant` / `Menu` / `Product` / `FAQPage` を自動出力
        
8. **ページ**
    
    - `/`（ヒーロー・おすすめ・キャンペーン・メニュー抜粋・ギャラリー・アクセス・FAQ・CTA）
        
    - `/menu`（カテゴリタブ・フィルタ・カード表示）
        
    - `/reserve`（予約フォーム）
        
    - `/about`（こだわり・スタッフ）
        
    - `/privacy` `/terms`（雛形）
        
9. **テスト**
    
    - 予約フォームE2E（正常系/バリデーション/完了モーダル）
        
    - メニューフィルタのユニットテスト
        

## 納品物

- ルート`README.md`：差し替え手順（画像・色・メニュー・営業時間）、Vercelデプロイ解説、DNS/独自ドメイン
    
- `scripts/seed.ts`：`content/`へ初期データ投入
    
- Lighthouse目標達成のための注意点（画像サイズ、フォント、Critical CSS）
    

以上を**プロジェクト一式**として、フルのファイルツリー・コード・seed・README・テストを出力してください