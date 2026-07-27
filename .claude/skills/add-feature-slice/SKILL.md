---
name: add-feature-slice
description: >
  ลำดับลงมือสร้าง feature ใหม่ใน PosterNung ให้ครบชั้นโดยไม่ต้องย้อนกลับมาแก้ —
  สร้างอะไรก่อนหลัง, ก๊อป pattern จากไฟล์ไหนใน auth/, เขียนเทสแต่ละชั้นยังไง,
  verify แบบเดียวกับที่ CI เช็ค. ใช้ skill นี้เมื่อผู้ใช้ขอเพิ่ม feature ใหม่ (cart,
  checkout, poster detail, profile ฯลฯ), ขอต่อ API ใหม่เข้าแอป, ขอเพิ่มหน้าจอที่ต้อง
  ดึงข้อมูล, หรือขอขยาย feature เดิมให้มี data layer — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
---

# สร้าง feature slice ใหม่ (PosterNung)

ไฟล์นี้เก็บ **ลำดับปฏิบัติ + กับดักที่เจอมาแล้ว** เท่านั้น

กฎทั้งหมด (Clean Architecture, ห้ามข้าม layer, MVVM/MVI, Riverpod-only,
โครงสร้างโฟลเดอร์เป้าหมาย, กฎ AppImages) อยู่ใน **`CLAUDE.md` ที่โหลดอัตโนมัติทุก
session อยู่แล้ว — ไม่ทวนซ้ำที่นี่**

## 0. ตัดสินก่อนว่าต้องมีกี่ชั้น

feature ที่**ไม่มี data dependency** ห้ามสร้าง `data/`/`domain/` เปล่าไว้ก่อน —
`lib/features/onboarding/` มีแค่ `presentation/` ทั้งโฟลเดอร์ ใช้เป็นแบบได้เลย
ค่อยเพิ่มตอนที่มันคุยกับ repository จริงๆ

## 1. ลำดับที่ไม่ต้องย้อนกลับมาแก้

ไล่จากในออกนอก — แต่ละขั้นคอมไพล์ผ่านได้ด้วยตัวเองก่อนไปขั้นถัดไป:

| # | สร้าง | ดูของจริงที่ |
|---|---|---|
| 1 | `domain/entities/` — plain class ห้าม import Flutter/Firebase | `auth/domain/entities/auth_user.dart` |
| 2 | `domain/repositories/` — abstract แค่ signature | `auth/domain/repositories/auth_repository.dart` |
| 3 | `domain/usecases/` — 1 คลาส 1 action มี `call()` เดียว | `auth/domain/usecases/sign_out.dart` |
| 4 | `data/models/` — DTO `@freezed` + `fromJson`/`toEntity()` | `auth/data/models/backend_user.dart` |
| 5 | **`dart run build_runner build`** | ต้องรันก่อน analyze ไม่งั้นพังทั้งไฟล์ |
| 6 | `data/datasources/` — คุย API/SDK จริง | `auth/data/datasources/backend_auth_data_source.dart` |
| 7 | `data/repositories/` — implement ข้อ 2 แปลง exception เป็น domain type | `auth/data/repositories/auth_repository_impl.dart` |
| 8 | `presentation/providers/` — ต่อ DI chain + ViewModel | `auth/presentation/providers/auth_providers.dart` |
| 9 | `presentation/screens/` + `widgets/` | `auth/presentation/screens/login_screen.dart` |
| 10 | `test/` มิเรอร์โครงเดิมทุกไฟล์ | §3 |

**ยิง API ผ่าน `dioProvider` เดิมเสมอ** (`lib/core/network/api_client.dart`) — มี
`AuthInterceptor` แนบ Bearer + refresh-on-401 ให้แล้ว อย่าสร้าง `Dio` ตัวใหม่

## 2. จุดที่มักเผลอ hardcode

เจอตอนไหนให้หยุดแล้วย้ายไป token ทันที ไม่ต้องรอ refactor รอบหลัง:

