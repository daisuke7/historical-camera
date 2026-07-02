# 03. 年代フィルター仕様

年代(西暦年)→ `FilterParams` → シェーダー、の 2 段で定義する。
前半(§1-2)は Dart 実装、後半(§3)はネイティブシェーダー実装の仕様。

## 1. 年代表現の 3 世代

| 区間 | メディア表現 | 主に効くパラメータ |
|------|-------------|-------------------|
| 1840〜現在 | 写真の時代。新しい→古い写真へ劣化 | monochrome, sepia, grain, scratches, vignette ほか |
| 1500〜1840 | 版画の時代(写真発明以前) | engraving, paperTexture |
| 1000〜1500 | 絵巻・古画の時代 | inkPainting, paperTexture |

区間の境界では必ずパラメータをクロスフェードさせ、スライダー操作中に表現が
「切り替わる」のではなく「移り変わる」ように見せる。

## 2. キーフレームテーブル(Dart: `era_filter.dart`)

### 2.1 データ

下表がキーフレーム。**表にない年は隣接キーフレーム間の線形補間で求める。**
省略されたセルは「中立値」(saturation=1.0, contrast=1.0, grainSize=1.0, その他=0.0)。

| year | mono | sepia | sat | cont | brig | warm | fade | grain | grSz | vign | scr | dust | jit | hal | blur | engr | ink | paper |
|------|------|-------|-----|------|------|------|------|-------|------|------|-----|------|-----|-----|------|------|-----|-------|
| 2030 | 0 | 0 | 1.00 | 1.00 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 2010 | 0 | 0 | 1.00 | 1.00 | 0 | 0 | 0 | 0.03 | 1.0 | 0.03 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 2000 | 0 | 0 | 0.95 | 1.02 | 0 | 0.05 | 0.03 | 0.08 | 1.0 | 0.08 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 1990 | 0 | 0 | 0.90 | 1.03 | 0 | 0.15 | 0.08 | 0.15 | 1.2 | 0.12 | 0 | 0 | 0 | 0.05 | 0 | 0 | 0 | 0 |
| 1975 | 0 | 0.10 | 0.75 | 0.97 | 0 | 0.35 | 0.20 | 0.25 | 1.5 | 0.20 | 0.02 | 0.02 | 0 | 0.08 | 0.05 | 0 | 0 | 0 |
| 1960 | 0.15 | 0.15 | 0.55 | 0.95 | 0 | 0.30 | 0.30 | 0.35 | 1.8 | 0.25 | 0.05 | 0.05 | 0.02 | 0.10 | 0.08 | 0 | 0 | 0 |
| 1950 | 0.90 | 0.10 | 0.40 | 1.10 | 0 | 0.10 | 0.25 | 0.45 | 2.0 | 0.30 | 0.15 | 0.10 | 0.05 | 0.12 | 0.10 | 0 | 0 | 0 |
| 1920 | 1.00 | 0.15 | 0 | 1.15 | 0.02 | 0 | 0.30 | 0.60 | 2.2 | 0.40 | 0.35 | 0.30 | 0.30 | 0.20 | 0.15 | 0 | 0 | 0.05 |
| 1880 | 1.00 | 0.80 | 0 | 1.05 | 0.03 | 0 | 0.35 | 0.55 | 2.5 | 0.55 | 0.30 | 0.40 | 0.15 | 0.30 | 0.30 | 0 | 0 | 0.20 |
| 1845 | 1.00 | 0.90 | 0 | 0.95 | 0.05 | 0 | 0.40 | 0.50 | 3.0 | 0.70 | 0.20 | 0.50 | 0.05 | 0.35 | 0.40 | 0 | 0 | 0.35 |
| 1840 | 1.00 | 0.90 | 0 | 0.95 | 0.05 | 0 | 0.40 | 0.45 | 3.0 | 0.70 | 0.15 | 0.45 | 0.05 | 0.30 | 0.40 | 0 | 0 | 0.40 |
| 1820 | 1.00 | 0.55 | 0 | 1.00 | 0.05 | 0 | 0.30 | 0.15 | 2.0 | 0.45 | 0 | 0.25 | 0 | 0.10 | 0.20 | 1.00 | 0 | 0.70 |
| 1550 | 1.00 | 0.50 | 0 | 1.00 | 0.05 | 0 | 0.35 | 0.10 | 2.0 | 0.40 | 0 | 0.30 | 0 | 0 | 0.20 | 1.00 | 0 | 0.75 |
| 1450 | 1.00 | 0.45 | 0 | 0.95 | 0.08 | 0.10 | 0.45 | 0.08 | 2.0 | 0.40 | 0 | 0.35 | 0 | 0 | 0.25 | 0 | 1.00 | 0.85 |
| 1000 | 1.00 | 0.40 | 0 | 0.90 | 0.10 | 0.15 | 0.55 | 0.05 | 2.0 | 0.45 | 0 | 0.45 | 0 | 0 | 0.30 | 0 | 1.00 | 1.00 |

