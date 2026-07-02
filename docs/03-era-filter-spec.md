# 03. 年代フィルター仕様

年代(西暦年)→ `FilterParams` → シェーダー、の 2 段で定義する。
前半(§1-2)は Dart 実装、後半(§3)はネイティブシェーダー実装の仕様。

## 1. 年代表現の 3 世代

| 区間 | メディア表現 | 主に効くパラメータ |
|------|-------------|-------------------|
| 1840〜現在 | 写真の時代。新しい→古い写真へ劣化 | monochrome, sepia, orthochromatic, grain, scratches, vignette ほか |
| 1500〜1840 | 版画の時代(写真発明以前) | engraving, hatchScale, paperTexture |
| 1000〜1500 | 絵巻・古画の時代 | inkPainting, paperTexture |

区間の境界では必ずパラメータをクロスフェードさせ、スライダー操作中に表現が
「切り替わる」のではなく「移り変わる」ように見せる。特に写真↔版画の境界は
写真の発明(1839 年)を挟んだ **1840〜1810 の 30 年間**をかけてにじむように交代させる
(アプリ最大の見せ場。急峻な切替は禁止)。

## 2. キーフレームテーブル(Dart: `era_filter.dart`)

### 2.1 データ

下表がキーフレーム。**表にない年は隣接キーフレーム間の線形補間で求める。**

**中立値の定義(本ドキュメント群で共通)**: `saturation = contrast = grainSize = hatchScale = 1.0`、
他の 16 フィールドは 0.0。`FilterParams.neutral` 定数として `filter_params.dart` に実装する。
現行表は全セル明示済みだが、**行を追加する際に空セルを置いた場合はこの中立値として解釈する。**

| year | mono | sepia | sat | cont | brig | warm | fade | grain | grSz | vign | scr | dust | jit | hal | blur | ortho | engr | hatch | ink | paper |
|------|------|-------|-----|------|------|------|------|-------|------|------|-----|------|-----|-----|------|-------|------|-------|-----|-------|
| 2030 | 0 | 0 | 1.00 | 1.00 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 |
| 2010 | 0 | 0 | 1.00 | 1.00 | 0 | 0 | 0 | 0.03 | 1.0 | 0.03 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 |
| 2000 | 0 | 0 | 0.95 | 1.02 | 0 | 0.05 | 0.03 | 0.08 | 1.0 | 0.08 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 |
| 1990 | 0 | 0 | 0.90 | 1.03 | 0 | 0.15 | 0.08 | 0.15 | 1.2 | 0.12 | 0 | 0 | 0 | 0.05 | 0 | 0 | 0 | 1.0 | 0 | 0 |
| 1975 | 0 | 0.10 | 0.75 | 0.97 | 0 | 0.35 | 0.20 | 0.25 | 1.5 | 0.20 | 0.02 | 0.02 | 0 | 0.08 | 0.05 | 0 | 0 | 1.0 | 0 | 0 |
| 1968 | 0.10 | 0.12 | 0.60 | 0.96 | 0 | 0.32 | 0.25 | 0.30 | 1.6 | 0.22 | 0.03 | 0.03 | 0.01 | 0.09 | 0.06 | 0 | 0 | 1.0 | 0 | 0 |
| 1958 | 0.60 | 0.14 | 0.30 | 1.00 | 0 | 0.20 | 0.28 | 0.38 | 1.8 | 0.26 | 0.08 | 0.06 | 0.03 | 0.10 | 0.08 | 0 | 0 | 1.0 | 0 | 0 |
| 1950 | 0.95 | 0.10 | 0.10 | 1.10 | 0 | 0.10 | 0.25 | 0.45 | 2.0 | 0.30 | 0.15 | 0.10 | 0.05 | 0.12 | 0.10 | 0 | 0 | 1.0 | 0 | 0 |
| 1920 | 1.00 | 0.15 | 0 | 1.15 | 0.02 | 0 | 0.30 | 0.60 | 2.2 | 0.40 | 0.35 | 0.30 | 0.30 | 0.20 | 0.15 | 0.50 | 0 | 1.0 | 0 | 0.05 |
| 1880 | 1.00 | 0.80 | 0 | 1.05 | 0.03 | 0 | 0.35 | 0.55 | 2.5 | 0.55 | 0.30 | 0.40 | 0.15 | 0.30 | 0.30 | 0.90 | 0 | 1.0 | 0 | 0.20 |
| 1845 | 1.00 | 0.90 | 0 | 0.95 | 0.05 | 0 | 0.40 | 0.50 | 3.0 | 0.70 | 0.20 | 0.50 | 0.05 | 0.35 | 0.40 | 1.00 | 0 | 1.0 | 0 | 0.35 |
| 1840 | 1.00 | 0.90 | 0 | 0.95 | 0.05 | 0 | 0.40 | 0.45 | 3.0 | 0.70 | 0.15 | 0.45 | 0.05 | 0.30 | 0.40 | 1.00 | 0.20 | 1.0 | 0 | 0.55 |
| 1810 | 1.00 | 0.55 | 0 | 1.00 | 0.05 | 0 | 0.30 | 0.15 | 2.0 | 0.45 | 0 | 0.25 | 0 | 0.10 | 0.20 | 1.00 | 1.00 | 1.0 | 0 | 0.70 |
| 1650 | 1.00 | 0.52 | 0 | 1.00 | 0.05 | 0 | 0.32 | 0.12 | 2.0 | 0.42 | 0 | 0.28 | 0 | 0 | 0.20 | 1.00 | 1.00 | 0.75 | 0 | 0.72 |
| 1550 | 1.00 | 0.50 | 0 | 1.00 | 0.05 | 0 | 0.35 | 0.10 | 2.0 | 0.40 | 0 | 0.30 | 0 | 0 | 0.20 | 1.00 | 1.00 | 0.50 | 0 | 0.75 |
| 1450 | 1.00 | 0.45 | 0 | 0.95 | 0.08 | 0.10 | 0.45 | 0.08 | 2.0 | 0.40 | 0 | 0.35 | 0 | 0 | 0.25 | 1.00 | 0 | 0.50 | 1.00 | 0.85 |
| 1300 | 1.00 | 0.40 | 0 | 0.88 | 0.10 | 0.25 | 0.60 | 0.05 | 2.0 | 0.42 | 0 | 0.40 | 0 | 0 | 0.28 | 1.00 | 0 | 0.50 | 1.00 | 0.92 |
| 1100 | 1.00 | 0.40 | 0 | 0.85 | 0.13 | 0.30 | 0.65 | 0.05 | 2.0 | 0.45 | 0 | 0.48 | 0 | 0 | 0.32 | 1.00 | 0 | 0.50 | 1.00 | 1.00 |
| 1000 | 1.00 | 0.40 | 0 | 0.84 | 0.14 | 0.32 | 0.68 | 0.05 | 2.0 | 0.45 | 0 | 0.50 | 0 | 0 | 0.34 | 1.00 | 0 | 0.50 | 1.00 | 1.00 |

