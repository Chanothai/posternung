---
name: debug-auth-failure
description: >
  ขั้นตอนไล่หาสาเหตุเวลา login/OTP/register บน PosterNung ล้มเหลว — อ่าน error code
  บนจอให้รู้ว่าพัง layer ไหน แล้วยืนยันด้วย docker log / DB / container env ของ
  posternung-backend. ใช้ skill นี้เมื่อผู้ใช้บอกว่า login ไม่ผ่าน, OTP ไม่ผ่าน,
  เข้าระบบแล้วเด้งกลับ, **ล็อกอิน Google/อีเมลผ่านแล้วแต่ไม่ไปหน้า home / กดแล้วไม่เกิดอะไรขึ้น**,
  เจอ error banner สีแดงในแอป, เจอ FirebaseException /
  AuthException / 401 / 422 จาก /auth/firebase หรือ /auth/me, หรือถามว่า "ทำไม auth พัง"
  — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill แค่เล่าอาการก็เข้าเงื่อนไข
---

# ไล่หาสาเหตุ auth ที่พัง (PosterNung)

ไฟล์นี้เก็บ **ลำดับการไล่ + กับดักที่เจอมาแล้วจริง** เท่านั้น

โครงสร้าง auth (dual session, `/auth/firebase`, AuthInterceptor, error display)
อยู่ใน **`lib/features/auth/CLAUDE.md`** ซึ่งโหลดอัตโนมัติอยู่แล้ว — ไม่ทวนซ้ำที่นี่
ส่วน config ต่อ environment อยู่ใน `docs/environments-setup.md`

**อย่าเดา** — ทุกอาการมีวิธียืนยันด้วยคำสั่งจริง ทำตามลำดับ 1 → 2 → 3

## 1. อ่าน error code บนจอก่อนเสมอ

`AuthErrorBanner` แสดง 2 บรรทัด: ข้อความไทย (แดง) + **`รหัสข้อผิดพลาด: <code>` (เทา)**
บรรทัดเทาคือตัวชี้ layer ให้ถามผู้ใช้เสมอถ้าเขาไม่ได้บอกมา

| code ที่เห็น | พังที่ไหน | ไปทำอะไรต่อ |
|---|---|---|
| `network_error` | **ไม่เคยถึง backend** | เช็ค baseURL/เครือข่ายก่อน ข้ามไป §2 ได้เลย (log จะว่าง) |
| `validation_error` | ถึง backend แล้ว แต่ request body ผิด (FastAPI 422) | ข้อความจะบอก field ที่ fail — ดูว่าเราส่งอะไรว่างไป |
| `SCREAMING_SNAKE_CASE` | backend ปฏิเสธเอง (`AppError`) | ข้อความไทยมาจาก backend แล้ว เชื่อได้ ไปดู §3 ว่า config ตรงมั้ย |
| `phone_signin_*` | Firebase SDK ฝั่ง client | ชื่อ type ต่อท้ายบอกว่าเป็นอะไร (`PlatformException` ฯลฯ) |
| kebab-case ของ Firebase (`invalid-verification-code`, `too-many-requests`) | Firebase ปฏิเสธ | เป็น error ปกติที่ map เป็นไทยแล้ว มักไม่ใช่บั๊กเรา |
| `unexpected_*` | **parse response พัง = บั๊กฝั่งเรา** | backend ตอบ 200 แต่ shape ไม่ตรงกับ model → §2 จะเห็น 200 |
| code เป็นชื่อ type ดิบๆ (`StateError`, `TypeError`) | **หลุด guard ทุกชั้น** | เป็นบั๊กที่ต้องแก้ที่ data source — ใส่ `catch (e)` ปิดท้ายให้ครบ |

**ถ้าไม่มีบรรทัดเทาเลย** = ของที่โยนมาไม่ใช่ `AuthException` และ `authErrorDisplayFor`
ก็ fallback ไม่ทัน → เป็นบั๊กการ wrap ที่ data source ให้แก้ตรงนั้นก่อน ไม่ต้องไล่ต่อ

## 2. request ไปถึง backend รึเปล่า

```bash
docker logs -t --tail 30 posternung-sit-app
```

