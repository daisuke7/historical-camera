# 07. 録画機能 — 実現可能性検討と設計(フェーズ P2)

初回リリースには含めないが、**後付け可能な構造で P0 を作るための設計**をここで確定する。
要件: フィルタ適用済み映像の録画。**録画中の年代スライダー操作も映像に反映される。**

## 1. 実現可能性の結論

**両 OS とも確立された API の組合せで実現可能。** リスクは品質面(熱・音声同期)であり、
可否ではない。

| 項目 | iOS | Android |
|------|-----|---------|
| 方式 | フィルタ済み CVPixelBuffer を `AVAssetWriter` に追記 | プレビューと同じ GL 描画を `MediaRecorder` の入力 Surface にもう 1 パス実行 |
| 音声 | `AVCaptureAudioDataOutput` → 同 writer の audio input | MediaRecorder が内包(`AudioSource.CAMCORDER`) |
| 「録画中の年代操作」 | 毎フレーム最新 params で描いたものを書くだけ。**追加実装ゼロ** | 同左 |
| コーデック/コンテナ | H.264 / .mov(保存時 .mp4 変換不要、PHPhotoLibrary は mov 可) | H.264 / .mp4 |
| 想定仕様 | 1080p または 720p、30fps、音声 AAC 44.1kHz | 同左 |
| 追加負荷 | エンコードは HW(VideoToolbox)。GPU 追加負荷は iOS はゼロコピー追記のため軽微 | GL 描画がフレームあたり 2 パスになる(+2〜6ms)。HW エンコーダ(MediaCodec 経由) |

### 主要リスクと対策

| リスク | 対策 |
|--------|------|
| 長時間録画での発熱・フレーム落ち | 録画時はプレビュー 30fps 固定・録画解像度を 720p に落とすオプション。10 分上限を仕様化 |
| 音声と映像の同期ズレ | iOS: sampleBuffer の PTS をそのまま使う(自前タイムスタンプ生成をしない)。Android: MediaRecorder に委譲するためリスク低 |
| 録画中の画面回転 | **録画開始時の向きでファイルの向きを固定**し、録画中の回転では UI のみ回す(一般的なカメラアプリと同挙動)。仕様として明記 |
| 録画中の中断(電話着信・background) | 中断イベントで自動 stop+保存。破棄しない |
| ディスクフル | 開始時に空き 500MB 未満なら `RECORDING_FAILED` を返す |

## 2. iOS 設計(MediaWriter に実装)

```
startRecording:
  1. AVAssetWriter(url: 一時 .mov, fileType: .mov)
  2. videoInput: AVAssetWriterInput(mediaType: .video,
       outputSettings: [AVVideoCodecKey: .h264, width, height])
       expectsMediaDataInRealTime = true
  3. pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor(videoInput, BGRA)
  4. audioInput: AAC 設定で同様に追加
  5. AVCaptureAudioDataOutput をセッションに追加(マイク権限は録画初回に要求)
  6. writer.startWriting(); startSession(atSourceTime: 最初のフレームの PTS)

毎フレーム(FilterRenderer の GPU 完了コールバック内):
  if recording && videoInput.isReadyForMoreMediaData {
      pixelBufferAdaptor.append(filteredBuffer, withPresentationTime: framePTS)
  }
  // filteredBuffer はプレビューに出しているものと同一。プレビュー用と録画用で
  // バッファプールの参照カウントを分けるため、append 中のバッファは copyPixelBuffer で
  // 返さない(プールサイズを 6 に増やす)

stopRecording:
  writer.finishWriting → PHPhotoLibrary に .mov を保存 → path と duration を返す
```

- 注意: `startSession(atSourceTime:)` 前に append しない。audio は最初の video フレーム以降
  の PTS のみ append(先頭の無映像音声を防ぐ)。

## 3. Android 設計(MediaWriter + FilterRenderer 拡張)

```
startRecording:
  1. MediaRecorder 構成: setVideoSource(SURFACE), setAudioSource(CAMCORDER),
     setOutputFormat(MPEG_4), H.264/AAC, サイズ・ビットレート(1080p: 8Mbps)設定
  2. prepare() 後に recorder.surface を取得
  3. GL スレッドで eglCreateWindowSurface(recorder.surface) → encoderEglSurface
  4. recorder.start()

毎フレーム(GL スレッド、プレビュー描画の直後):
  if (recording) {
      eglMakeCurrent(encoderEglSurface)
      同じシェーダー・同じ params・同じ入力テクスチャで再描画
      EGLExt.eglPresentationTimeANDROID(display, encoderEglSurface, frameTimeNs)
      eglSwapBuffers(encoderEglSurface)
      eglMakeCurrent(previewEglSurface)   // 戻す
  }

stopRecording:
  recorder.stop(); release() → MediaStore.Video へ移動 → path と duration を返す
```

- `eglPresentationTimeANDROID` に `SurfaceTexture.getTimestamp()` を渡すこと
  (滑らかな VFR 動画になる)。
- `RECORD_AUDIO` 権限は録画モード初回選択時に要求する。

## 4. P0 に織り込む「後付けフック」

P0 実装時点で以下を守れば、P2 は MediaWriter の追加だけで済む:

1. **iOS**: FilterRenderer の出力バッファプールを外から差し替え可能にし、GPU 完了
   コールバックに「録画シンク」を挿せる関数ポインタ(クロージャ)を用意しておく。
2. **Android**: FilterRenderer の描画関数を `draw(target: EGLSurface, params, texMatrix)` の
   形にしておき、描画先を引数化する(プレビュー専用にハードコードしない)。
3. **Dart**: `startRecording`/`stopRecording`/`recordingProgress` の API・UI 状態
   (`recording` フェーズ)は 02/04 で定義済み。P0 では動画モード UI を非表示にするだけ。

## 5. 検証項目(P2 受け入れ基準)

- 録画中にスライダーを 2026→1000 まで動かし、再生動画に色調変化が連続的に記録されている
- 音ズレ: 手を叩く動画 30 秒で音と映像のズレが知覚できない(±50ms 以内)
- 10 分連続録画でクラッシュ・フレームレート半減がない(発熱テスト、実機 2 機種)
- 着信・home ボタンで中断した場合、それまでの録画が保存されている
