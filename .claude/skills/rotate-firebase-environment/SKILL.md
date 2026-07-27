---
name: rotate-firebase-environment
description: >
  คำสั่งตรวจและวิธีหมุน Firebase config ต่อ flavor (sit/uat/production) ของ PosterNung
  — เทียบค่าฝั่ง Dart กับ native ทีละ field ให้เจอจุดที่ drift, รัน flutterfire configure
  แล้วเก็บกวาด side effect. ใช้ skill นี้เมื่อเจอ [core/duplicate-app], Google Sign-In
  ค้างหลังกด consent, สงสัยว่า flavor ไหนชี้ Firebase project ผิด, เพิ่ง regenerate
  google-services.json / GoogleService-Info.plist, จะย้าย environment ไป project ใหม่,
  หรือจะเพิ่ม flavor — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
---

# ตรวจ/หมุน Firebase config ต่อ flavor (PosterNung)

ไฟล์นี้เก็บ **คำสั่งตรวจจริง + กับดักที่เจอมาแล้ว** เท่านั้น

*เหตุผล*ว่าทำไมต้อง sync กัน, ตาราง flavor↔project↔bundle ID, ขั้นตอน console,
คำเตือน 3 ไฟล์ — อยู่ครบใน **`docs/environments-setup.md`** อ่านจากตรงนั้น ไม่ทวนซ้ำ

## 1. ตรวจว่า Dart ตรงกับ native มั้ย (Android)

`firebase_core` เทียบ `apiKey` / `appId` / `projectId` / `storageBucket` ถ้าไม่ตรง
= `[core/duplicate-app]` ตอนเปิดแอป

```bash
for env in sit uat production; do
  echo "════ $env ════"
  awk '/static const FirebaseOptions android/,/\);/' lib/firebase_options_$env.dart \
    | grep -E "apiKey|appId|projectId|storageBucket"
  python3 -c "
import json
d = json.load(open('android/app/src/$env/google-services.json'))
for c in d['client']:
    print('   pkg=%-42s appId=%s' % (
        c['client_info']['android_client_info']['package_name'],
        c['client_info']['mobilesdk_app_id']))
print('   projectId:', d['project_info']['project_id'])
"
done
```

> ⚠️ **ต้องวนทุก `client` ห้ามอ่านแค่ `client[0]`** — ไฟล์ของ project ที่แชร์กัน
> (`posternung`) บรรจุ client ของ **ทุก package** ไว้ในไฟล์เดียว ถ้าอ่านแค่ตัวแรก
> จะเห็น appId ไม่ตรงแล้วสรุปผิดว่าเจอบั๊ก **เคยเกือบรายงานผิดมาแล้ว** — จับคู่ด้วย
> `package_name` เสมอ
>
> ผลพลอยได้: `uat` กับ `production` มี `google-services.json` **เหมือนกันเป๊ะ**
> (checksum ตรงกัน) เพราะมาจาก project เดียวกัน — เป็นเรื่องปกติ ไม่ใช่ไฟล์ผิด
> Gradle เลือก client ตาม applicationId ของ flavor เอง

## 2. ตรวจฝั่ง iOS

```bash
for env in sit uat production; do
  echo "════ $env ════"
  awk '/static const FirebaseOptions ios/,/\);/' lib/firebase_options_$env.dart \
    | grep -E "apiKey|appId|projectId|iosBundleId"
  plutil -p ios/Runner/Firebase/$env/GoogleService-Info.plist \
    | grep -E "API_KEY|GOOGLE_APP_ID|PROJECT_ID|BUNDLE_ID"
done
```

## 3. ตรวจ `REVERSED_CLIENT_ID` — พังเงียบสนิท

```bash
for env in sit uat production; do
  printf "%-11s plist:   " $env
  plutil -extract REVERSED_CLIENT_ID raw ios/Runner/Firebase/$env/GoogleService-Info.plist
done
grep -h REVERSED_CLIENT_ID ios/Flutter/Sit.xcconfig ios/Flutter/Uat.xcconfig ios/Flutter/Production.xcconfig
```

ค่าใน xcconfig ของ flavor ไหน **ต้องตรงกับ plist ของ flavor นั้น** ไม่ตรงเมื่อไหร่
Google Sign-In จะ**ค้างหลังผู้ใช้กด consent โดยไม่มี error ใดๆ ทั้งใน log และบนจอ**
(SDK อ่าน `CLIENT_ID` จาก plist ตอน runtime แล้ว redirect ไป scheme นั้น แต่
`Info.plist` ประกาศ scheme อีกอันไว้ iOS เลย route กลับแอปไม่ได้)