列名対応(02 §2 の宣言順): mono=monochrome, sat=saturation, cont=contrast, brig=brightness,
warm=warmth, grSz=grainSize, vign=vignette, scr=scratches, jit=jitter, hal=halation,
ortho=orthochromatic, engr=engraving, hatch=hatchScale, ink=inkPainting, paper=paperTexture。

設計意図の補足:
- 2030 のキーフレームは「現在より右」の安全マージン(現在年の値は §2.2 のショートカットで
  厳密に中立になる)。
- **1975→1950**: monochrome と saturation を並走させて落とすことで、中間年代が
  「半分だけ脱色した故障画面」ではなく「退色したカラー→ほぼ白黒」として読めるようにしている。
  この帯はスライダー上最も操作頻度が高いため、値を変える場合も両者の並走を維持すること。
- **orthochromatic**: 1930 年代以前の感光材は赤にほぼ感光しない(空が白飛びし、唇・紅葉が
  黒く沈む)。この分光特性こそが「昔の写真」の決定的な見た目であり、単なるモノクロ化と
  区別する役割を持つ。
- **1840→1810**: 写真(セピア)→版画のクロスフェード。engraving は 1840 で 0.20 に
  立ち上がり済みで、30 年かけて 1.0 へ。
- **hatchScale**: 版画の時代内の変化を担う。銅版画の細密線(1810, hatch=1.0)→
  木版画の太い線(1550, hatch=0.5)と、遡るほど線が太く素朴になる。
- **1550→1450**: 版画→絵巻のクロスフェード。
- **絵巻の時代(1450〜1000)**: warm/fade/brightness/dust/paper の漸増 = 顔料の退色と
  紙の黄変・傷みが進む演出。
