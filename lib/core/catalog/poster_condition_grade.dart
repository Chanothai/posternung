/// The 8-level poster condition scale (ADR-0003) — pure Dart, no Flutter
/// import, so both `features/poster/domain/` and the shared
/// `core/widgets/condition_grade_indicator.dart` can depend on the same
/// type without domain importing Flutter or a `core/widgets/` file that
/// does.
///
/// **Declaration order is meaning, not alphabetical** — matches the
/// PostgreSQL enum `poster_condition` (`app/models/enums.py` in
/// `posternung-backend`) and the API contract's `PosterCondition` schema
/// exactly: `mint > near_mint > very_fine > fine > very_good > good > fair >
/// poor`. Never reorder this list or add a value without updating the
/// backend enum first — see ADR-0003.
enum PosterConditionGrade {
  mint,
  nearMint,
  veryFine,
  fine,
  veryGood,
  good,
  fair,
  poor,
}

/// Display/interop metadata for [PosterConditionGrade]. Kept as an
/// extension (rather than fields on the enum) so this file stays trivial to
/// scan for the one thing that actually matters — the declaration order
/// above.
extension PosterConditionGradeX on PosterConditionGrade {
  /// Total number of levels on the scale — always `8`. Exposed as an
  /// instance getter (rather than requiring callers to reach for a static)
  /// so `core/widgets/condition_grade_indicator.dart` can compute "x/8" from
  /// a single value.
  int get scaleLength => PosterConditionGrade.values.length;

  /// 1-based position on the scale, best first — e.g. `mint` is `1`,
  /// `poor` is `8`. ADR-0003's UI mandate: never show [label] alone, always
  /// pair it with this (e.g. "Very Good (5/8)") so the reader isn't misled
  /// by "Very Good" reading as better than "Fine" when it's the opposite.
  int get scalePosition => PosterConditionGrade.values.indexOf(this) + 1;

  /// Standard collector-grading term, Title Case English — deliberately not
  /// translated (ADR-0003: this is the vocabulary the target audience
  /// already reads, unlike a numeric C1–C10 scale).
  String get label => switch (this) {
    PosterConditionGrade.mint => 'Mint',
    PosterConditionGrade.nearMint => 'Near Mint',
    PosterConditionGrade.veryFine => 'Very Fine',
    PosterConditionGrade.fine => 'Fine',
    PosterConditionGrade.veryGood => 'Very Good',
    PosterConditionGrade.good => 'Good',
    PosterConditionGrade.fair => 'Fair',
    PosterConditionGrade.poor => 'Poor',
  };

  /// Short Thai description of what this grade means — the content of the
  /// condition-scale guide bottom sheet (ADR-0003 §ข้อบังคับด้าน UI ข้อ 3).
  /// Generic collector-grading language, not specific to any one listing.
  String get thaiDescription => switch (this) {
    PosterConditionGrade.mint =>
      'สภาพสมบูรณ์แบบ ไม่มีร่องรอยการใช้งานหรือการจัดเก็บเลย',
    PosterConditionGrade.nearMint =>
      'ใกล้เคียงสมบูรณ์แบบ มีตำหนิเล็กน้อยที่สังเกตเห็นได้ยากมาก',
    PosterConditionGrade.veryFine =>
      'สภาพดีเยี่ยม มีร่องรอยจากการจัดเก็บเพียงเล็กน้อยเท่านั้น',
    PosterConditionGrade.fine => 'สภาพดีมาก อาจมีรอยพับหรือรอยขอบเบา ๆ',
    PosterConditionGrade.veryGood =>
      'สภาพดี มีร่องรอยการใช้งานที่มองเห็นได้ชัดขึ้น แต่ไม่กระทบภาพรวม',
    PosterConditionGrade.good =>
      'สภาพปานกลาง มีร่องรอยการใช้งานชัดเจน เช่น รอยพับหรือรอยเปื้อนเล็กน้อย',
    PosterConditionGrade.fair =>
      'สภาพพอใช้ มีตำหนิที่มองเห็นได้ง่าย เหมาะสำหรับนักสะสมที่เน้นความหายาก',
    PosterConditionGrade.poor =>
      'สภาพต่ำ มีความเสียหายชัดเจน เก็บไว้เพื่อคุณค่าทางประวัติศาสตร์เป็นหลัก',
  };

  /// The wire value used by `posternung-backend`'s `PosterCondition` enum
  /// (`GET /posters/{poster_id}`'s `condition_grade` field) — snake_case,
  /// matches [PosterConditionGrade.name] for every value except the
  /// multi-word ones, which need an explicit mapping since Dart enum names
  /// can't contain underscores in camelCase form.
  String get apiValue => switch (this) {
    PosterConditionGrade.mint => 'mint',
    PosterConditionGrade.nearMint => 'near_mint',
    PosterConditionGrade.veryFine => 'very_fine',
    PosterConditionGrade.fine => 'fine',
    PosterConditionGrade.veryGood => 'very_good',
    PosterConditionGrade.good => 'good',
    PosterConditionGrade.fair => 'fair',
    PosterConditionGrade.poor => 'poor',
  };
}

/// Parses the backend's `condition_grade` wire value. Returns `null` for a
/// `null` input (the field is genuinely nullable — no service-layer guard
/// exists yet, see ADR-0003's "ช่องโหว่ที่ต้องปิด" — and for any value this
/// client doesn't recognize, so a future backend-side addition degrades to
/// "no grade shown" instead of crashing the app.
PosterConditionGrade? posterConditionGradeFromApi(String? value) {
  if (value == null) return null;
  for (final grade in PosterConditionGrade.values) {
    if (grade.apiValue == value) return grade;
  }
  return null;
}
