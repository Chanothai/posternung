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

  /// The `"x/8"` fragment ADR-0003 mandates pairing with [label] everywhere
  /// a grade is shown, and ADR-0016 D6 additionally mandates pairing with
  /// any *color* used to represent the scale. Kept as one getter so the
  /// exact format (`4/8`, not `4 of 8` or `4-8`) has a single source across
  /// `ConditionGradeIndicator`, the guide sheet's grade rows, and its
  /// per-row position track.
  String get scaleFractionLabel => '$scalePosition/$scaleLength';

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

  /// Structured wear-trace breakdown for this grade (ADR-0016 AC-3a / D9).
  ///
  /// The vocabulary these phrases may use is locked — **`ADR-0016` D9
  /// §ขอบเขตของการล็อก is the sole owner of that rule, including which part
  /// of a phrase the lock covers.** Read it before rewording anything here;
  /// don't restate it in this file (D9 says so by name).
  ///
  /// (code-critic 2026-08-06 round 1 caught `รอยยับ` and `ฉีก`/`รอยฉีก`/
  /// `ฉีกขาด` here — neither is in BL-60's six terms. Fixed by removing
  /// both, not by unilaterally adding them to BL-60 — that vocabulary is
  /// the user's to extend, and whether "torn/creased" needs its own D9 term
  /// is now a GATE 3 question, not a decision made by editing this file.
  ///
  /// GATE 3 (2026-08-06) resolved that question: the user approved `ฉีก`
  /// as a seventh locked term; `ยับ` stays rejected. See ADR-0016 D9
  /// §ขอบเขตของการล็อก for the current list — not restated here.)
  ///
  /// Empty for [mint] — there is no trace to list, not a missing value.
  /// Rendering that empty case is a **UI** concern (a dedicated "no traces"
  /// line, not a blank section) — see
  /// `AppStrings.conditionGuideNoTracesLabel` at the one call site
  /// (`condition_grade_guide_sheet.dart`).
  ///
  /// Each of the 7 nouns forms its own severity *ladder* across whichever
  /// grades mention it, and that ladder must read as monotonically
  /// non-decreasing from [mint] toward [poor] — GATE 3 round 2 (2026-08-06)
  /// found two places this broke (`good`/`fair` used byte-identical text
  /// for `ขอบ`; `poor`'s `รอยพับ` phrase read *milder* than `fair`'s
  /// because it dropped `ชัดเจน`) and asked for every repeated dimension to
  /// be re-audited, not just the two flagged spots. The ladders, read top
  /// (mildest) to bottom (worst), as they appear below:
  ///   - รอยพับ: เล็กน้อยมาก(nearMint) → เบา ๆ(veryFine) →
  ///     สังเกตเห็นได้(fine) → หลายจุด(veryGood) → ชัดเจนหลายจุด(good) →
  ///     ชัดเจนทั่วใบ(fair) → หนาแน่นทั่วทั้งใบ(poor)
  ///   - ขอบ (wear escalating into tear at the bottom two grades):
  ///     มีรอยเล็กน้อย(veryFine) → สึกบาง ๆ(fine) → สึกชัดขึ้น(veryGood) →
  ///     สึกชัดเจน(good) → สึกและมีรอยฉีกเล็กน้อย(fair) →
  ///     สึกและฉีกขาด(poor)
  ///   - รูหมุด: มีรูหมุด(fair) → มีรูหมุดชัดเจน(poor)
  ///   - คราบ: จาง ๆ(veryGood) → ที่สังเกตเห็นได้(good) → ชัดเจน(fair) →
  ///     ชัดเจนหลายจุด(poor)
  ///   - สีซีด: เล็กน้อย(good) → ที่สังเกตเห็นได้(fair) → ชัดเจน(poor)
  ///   - เทป: only [poor] mentions it — no cross-grade ladder to check.
  List<String> get wearTraces => switch (this) {
    PosterConditionGrade.mint => const [],
    PosterConditionGrade.nearMint => const ['รอยพับที่มุมเล็กน้อยมาก'],
    PosterConditionGrade.veryFine => const ['รอยพับเบา ๆ', 'ขอบมีรอยเล็กน้อย'],
    PosterConditionGrade.fine => const [
      'รอยพับที่สังเกตเห็นได้',
      'ขอบสึกบาง ๆ',
    ],
    PosterConditionGrade.veryGood => const [
      'รอยพับหลายจุด',
      'ขอบสึกชัดขึ้น',
      'มีคราบจาง ๆ',
    ],
    PosterConditionGrade.good => const [
      'รอยพับชัดเจนหลายจุด',
      'ขอบสึกชัดเจน',
      'มีคราบที่สังเกตเห็นได้',
      'มีสีซีดเล็กน้อย',
    ],
    PosterConditionGrade.fair => const [
      'รอยพับชัดเจนทั่วใบ',
      'มีรูหมุด',
      'ขอบสึกและมีรอยฉีกเล็กน้อย',
      'มีคราบชัดเจน',
      'มีสีซีดที่สังเกตเห็นได้',
    ],
    PosterConditionGrade.poor => const [
      'รอยพับหนาแน่นทั่วทั้งใบ',
      'มีรูหมุดชัดเจน',
      'ขอบสึกและฉีกขาด',
      'มีคราบชัดเจนหลายจุด',
      'สีซีดชัดเจน',
      'มีรอยเทปซ่อม',
    ],
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