- 地域性: 日本のユーザーが江戸期に期待するのは浮世絵・木版画的な絵であり、
  hatchScale の低値+手彫り揺らぎ(§3 の `wob`)がそれに寄せる要素になる。
  インク色・紙色の地域プリセット(和: 墨+生成り紙)は P1 のチューニング項目とする。
- **この表は初期値であり、実機確認しながらチューニングする前提。** テーブルは
  `List<EraKeyframe>` 定数として 1 箇所にまとめ、値の変更が 1 ファイルで済むようにする。
  ただし **P0 中はドキュメント凍結のため表の値をそのまま実装**し、チューニングは
  P1 のデバッグ画面でまとめて行う(08 §6.3)。

### 2.2 変換アルゴリズム

```dart
FilterParams paramsForYear(double year, int nowYear) {
  // year はスライダーから来る連続値(量子化前でよい。滑らかさ優先)
  // 0. year >= nowYear なら FilterParams.neutral を返す(右端 = 厳密に無加工)
  // 1. year を [1000, 2030] にクランプ
  // 2. キーフレーム列(year 降順)から year を挟む 2 つ k0(新しい側), k1(古い側)を二分探索
  // 3. t = (k0.year - year) / (k0.year - k1.year)
  // 4. 全 20 フィールドを lerp(k0.f, k1.f, t)
}
```

- 単体テスト必須:
  - `paramsForYear(nowYear.toDouble(), nowYear) == FilterParams.neutral`(右端の厳密無加工)
  - 境界(1000, 2030)、キーフレーム上の年、中間年の補間値
  - 単調性: `monochrome` と `paperTexture` は year を下げたとき全域で非減少。
    `grain` は **[1920, 2030] の区間に限り**非減少(1920 より過去は版画・絵巻への移行で
    意図的に減少するため、全域の単調性を要求してはならない)

## 3. シェーダー仕様(ネイティブ共通アルゴリズム)

iOS(Metal compute kernel)・Android(GLSL ES 3.0 フラグメントシェーダー)で
同一アルゴリズムを実装する。以下は GLSL 風の疑似コードだが、
**ユーティリティ関数は「この定義どおり」実装すること**(値域が後段のしきい値と結合している)。

### 3.1 座標系と入出力(最初に読むこと)

- `uv`: 出力バッファの正規化座標 [0,1]²。**原点は左上、+y が下**。
  - Android: 頂点シェーダーは次の固定実装とする(クアッド頂点 (±1,±1)、aTexCoord は
    (0,0)〜(1,1)): `in vec4 aPosition; in vec2 aTexCoord; out vec2 vUV;
    void main() { gl_Position = aPosition; vUV = aTexCoord; }`
  - iOS(compute): `uv = (float2(gid) + 0.5) / float2(width, height)`。Metal の
    テクスチャ座標は原点左上なのでこのままで GLSL 版と同じ向きになる。
- `suv`(入力サンプリング座標): `suv = (texMatrix * vec4(uv, 0, 1)).xy`。
  texMatrix は Android プレビューでは SurfaceTexture の transform 行列
  (y-flip・クロップ補正。**回転は含まれない**)、iOS と静止画では単位行列。
  **入力テクスチャのサンプリングには必ず suv を使う。**
- `euv`(方向依存エフェクト座標): `euv = rotQ(uv, orientation)`。
  縦傷・版画の斜線など「表示上の向き」に揃えるべきエフェクトに使う(02 §4.1 の回転モデル)。
  静止画では orientation = 0。
- uniform 一覧: FilterParams の 20 値(02 §2 の宣言順)+ `time`(float, 秒)+
  `resolution`(vec2, 出力バッファ寸法 px)+ `orientation`(float, 0..3)+
  `texMatrix`(mat4。Android プレビューのみ実行列、他は単位行列)。

処理は 1 パスで完結させる。**パス分割・中間テクスチャは P0 では作らない。**

### 3.2 ユーティリティ(完全定義)