| เผลอเขียน | ต้องไปอยู่ที่ |
|---|---|
| `'ข้อความไทย'` ใน widget | `core/strings/app_strings.dart` |
| `'assets/images/x.svg'` | `core/assets/app_images.dart` (**บังคับ** ตาม CLAUDE.md) |
| `EdgeInsets.all(24)` / `BorderRadius.circular(8)` / `size: 20` | `AppSpacing` / `AppRadius` / `AppDimens` |
| `Color(0xFF...)` / `TextStyle(...)` | `AppColors` / `AppTextStyles` |

## 3. เทสต์ทีละชั้น

- **usecase / repository impl** → mocktail mock ชั้นที่อยู่ใต้ลงไปหนึ่งชั้น
  (`test/features/auth/data/repositories/auth_repository_impl_test.dart`)
- **data source** → mock `Dio` แล้ว `verify` ทั้ง path และ body ที่ยิงจริง
  (`test/features/auth/data/datasources/backend_auth_data_source_test.dart`)
- **screen** → `ProviderScope(overrides: [...])` ด้วย Fake ViewModel ห้ามแตะ network จริง
  (`test/features/auth/presentation/screens/login_screen_test.dart`)

> ⚠️ **Fake ViewModel ต้องเซ็ต `state` ไม่ใช่ `throw`**
> ```dart
> // ❌ ของจริงจะไม่มีวันเห็น error นี้
> Future<void> confirmPhoneCode({...}) async => throw error;
> // ✅ เลียนแบบสิ่งที่ AsyncValue.guard ทำจริง
> Future<void> confirmPhoneCode({...}) async {
>   state = error != null ? AsyncError(error, StackTrace.current) : const AsyncData(null);
> }
> ```
> ของจริงห่อทุกอย่างด้วย `AsyncValue.guard` แล้วแปลง exception เป็น `AsyncError`
> — `throw` เฉยๆ ในของปลอมจะข้ามขั้นนั้น widget เลยไม่เคยเห็น error state

## 4. Verify — ตรงกับที่ CI รัน

`.github/workflows/ci.yml` รันตามลำดับนี้ ทำให้ครบก่อน commit:

```bash
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib/ test/
flutter analyze --fatal-infos
flutter test
```

`--fatal-infos` แปลว่า **info ก็แดง** ไม่ใช่แค่ error — unused import ตัวเดียวก็ไม่ผ่าน

**เปลี่ยนพฤติกรรมที่เห็นบนจอ?** unit test เขียวไม่พอ ต้องเปิดบนอุปกรณ์จริงดูด้วย →
skill `run-and-verify-on-device`

## กับดักที่เจอมาแล้ว

| อาการ | สาเหตุจริง | ทางแก้ |
|---|---|---|
| แอปขึ้น error สีแดงลอยๆ ไม่มี error code ให้ debug | data source จับ exception แคบเกินไป (`on DioException` / `on FirebaseAuthException` อย่างเดียว) ของอื่นหลุดดิบๆ ขึ้นไปถึง UI | **ทุก data source ต้องปิดท้ายด้วย `catch (e)`** ห่อเป็น `AuthException` ที่มี code เสมอ — ดู `_guard` ใน `backend_auth_data_source.dart` เป็นแบบ |
| `fromJson` โยน `TypeError` ตอน field เป็น null | DTO ประกาศ `required String` แต่ backend ส่ง null ได้จริง | เทียบ `posternung-backend/openapi.json` ทุก field ว่า `anyOf: [..., null]` มั้ย **ก่อน**เขียน model |
| แก้ `@freezed` แล้ว analyze พังทั้งไฟล์ | ลืมรัน build_runner — `.freezed.dart`/`.g.dart` เป็น gitignored ไม่มีใน repo | รันข้อ 5 ทุกครั้งที่แตะ model |
| เทสต์เขียวหมดแต่ของจริงพัง | Fake ViewModel `throw` แทนการเซ็ต state | §3 |
| สร้าง `data/`+`domain/` เปล่าไว้ก่อน "เผื่อ" | ผิดกฎ CLAUDE.md และทำให้อ่านยาก | §0 |

## เมื่อไหร่ควรอ่านต่อ

- ต่อ API แล้ว auth/token มีปัญหา → skill **`debug-auth-failure`**
- ต้องเห็นผลบนอุปกรณ์จริง → skill **`run-and-verify-on-device`**
- ก่อน commit/เปิด PR → **`docs/git-workflow.md`**
