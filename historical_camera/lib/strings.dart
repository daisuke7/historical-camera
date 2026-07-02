/// Central place for all user-facing strings (docs/02 §5).
/// Keep every UI string here to ease future i18n.
class Strings {
  Strings._();

  static const appName = 'Historical Camera';

  // Permission / error views (docs/04 §5).
  static const permissionDeniedTitle = 'カメラを使用できません';
  static const permissionDeniedBody =
      '昔の見た目を再現するためにカメラを使用します。\n設定アプリからカメラへのアクセスを許可してください。';
  static const openSettings = '設定を開く';
  static const errorTitle = 'エラーが発生しました';
  static const retry = '再試行';

  // Era label (docs/04 §3).
  static const now = '現在';

  /// Big title for the era label: 現在 / 1970年代 / 1500年ごろ.
  /// Years at or before 1840 use the approximate "ごろ" form.
  static String eraTitle(int quantizedYear, int nowYear) {
    if (quantizedYear >= nowYear) return now;
    if (quantizedYear > 1840) return '$quantizedYear年代';
    return '$quantizedYear年ごろ';
  }

  /// Small subtitle describing the media era of the given year.
  static String eraDescription(int year, int nowYear) {
    if (year >= nowYear) return '';
    if (year >= 2000) return 'デジタル写真の時代';
    if (year >= 1970) return 'カラー写真の時代';
    if (year >= 1840) return 'モノクロ写真の時代';
    if (year >= 1500) return '版画の時代';
    return '絵巻の時代';
  }

  // Media-boundary callouts shown for 1.5 s when crossed (docs/04 §3).
  static const boundaryPhotography = '1839 写真の発明';
  static const boundaryEngraving = '1500 版画の時代へ';
}