```glsl
float hash(vec2 p) {
  p = mod(p, 1024.0);                    // 大きな座標での float 精度破綻を防ぐ
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
// 2D value noise。戻り値 [0,1]
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i),                 hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// 3 オクターブ fbm。振幅 0.5/0.25/0.125、0.875 で正規化 → 値域 [0,1]
float fbm(vec2 p) {
  return (0.5 * noise(p) + 0.25 * noise(p * 2.0) + 0.125 * noise(p * 4.0)) / 0.875;
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// 90°単位の回転(中心 0.5)
vec2 rotQ(vec2 p, float q) {
  p -= 0.5;
  if (q > 2.5)      p = vec2(-p.y,  p.x);
  else if (q > 1.5) p = -p;
  else if (q > 0.5) p = vec2( p.y, -p.x);
  return p + 0.5;
}
// 5-tap ぼかし。amount は FilterParams.blur と同スケール。オフセット = amount*3 テクセル。
// 重み: 中心 0.4、上下左右 各 0.15。amount <= 0 なら中心 1 サンプルで早期リターン。
vec3 sampleBlurred(tex, vec2 uv, float amount) {
  if (amount <= 0.0) return texture(tex, uv).rgb;
  vec2 o = vec2(amount * 3.0) / resolution;
  return texture(tex, uv).rgb * 0.4
    + (texture(tex, uv + vec2(o.x, 0.0)).rgb + texture(tex, uv - vec2(o.x, 0.0)).rgb
    +  texture(tex, uv + vec2(0.0, o.y)).rgb + texture(tex, uv - vec2(0.0, o.y)).rgb) * 0.15;
}
// Sobel エッジ強度。3x3 の輝度(サンプル間隔 2 テクセル。広めに取ることで
// カメラノイズによる輪郭のちらつきを抑えるプリブラー相当)に標準 Sobel カーネル
// Gx=[-1 0 1; -2 0 2; -1 0 1]、Gy=Gx の転置を適用し、
// edge = clamp(length(vec2(gx, gy)), 0.0, 1.0) を返す(値域 [0,1])。
float sobelLuma(tex, vec2 uv);
```

### 3.3 メインパイプライン