列名対応: mono=monochrome, sat=saturation, cont=contrast, brig=brightness, warm=warmth,
grSz=grainSize, vign=vignette, scr=scratches, jit=jitter, hal=halation, engr=engraving,
ink=inkPainting, paper=paperTexture。

補足:
- 2030 のキーフレームは「現在より右」の安全マージン。現在年(実行時の年)ではテーブル上
  2010〜2030 の補間となり、実質ニュートラル。
- 1840→1820 で photo(sepia 系)→engraving のクロスフェード、1550→1450 で
  engraving→inkPainting のクロスフェードが起きる。engraving と inkPainting が
  同時に 1.0 になることはない。
- **この表は初期値であり、実機確認しながらチューニングする前提。** 実装ではテーブルを
  `List<EraKeyframe>` 定数として 1 箇所にまとめ、値の変更が 1 ファイルで済むようにする。

### 2.2 変換アルゴリズム

```dart
FilterParams paramsForYear(double year) {
  // year はスライダーから来る連続値(量子化前でよい。滑らかさ優先)
  // 1. year を [1000, 2030] にクランプ
  // 2. キーフレーム列(year 降順)から year を挟む 2 つ k0(新しい側), k1(古い側)を二分探索
  // 3. t = (k0.year - year) / (k0.year - k1.year)
  // 4. 全 18 フィールドを lerp(k0.f, k1.f, t)
}
```

- 単体テスト必須: 境界(1000, 2030)、キーフレーム上の年、中間年の補間値、単調性
  (year を下げたとき grain が減らない、など代表 3 フィールド)。

## 3. シェーダー仕様(ネイティブ共通アルゴリズム)

iOS(Metal)・Android(GLSL ES)で同一アルゴリズムを実装する。以下は GLSL 風の擬似コード。
uniform は `FilterParams` の 18 値 + `time`(秒, float)+ `resolution`(vec2)+ 入力テクスチャ。

処理は 1 パスのフラグメントシェーダーで完結させる(halation の簡易化を含む)。
**パス分割・中間テクスチャは P0 では作らない**(性能・実装単純化のため)。