ยืนยันกับ **แอปที่บิลด์แล้ว** (source plist ยังเป็น `$(...)` placeholder อยู่):
```bash
plutil -p "$(find build/ios -name Runner.app -maxdepth 3 | head -1)/Info.plist" \
  | grep -A4 CFBundleURLSchemes
```

## 4. regenerate เมื่อจำเป็น

```bash
~/.pub-cache/bin/flutterfire configure \
  --project=posternung-sit \
  --out=lib/firebase_options_sit.dart \
  --platforms=android,ios \
  --android-package-name=com.frameshine.posternung.sit \
  --ios-bundle-id=com.frameshine.posternung.sit \
  --yes
```
(`flutterfire` ไม่ได้อยู่บน PATH ต้องเรียก full path)

**เก็บกวาด side effect ทันที** — 3 อย่างนี้เกิดทุกครั้ง:

1. สร้าง `android/app/google-services.json` ที่ root ทิ้งไว้ → **ต้อง `rm`**
   repo นี้ใช้ per-flavor path เท่านั้น ไฟล์ root ไม่ผูกกับ flavor ไหนเลย แต่ทำให้สับสน
2. format ไฟล์ที่ generate ไม่ตรง → รัน `dart format lib/firebase_options_<env>.dart`
3. **ไม่แตะ `web` block** ถ้าใช้ `--platforms=android,ios` → ค่าเก่าค้างอยู่เงียบๆ
   ตอนนี้ `firebase_options_sit.dart` block `web` ยังชี้ project `posternung` (เก่า)
   บนมือถือไม่มีผล แต่ `flutter run -d chrome` จะไปคุย project ผิดโดยไม่มีสัญญาณอะไร

`git diff` ไฟล์ per-flavor (`android/app/src/*/google-services.json`,
`ios/Runner/Firebase/*/`) หลังรัน — ต้อง **ไม่เปลี่ยน** ถ้าเปลี่ยนให้ `git checkout` คืน

## 5. ยืนยันปลายทาง

```bash
flutter build apk --debug --flavor sit        # ผ่าน = google-services plugin จับคู่ client ถูก
flutter build ios --flavor sit --debug --no-codesign
```

Android: `aapt2 dump packagename <apk>` ต้องได้ applicationId ตรง flavor
iOS: เช็ค `CFBundleURLSchemes` + `PROJECT_ID` ของ plist ที่ถูก copy เข้า `Runner.app` (§3)

## กับดักที่เจอมาแล้ว

| อาการ | สาเหตุจริง | จับยังไง |
|---|---|---|
| `[core/duplicate-app]` ตอนเปิดแอป | native auto-init จาก plist ที่ bundle มา **ก่อน** Dart รัน แล้ว `Firebase.initializeApp()` ส่ง options คนละชุด | §1/§2 — **อย่าไปหา `initializeApp` ซ้ำ** มีที่เดียวใน `main.dart` เสมอ |
| อ่าน `client[0]` แล้วสรุปว่า appId ไม่ตรง | ไฟล์ของ project ที่แชร์มี client ทุก package | §1 — วนทุก client จับคู่ด้วย `package_name` |
| Google Sign-In ค้างหลัง consent เงียบสนิท | `REVERSED_CLIENT_ID` ใน xcconfig ค้างค่าของ project เก่า | §3 — ไม่มีทางเห็นจาก log ต้องเทียบเอง |
| ย้าย project แล้วมือถือใช้ได้ แต่ web คุย project เก่า | `--platforms=android,ios` ไม่แตะ `web` block | §4 ข้อ 3 |
| `flutterfire configure` แล้วมีไฟล์โผล่ที่ `android/app/` | fileOutput ใน `firebase.json` เป็น path แบบ single-project | §4 ข้อ 1 — ลบทิ้ง |

## เมื่อไหร่ควรอ่านต่อ

- แก้ config แล้วต้องพิสูจน์บนอุปกรณ์จริง → skill **`run-and-verify-on-device`**
- ยังไม่แน่ใจว่าพังที่ config หรือที่โค้ด → skill **`debug-auth-failure`** ก่อน