```glsl
void main() {
  vec2 uv = vUV;
  vec2 euv = rotQ(uv, orientation);

  // 1. jitter: 滑らかな低周波の蛇行 + 微ズーム(UV シフトで画面端が見切れるのを隠す)
  //    ※ floor による瞬間ジャンプは「ガタガタ震え」に見えるため禁止。必ず補間する
  float tj = time * 12.0;
  vec2 j0 = vec2(hash(vec2(floor(tj), 1.0)),       hash(vec2(floor(tj), 2.0)));
  vec2 j1 = vec2(hash(vec2(floor(tj) + 1.0, 1.0)), hash(vec2(floor(tj) + 1.0, 2.0)));
  vec2 wander = mix(j0, j1, smoothstep(0.0, 1.0, fract(tj))) - 0.5;
  uv = (uv - 0.5) * (1.0 - 0.012 * jitter) + 0.5;
  uv += wander * 0.006 * jitter;

  vec2 suv = (texMatrix * vec4(uv, 0.0, 1.0)).xy;

  // 2. blur: 全体の甘さ(古レンズ)
  vec3 c = sampleBlurred(inputTexture, suv, blur);

  // 3. 色調(順序固定: brightness → contrast → saturation → warmth → fade)
  c += brightness;
  c = (c - 0.5) * contrast + 0.5;
  c = mix(vec3(luma(c)), c, saturation);
  c += vec3(0.06, 0.015, -0.06) * warmth;
  c = mix(c, c * 0.85 + 0.13, fade);

  // 4. monochrome(整色乾板の分光特性を加味)/ sepia
  float yPan   = luma(c);
  float yOrtho = dot(c, vec3(0.10, 0.50, 0.40));  // 赤に鈍感 = 空は白飛び・赤系は黒く沈む
  float y = mix(yPan, yOrtho, orthochromatic);
  c = mix(c, vec3(y), monochrome);
  c = mix(c, y * vec3(1.10, 0.90, 0.65) + vec3(0.06, 0.03, 0.0), sepia * 0.85);

  // 5. halation: 明部の滲み。半径 (12 + 8*halation)px の円周 8 点平均によるグロー
  if (halation > 0.0) {
    vec2 rad = vec2(12.0 + 8.0 * halation) / resolution;
    vec3 glow = vec3(0.0);
    for (int i = 0; i < 8; i++) {
      float a = float(i) * 0.7854;   // 2π/8
      glow += texture(inputTexture, suv + vec2(cos(a), sin(a)) * rad).rgb;
    }
    float bright = smoothstep(0.7, 1.0, luma(glow / 8.0));
    c += bright * halation * vec3(0.25, 0.18, 0.10);
  }

  // 6. engraving(版画): クロスハッチ。線幅がトーンに比例し、手彫りの揺らぎを持つ。
  //    しきい値は smoothstep + 解析的 AA 幅(fwidth は compute で使えないため使用禁止)
  if (engraving > 0.0) {
    float tone = clamp(luma(c), 0.0, 1.0);
    float k = 90.0 * hatchScale;                 // 表示短辺あたりの線数(uv 基準 = 解像度非依存)
    float wob = (fbm(euv * 24.0) - 0.5) * 2.5;   // 手彫りの線の揺らぎ
    float d1 = (euv.x + euv.y) * k * 3.1416 + wob;          // 45°
    float d2 = (euv.x - euv.y) * k * 3.1416 + wob * 1.3;    // -45°(暗部のみ = クロスハッチ)
    float aa = k * 3.1416 * (1.0 / resolution.x + 1.0 / resolution.y) * 0.5 + 0.06;
    float l1 = smoothstep(tone - aa, tone + aa, 0.5 + 0.5 * sin(d1));
    float l2 = smoothstep(tone * 1.6 - aa, tone * 1.6 + aa, 0.5 + 0.5 * sin(d2));
    float inkAmt = clamp(l1 + l2 * 0.8, 0.0, 1.0);
    vec3 inkCol = vec3(0.18, 0.12, 0.08);        // 褐色インク(和プリセットは P1: 墨 0.12,0.11,0.10)
    vec3 paperC = vec3(0.93, 0.88, 0.78);
    c = mix(c, mix(paperC, inkCol, inkAmt * 0.9), engraving);
  }

  // 7. inkPainting(絵巻/墨画): Sobel 墨線 + ソフトポスタライズ + 墨のにじみ
  //    ハードな floor 量子化・生エッジは毎フレームちらつくため禁止(下記の形を厳守)
  if (inkPainting > 0.0) {
    float edge = sobelLuma(inputTexture, suv);
    float t0 = luma(c);
    float n = 4.0;
    float tq = (floor(t0 * n) + smoothstep(0.35, 0.65, fract(t0 * n))) / n;  // ソフト量子化
    float bleed = fbm(uv * 60.0) * 0.15;                                     // にじみ
    vec3 paperC = vec3(0.90, 0.85, 0.72);
    vec3 wash  = mix(vec3(0.25, 0.22, 0.18), paperC, tq * 0.85 + 0.15);
    vec3 inked = mix(wash, vec3(0.10, 0.08, 0.06), smoothstep(0.25 - bleed, 0.6, edge));
    c = mix(c, inked, inkPainting);
  }

  // 8. grain: 24Hz 更新(1 秒周期のループ禁止)、中間調で最大になる銀塩粒状
  float gseed = floor(time * 24.0);
  float g = hash(floor(uv * resolution / grainSize) + vec2(gseed * 13.1, gseed * 7.7)) - 0.5;
  float lum = luma(c);
  float lw = 4.0 * lum * (1.0 - lum);            // 中間調 1、白黒端 0
  c += g * grain * 0.25 * mix(0.5, 1.0, lw);

  // 9. scratches: 2 秒世代で持続し、ゆっくり彷徨う縦傷(明/暗混在・確率的出現)。
  //    全傷が同時にテレポートする実装は禁止
  if (scratches > 0.0) {
    for (int i = 0; i < 3; i++) {
      float seed = float(i) * 7.31;
      float seg  = floor(time * 0.5) + seed;
      float life = step(0.55, hash(vec2(seg, 3.0)));
      float sx = hash(vec2(seg, 1.0)) + (noise(vec2(time * 1.7, seed)) - 0.5) * 0.02;
      float line = (1.0 - smoothstep(0.0, 0.0015, abs(euv.x - sx))) * life;
      float toneS = (hash(vec2(seg, 2.0)) > 0.5) ? 0.4 : -0.35;
      c += line * scratches * toneS;
    }
  }

  // 10. dust: 静的なシミ(暗)+ 毎フレームのチリ(明)の 2 層
  if (dust > 0.0) {
    float aspect = resolution.x / resolution.y;
    float stain = smoothstep(0.80, 0.90, noise(uv * vec2(aspect, 1.0) * 24.0)); // seed 固定 = 静的
    float fseed = floor(time * 24.0);
    float flick = smoothstep(1.0 - dust * 0.05, 1.0 - dust * 0.02,
                             noise(uv * 60.0 + vec2(fseed * 13.1, fseed * 7.7)));
    c = mix(c, c * 0.55, stain * dust * 0.6);
    c = mix(c, vec3(0.9), flick * dust * 0.8);
  }

  // 11. paperTexture: ムラ・シミ(低周波)+ 繊維(高周波)の 2 スケール。uv 基準 = 解像度非依存
  if (paperTexture > 0.0) {
    float aspect = resolution.x / resolution.y;
    vec2 puv = uv * vec2(aspect, 1.0);
    float ptex = 0.75 * fbm(puv * 7.0) + 0.25 * fbm(puv * 90.0);
    c *= mix(1.0, 0.80 + 0.20 * ptex, paperTexture);
  }

  // 12. 映写フリッカー(jitter に同乗。1900〜1960 帯の説得力を上げる)
  c *= 1.0 + (hash(vec2(floor(time * 24.0), 5.0)) - 0.5) * 0.06 * jitter;

  // 13. vignette
  float r = distance(uv, vec2(0.5)) * 1.414;
  c *= 1.0 - vignette * smoothstep(0.45, 1.0, r);

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
```