> ⚠️ **timestamp เป็น UTC แต่เครื่องเราคือ +07** — ต้องบวก 7 เองทุกครั้ง
> เคยพลาดจริง: เห็น 422 ที่ `02:20Z` แล้วนึกว่าเป็นของที่เพิ่งกดไป ทั้งที่นั่นคือ
> 09:20 น. เมื่อ 3 ชั่วโมงก่อน เกือบไล่ผิดทาง เทียบกับ `date -u` ก่อนสรุปเสมอ

อ่านผลแบบนี้:

- **ไม่มีบรรทัดใหม่เลย** → request ไม่เคยมาถึง **แต่มีสองสาเหตุ ไม่ใช่หนึ่ง**
  · 🔴 **‹แก้ 2026-09-10 — เดิมบรรทัดนี้เขียนว่า "คือตายที่ Firebase" ห้วน ๆ ซึ่งพา
  ไล่ผิดทางไปแล้วหนึ่งรอบ›**
  | ถ้า error code คือ | แปลว่า |
  |---|---|
  | `phone_signin_*` · kebab-case ของ Firebase | **ตายที่ Firebase จริง** — ไปดู §1 |
  | **`network_error`** | 🔴 **Firebase ผ่านแล้ว แต่ยิง HTTP ไปที่ที่ไม่มีตัวตน** — ไม่ใช่เรื่องของ Firebase เลย ไป **§4** |
  ⚠️ **จำนวนบรรทัดที่ backend เห็น = 0 เหมือนกันทั้งสองกรณี** แยกด้วย log ไม่ได้
  ต้องแยกด้วย error code จาก §1 เสมอ
- **`POST /auth/firebase` 200 แต่แอปขึ้น error** → auth สำเร็จแล้ว พังตอน **parse
  response หรือขั้นถัดไป** (`/auth/me`, secure storage) นี่คือ `unexpected_*`
- **422** → body ที่เราส่งผิด ดู §1 แถว `validation_error`
- **401** → token ถูกปฏิเสธ ไปต่อ §3 (มักเป็น project ไม่ตรง)

ทั้ง `/auth/firebase` และ `/auth/me` ต้องมาคู่กันเสมอ — เห็นแค่ตัวแรก 200 แล้วเงียบ
แปลว่าพังระหว่างสองอันนี้

## 3. เช็ค config ของ container ที่รันอยู่จริง

**เช็ค Firebase project ที่ backend ใช้ verify token:**
```bash
docker exec posternung-sit-app printenv | grep -iE "FIREBASE|ENVIRONMENT"
```
ต้องได้ `FIREBASE_PROJECT_ID=posternung-sit` — repo มี **`.env` (ชี้ `posternung`)
กับ `.env.sit` (ชี้ `posternung-sit`) คนละไฟล์** ถ้า container ถูกยกขึ้นด้วยไฟล์ผิด
token จาก flavor sit จะโดน reject ทั้งหมดโดยที่โค้ดฝั่งแอปไม่ผิดอะไรเลย

**เช็ค user ใน DB:**
```bash
docker exec posternung-sit-db psql -U poster_nung_app -d poster_nung_db_sit \
  -c "select u.id, u.email, u.phone, u.created_at, oi.provider, oi.provider_user_id
      from users u left join oauth_identities oi on oi.user_id = u.id
      order by u.created_at desc limit 10;"
```

> ⚠️ **`-U postgres` ใช้ไม่ได้** — ได้ `FATAL: role "postgres" does not exist`
> user/db ต้องเอาจาก `POSTGRES_USER` / `POSTGRES_DB` ใน `posternung-backend/.env.sit`

มี row = เคยล็อกอินสำเร็จมาก่อน (config ฝั่ง Firebase Console ถูกแล้ว) ปัญหาอยู่ที่อื่น

## 4. `network_error` — เช็คว่าอุปกรณ์ต่อถึง backend จริงไหม

‹เพิ่ม 2026-09-10 หลังเสียเวลาไล่ผิดทางไปหนึ่งรอบกับอาการ **"ล็อกอิน Google ผ่านแล้ว
แต่ไม่ไปหน้า home"**›