```glsl
// ---- ユーティリティ ----
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p);   // 2D value noise(hash の双線形補間)
float fbm(vec2 p);     // noise を 3 オクターブ加算
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
  vec2 uv = fragUV;

  // 1. jitter: フレーム全体の微小揺れ。約12Hzで離散的に変わる
  float t12 = floor(time * 12.0);
  uv += (vec2(hash(vec2(t12, 1.0)), hash(vec2(t12, 2.0))) - 0.5) * 0.006 * jitter;

  // 2. blur: 5-tap の簡易ぼかし(中心 + 上下左右 offset=blur*3px)を加重平均
  vec3 c = sampleBlurred(inputTexture, uv, blur);

  // 3. 色調(順序固定: brightness → contrast → saturation → warmth → fade)
  c += brightness;
  c = (c - 0.5) * contrast + 0.5;
  c = mix(vec3(luma(c)), c, saturation);
  c += vec3(0.06, 0.015, -0.06) * warmth;          // 色温度近似
  c = mix(c, c * 0.85 + 0.13, fade);               // 黒浮き+白沈み

  // 4. monochrome / sepia
  float y = luma(c);
  c = mix(c, vec3(y), monochrome);
  c = mix(c, y * vec3(1.10, 0.90, 0.65) + vec3(0.06, 0.03, 0.0), sepia * 0.85);

  // 5. halation(簡易): 明部のみ滲み色を足す。blur テクスチャ再利用
  float bright = smoothstep(0.7, 1.0, luma(sampleBlurred(inputTexture, uv, 2.0)));
  c += bright * halation * vec3(0.25, 0.18, 0.10);

  // 6. engraving(版画): 輝度→45°ハッチング線。線密度は暗いほど高い
  if (engraving > 0.0) {
    float d = (uv.x + uv.y) * resolution.y * 0.7;   // 45°方向の座標
    float tone = luma(c);
    float lines = 0.0;                               // 3 段階の線を暗さに応じて重ねる
    lines += step(tone, 0.85) * (0.5 + 0.5 * sin(d * 1.0));
    lines += step(tone, 0.55) * (0.5 + 0.5 * sin(d * 2.0 + 1.6));
    lines += step(tone, 0.30) * (0.5 + 0.5 * sin(d * 4.0 + 3.1));
    vec3 ink = vec3(0.18, 0.12, 0.08);               // 褐色インク
    vec3 paper = vec3(0.93, 0.88, 0.78);
    vec3 engraved = mix(paper, ink, clamp(lines, 0.0, 1.0) * 0.9);
    c = mix(c, engraved, engraving);
  }

  // 7. inkPainting(絵巻/墨画): Sobel エッジ→墨線 + トーンのポスタライズ + 和紙色
  if (inkPainting > 0.0) {
    float edge = sobelLuma(inputTexture, uv);        // 8近傍サンプルの Sobel 強度
    float tone = floor(luma(c) * 4.0) / 4.0;         // 4 階調ポスタライズ
    vec3 paper = vec3(0.90, 0.85, 0.72);
    vec3 wash = mix(vec3(0.25, 0.22, 0.18), paper, tone * 0.85 + 0.15);
    vec3 inked = mix(wash, vec3(0.10, 0.08, 0.06), smoothstep(0.25, 0.6, edge));
    c = mix(c, inked, inkPainting);
  }

  // 8. grain(粒状): 毎フレーム変化するノイズ
  float g = hash(floor(uv * resolution / grainSize) + fract(time) * 100.0) - 0.5;
  c += g * grain * 0.25;

  // 9. scratches(縦傷): 時間で位置が変わる細い縦線を最大3本
  for (int i = 0; i < 3; i++) {
    float sx = hash(vec2(floor(time * 2.0), float(i)));
    float line = 1.0 - smoothstep(0.0, 0.0015, abs(uv.x - sx));
    c += line * scratches * 0.35 * (hash(vec2(time, float(i))) - 0.3);
  }

  // 10. dust(斑点): 低頻度ノイズのしきい値
  float dspot = step(1.0 - dust * 0.03, noise(uv * 40.0 + floor(time * 3.0)));
  c = mix(c, vec3(0.85), dspot * 0.8);

  // 11. paperTexture(紙の質感): fbm を乗算
  c *= mix(1.0, 0.82 + 0.18 * fbm(uv * resolution / 3.0), paperTexture);

  // 12. vignette(周辺減光)
  float r = distance(uv, vec2(0.5)) * 1.414;
  c *= 1.0 - vignette * smoothstep(0.45, 1.0, r);

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
```

### 実装上の注意

- `sampleBlurred(tex, uv, amount)`: amount==0 なら 1 サンプルに早期リターンすること。
- テクスチャサンプル数は最悪ケース(blur + halation + sobel)でも約 15。720p で問題ない。
- `time` は録画時の見た目一致のためレンダラー起動からの経過秒を使う(フレーム番号ではなく)。
- 全パラメータ 0(中立)のとき、出力が入力と一致することをテストすること(パススルー検証)。
- posterize・step 系はスライダー操作でちらつきやすいので、engraving/inkPainting の
  しきい値には smoothstep を使う(上記コード準拠)。

## 4. 静止画への適用

- 同一シェーダーをフル解像度(例 4032×3024)で 1 回実行する。
- `grainSize` はプレビューとの見た目一致のため、解像度比でスケールする:
  `effectiveGrainSize = grainSize * (photoWidth / previewWidth)`。
  scratches の線幅 0.0015、dust の noise 周波数は uv 基準なので追加補正不要。
- `time` は撮影時点のプレビューの time をそのまま使う(粒子パターンがプレビューと同系になる)。

## 5. 将来拡張(P3)の設計フック

- セグメンテーションマスク(人物・空)を追加テクスチャ uniform `maskTexture` として渡し、
  領域ごとにパラメータを増減する(例: 空は fade+0.2)。シェーダーは
  `maskTexture` が無ければ従来動作、が成立する形で拡張する。
- クラウド生成 AI 変換(タイムトラベル現像)はシェーダーと独立した撮影後機能であり、
  本仕様への影響はない。