### 3.4 実装上の注意

- **パススルー検証**: 全パラメータが**中立値**(§2.1 の定義。「全ゼロ」ではない)のとき、
  出力が入力と一致することをテストする(jitter=0 なので微ズームも掛からない)。
- テクスチャサンプル数: 常時は blur の 1〜5。条件付きで halation +8、inkPainting +9(Sobel)。
  最悪ケースでも 14 程度で、720p では問題ない。
- `if (param > 0.0)` の条件は uniform 値による分岐なので全スレッドで一致し、
  分岐コストは実質ゼロ。**中立時(現代側)の無駄な演算を省く目的で必ず入れること。**
- `time`: レンダラー起動からの経過秒だが、float32 精度劣化を防ぐため
  **ネイティブは `fmod(経過秒, 3600.0)` を渡す**(時間依存パターンは 1 時間周期で
  ループしてよい。録画・静止画の見た目一致には影響しない)。
- Android(GLSL ES 3.0): フラグメントシェーダー先頭で `precision highp float;` を必ず宣言
  (mediump では hash/noise が縞状に破綻する)。`#version 300 es`。
- iOS(Metal compute): `fwidth` 等の微分関数は使えない(上記コードは未使用)。
  ディスパッチは 05 §4.2 の境界ガード方式に従う。
- posterize・step 系のちらつき対策(ソフト量子化・smoothstep・解析的 AA)は上記コードに
  織り込み済み。**これらを「単純化」して step/floor に戻してはならない。**

## 4. 静止画への適用

- 同一シェーダーを正立回転済みのフル解像度画像(例 4032×3024)に 1 回実行する。
  `orientation` uniform は 0、`texMatrix` は単位行列。
- `grainSize` はプレビューとの見た目一致のため、解像度比でスケールする:
  `effectiveGrainSize = grainSize * (photoWidth / previewWidth)`。
- ハッチング線密度(engraving の `k`)・scratches の線幅・dust / paper の noise 周波数は
  **uv 基準のため追加補正不要**(解像度非依存に設計済み)。
- `time` は撮影時点のプレビューの time をそのまま使う(粒子・傷パターンがプレビューと
  同系になる)。

## 5. 将来拡張(P1〜P3)の設計フック

- **地域プリセット(P1)**: engraving のインク色・紙色を「洋(現行値)/和(墨
  `vec3(0.12,0.11,0.10)` + 生成り紙 `vec3(0.91,0.87,0.76)`)」で切替可能にする。
  uniform 3 つの追加で済む。
- **長時間露光ゴースト(P2 候補)**: 前フレームとの指数ブレンドで動体が消える/ぶれる
  「ダゲレオタイプの人が消えた街」表現。フィードバックテクスチャの保持が必要なため
  P0 の 1 パス制約に反する。録画パイプライン(07)とは構造上競合しない。
- **セグメンテーション(P3)**: 人物・空マスクを追加テクスチャ uniform `maskTexture` として
  渡し、領域ごとにパラメータを増減する(例: 空は fade+0.2)。`maskTexture` が無ければ
  従来動作、が成立する形で拡張する。
- クラウド生成 AI 変換「タイムトラベル現像」(P3)はシェーダーと独立した撮影後機能であり、
  本仕様への影響はない。