🔴 **อาการนี้อ่านเหมือนบั๊กของ auth แต่บ่อยครั้งไม่ใช่** — Google Sign-In คุยกับ
Firebase ซึ่งเป็น **public cloud** ⇒ **มีแค่เน็ตมือถือก็ผ่าน** · ส่วน `/auth/firebase`
คุยกับ backend ที่อยู่ใน **LAN ของคุณ** ⇒ ต้องมีเส้นทางถึงเครื่องคุณจริง ๆ

เมื่อขั้นที่สองล้ม จะไม่มี backend session และ **`AuthGate` เรนเดอร์หน้า login ต่อไป
ซึ่งถูกต้องตาม ADR-0021 D1** (Firebase session เปล่า ๆ ไม่นับว่าล็อกอิน) —
**ไม่ใช่บั๊ก** แต่ผู้ใช้เห็นเป็น "กดแล้วไม่เกิดอะไรขึ้น"

ไล่สี่ข้อนี้ตามลำดับ **ก่อน**จะไปแตะโค้ด auth:

```bash
# 1. backend ยังอยู่ไหม และ IP ของเครื่องเราคืออะไร "ตอนนี้"
docker ps --format "{{.Names}}\t{{.Status}}" | grep sit
ipconfig getifaddr en0

# 2. ค่าที่แอปจะใช้จริง — ตรงกับข้อ 1 ไหม
grep -n "Environment.sit =>" lib/core/config/api_base_url_resolver.dart

# 3. อุปกรณ์ต่อเน็ตแบบไหน  🔴 ข้อที่คนลืมบ่อยที่สุด
adb shell dumpsys wifi | grep -m1 "mWifiInfo SSID"     # DISCONNECTED = ไม่มี Wi-Fi
adb shell ip -4 -o addr | awk '{print $2, $4}'         # ไม่มี wlan0 = ต่อ LAN ไม่ได้แน่นอน

# 4. ยิงจากอุปกรณ์เองเลย ไม่ใช่จาก Mac
adb shell "curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://<ip>:8000/health"
```

⚠️ **`curl` จาก Mac ผ่าน ไม่ได้แปลว่าอุปกรณ์ต่อถึง** — คนละเครื่อง คนละเส้น
(ตระกูลเดียวกับกับดัก SPM ใน `run-and-verify-on-device` ที่ `curl` ผ่านแต่ `xcodebuild` ไม่ผ่าน)
· และ **`ping` ไม่ผ่านก็ยังสรุปไม่ได้** เพราะ ICMP ถูกบล็อกได้โดยที่ TCP:8000 ยังเปิด — วัดที่ port จริงเสมอ

### 4.1 🔴 เครื่องจริงที่ไม่มี Wi-Fi — ใช้ `adb reverse` ไม่ใช่ LAN IP

เจอจริง 2026-09-10: เครื่องเสียบสาย USB อยู่ Wi-Fi `DISCONNECTED` ไม่มี IP เลย มีแต่ LTE
⇒ **ไม่มีทางถึง LAN IP ใด ๆ ทั้งสิ้น** และแก้ค่า `API_BASE_URL` เป็นเลขอะไรก็ไม่ช่วย

```bash
adb reverse tcp:8000 tcp:8000      # ส่ง 127.0.0.1:8000 ของ "มือถือ" มาที่ 8000 ของ Mac ผ่านสาย USB
adb reverse --list                 # ยืนยัน: UsbFfs tcp:8000 tcp:8000
```
แล้วรันด้วย `--dart-define=API_BASE_URL=http://127.0.0.1:8000`

⚠️ **หายเมื่อถอดสาย/รีสตาร์ท adb** ต้องรันซ้ำหนึ่งครั้งต่อการเสียบสาย
· `.vscode/launch.json` มี config `เครื่องจริง USB` ที่ตั้งค่านี้ไว้แล้ว

### 4.2 🔴 ค่า default ของ SIT เป็นของเฉพาะเครื่อง — อย่าเชื่อว่ามันยังใช้ได้

SIT **ไม่มี backend ที่ deploy ไว้** ที่อยู่จึงผูกกับเครื่องและเครือข่ายเสมอ
IP ที่เคยใช้ได้จะตายเงียบ ๆ เมื่อย้ายเครือข่าย **โดยไม่มีเทสไหนแดง**

⇒ **ส่งผ่าน `--dart-define=API_BASE_URL=...` เสมอ** ตามเป้าหมายจริง:

| รันบนอะไร | ที่อยู่ |
|---|---|
| เครื่องจริงต่อ USB | `http://127.0.0.1:8000` + `adb reverse` (§4.1) |
| iOS Simulator | `http://127.0.0.1:8000` |
| Android Emulator | `http://10.0.2.2:8000` |
| เครื่องจริงบน Wi-Fi วงเดียวกัน | `http://$(ipconfig getifaddr en0):8000` |

## กับดักที่เจอมาแล้ว

| อาการ | สาเหตุจริง | วิธีจับ |
|---|---|---|
| แดงว่า "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง" **ไม่มีบรรทัดเทา** ทั้งที่ Firebase ผ่านแล้ว | `BackendUser.email` เป็น `required String` แต่ backend ส่ง `"email": null` จริงสำหรับ user ที่สมัครด้วยเบอร์อย่างเดียว → `fromJson` โยน `TypeError` ดิบๆ | log จะเห็น `/auth/me` **200** (§2) — 200 + แอป error = parse พัง เทียบ `openapi.json` ว่า field ไหน nullable |
| `/auth/firebase` ตอบ **422** เป็นคู่ๆ | `getIdToken()` คืน **string ว่าง** (ไม่ใช่ null) ผ่านเช็ค `== null` แล้วถูกยิงเป็น `{"id_token": ""}` ชน `min_length=1` | เช็ค `idToken.isEmpty` ด้วยเสมอ ไม่ใช่แค่ `== null` |
| `FirebaseException ([core/duplicate-app])` ตอนเปิดแอป | native auto-init จาก plist ที่ bundle มา **ก่อน** Dart รัน แล้ว `Firebase.initializeApp()` ส่ง options ที่ไม่ตรง | ไม่ต้องหา `initializeApp` ซ้ำ (มีที่เดียวใน `main.dart`) → ใช้ skill `rotate-firebase-environment` |
| Google Sign-In ค้างหลังกด consent ไม่มี error ใดๆ | `REVERSED_CLIENT_ID` ใน xcconfig ไม่ตรงกับ plist ของ flavor นั้น URL callback เลย route กลับแอปไม่ได้ | **ไม่มีทางเห็นจาก log** → skill `rotate-firebase-environment` |
| 🔴 **Google Sign-In ผ่าน (ไม่มี error banner) แต่ยังค้างอยู่หน้า login ไม่ไป `/home`** | Firebase สำเร็จเพราะเป็น public cloud (เน็ตมือถือก็พอ) แต่ `POST /auth/firebase` ยิงไป LAN IP ที่อุปกรณ์ไปไม่ถึง ⇒ ไม่มี backend session ⇒ `AuthGate` เรนเดอร์ `LoginScreen` ต่อ **ตาม ADR-0021 D1 ซึ่งถูกต้องแล้ว ไม่ใช่บั๊ก** · เจอจริง 2026-09-10: มือถือ Wi-Fi `DISCONNECTED` มีแต่ LTE **และ** ค่า default ของ SIT เป็น IP ที่ตายไปแล้ว — สองชั้นพร้อมกัน | `docker logs` **ไม่มี `/auth/firebase` เลยสักบรรทัด** (เช็คด้วย `grep -c`) ⇒ §4 · 🔴 อย่าเริ่มจากโค้ด auth |
| log ขึ้น `Could not find a generator for route /link?deep_link_id=...` | Flutter engine ตีความ redirect ของ reCAPTCHA เป็น route name | **ไม่ใช่ error จริง** auth ผ่านปกติ ดู `docs/phone-auth-setup.md` §3.5.1 |

## เมื่อไหร่ควรอ่านต่อ

- ต้องรันบน simulator/เครื่องจริงเพื่อ reproduce → skill **`run-and-verify-on-device`**
- สงสัยว่า config ต่อ environment เพี้ยน (project/appId/URL scheme ไม่ตรง) → skill
  **`rotate-firebase-environment`**
