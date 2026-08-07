---
name: run-and-verify-on-device
description: >
  วิธีรัน PosterNung บน iOS simulator, Android emulator หรือเครื่องจริงเพื่อ verify งาน
  ด้วยตาตัวเอง — กันบิลด์ชนกับ session ที่ผู้ใช้เปิดค้างไว้, สร้าง/บูต AVD, อ่าน log ให้ออก,
  กดหน้าจอ, แล้วเก็บกวาด. ใช้ skill นี้เมื่อจะ reproduce บั๊กบนอุปกรณ์จริง, ต้องพิสูจน์ว่า
  งานที่แก้ไปใช้ได้จริงไม่ใช่แค่ unit test เขียว, ต้องทดสอบปุ่ม back ของ Android,
  ผู้ใช้ขอให้ "ลองบนเครื่อง"/"รันดูหน่อย", หรือเจอ Xcode build failed / concurrent builds /
  emulator บูตไม่ขึ้น / build ค้างไม่มี output — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
---

# รันและ verify บนอุปกรณ์จริง (PosterNung)

ไฟล์นี้เก็บ **ลำดับปฏิบัติ + กับดักที่เจอมาแล้วจริง** เท่านั้น

ค่า baseURL ต่อ environment, cleartext/ATS, flavor/scheme ทั้งหมดอยู่ใน
**`docs/environments-setup.md` §6** — ไม่ทวนซ้ำที่นี่

## 1. เช็คก่อนบิลด์ทุกครั้ง — ห้ามข้าม

```bash
ps aux | grep -E "xcodebuild|flutter run" | grep -v grep
```

ผู้ใช้มัก**เปิด debug session ใน VS Code ค้างไว้** (`flutter run --machine
--start-paused ... --flavor sit`) ซึ่งใช้โฟลเดอร์ `build/ios` **ร่วมกับเรา** บิลด์
พร้อมกันเมื่อไหร่พังทันที:

- `Xcode build failed due to concurrent builds, will retry in 2 seconds`
- `Could not delete .../build/ios/Debug-sit-iphonesimulator because it was not
  created by the build system and it is not a subfolder of derived data`
- `Could not resolve package dependencies` (SPM resolution ชนกัน — หายเองถ้ารันใหม่ตอนว่าง)

> **ถ้าเจอ process ที่ไม่ใช่ของเรา ให้หยุดของเราเอง ห้ามไปฆ่าของเขา** — เขากำลัง
> debug อยู่ ดูที่ `-d <udid>` กับ `--flavor` ว่าชนกันจริงมั้ย และดู `--machine`
> (แปลว่ามาจาก IDE ไม่ใช่ terminal)

## 2. เลือกอุปกรณ์

```bash
flutter devices                          # เห็นทั้งเครื่องจริงและ simulator ที่ boot แล้ว
xcrun simctl list devices available      # รายชื่อ simulator ทั้งหมด
xcrun simctl boot "iPhone 17 Pro"        # boot ก่อนถึงจะ attach panel ได้
```

เปิด panel ให้ผู้ใช้ดูด้วย simulator tool (`attach`) — เรียกได้ตั้งแต่ก่อนบิลด์ ถ้ายัง
ไม่มีอะไร boot มันจะฟ้อง error ที่ไม่อันตราย boot แล้วค่อยเรียกซ้ำ

**เครื่องจริง vs simulator ต่างกันที่ backend**: simulator ใช้ `127.0.0.1` ได้ตรงๆ
เครื่องจริงต้องเป็น LAN IP — ส่งผ่าน `--dart-define=API_BASE_URL=...` (ดู doc §6)

## 3. รัน แล้วอย่าให้ log หาย

```bash
flutter run --flavor sit -d <udid> --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  > /tmp/flutter_run.log 2>&1
```

> ⚠️ **ห้าม pipe ผ่าน `| tail`** — `tail` buffer ไว้จนกว่า process จะจบ ระหว่างบิลด์
> ไฟล์จะ **ว่างเปล่าสนิท** ทำให้เข้าใจผิดว่าค้าง/ตาย ทั้งที่กำลังคอมไพล์อยู่ปกติ
> redirect ลงไฟล์แล้ว poll เอาแทน

รอด้วย until-loop ไม่ใช่ `sleep` ตายตัว:
```bash
until grep -qE "Flutter run key commands|Error|Xcode build failed" /tmp/flutter_run.log; do
  sleep 10
done
```

บิลด์แรก ~2 นาที บิลด์ถัดไป ~1 นาที (incremental)

## 4. กดหน้าจอเอง

ใช้ simulator tool: `screenshot` → `tap`/`swipe`/`text` → `screenshot` ยืนยันผล

- **พิกัดเป็น point ไม่ใช่ pixel** — ค่าที่ tool คืนตอน attach คือขนาดจริงที่ต้องใช้
  (เช่น 402×874) อย่าเอาพิกัดจากภาพ screenshot ที่ resolution สูงกว่ามาใช้ตรงๆ
- **screenshot ก่อนแตะทุกครั้ง** อย่าจำว่าหน้าจออยู่สถานะไหน
- ปุ่มบนพื้น gradient บางทีแตะไม่ติด — **ใช้ `swipe` แทนได้** (เช่นปัดเปลี่ยนหน้า
  onboarding แทนการกด "ถัดไป")
- พิมพ์ลงช่อง: แตะให้ช่อง focus ก่อน แล้วค่อย `text` — ถ้าไม่ focus ตัวอักษรจะหายไปเฉยๆ

## 5. เทียบกับ backend

```bash
docker logs -t --tail 10 posternung-sit-app
```
ยืนยันว่าสิ่งที่เห็นบนจอตรงกับ request จริง (**timestamp เป็น UTC ต้อง +7**)
รายละเอียดการอ่าน log อยู่ใน skill `debug-auth-failure` §2

## 6. เก็บกวาด

หยุดเฉพาะ process ที่**เราเปิดเอง**:
```bash
ps aux | grep "flutter run --flavor sit -d <udid>" | grep -v grep | awk '{print $2}' | xargs -r kill
```

> **exit code 144 = SIGTERM = ปกติ** ไม่ใช่ error อย่ารายงานว่าล้มเหลว

ทิ้ง session ค้างไว้ = รอบหน้าชนตัวเองตาม §1

## กับดักที่เจอมาแล้ว

| อาการ | สาเหตุจริง | ทางแก้ |
|---|---|---|
| log ไฟล์ว่างเปล่าเป็นนาที นึกว่าค้าง | pipe ผ่าน `| tail` → buffer จนจบ | redirect ลงไฟล์ตรงๆ (§3) |
| `Could not delete .../Debug-sit-iphonesimulator ...` | บิลด์สองตัวใช้ `build/ios` พร้อมกัน | §1 — เช็ค process ก่อนเสมอ |
| `Could not resolve package dependencies` แล้วรันใหม่หาย | SPM resolution ชนกันชั่วคราว | ไม่ใช่บั๊กในโค้ด รอให้ว่างแล้วรันใหม่ |
| กด "ถัดไป"/"ข้าม" แล้วหน้าจอไม่ขยับ | hit-test บนพื้น gradient ไม่ติด | swipe แทน (§4) |
| แอปเปิดมาเข้า Home เลยทั้งที่ยังไม่ล็อกอิน | token เก่ายังอยู่ใน secure storage → `_restore()` ยิง `/auth/me` สำเร็จ | ไม่ใช่บั๊ก ถ้าจะเทสต์ล็อกอินใหม่ต้อง sign out ก่อน |
| `timeout 90 flutter ...` ไม่ทำงาน | macOS ไม่มี `timeout` (เป็นของ GNU coreutils) | ใช้ timeout ของ Bash tool แทน |

## 7. Android emulator

**ใช้เมื่อไหร่:** อยากเห็นของจริงโดยไม่ต้องพึ่ง iOS · ทดสอบ **ปุ่ม back ของ Android**
ซึ่ง widget test พิสูจน์ไม่ได้ (`project-gotchas` §5) · หรือ iOS build พังอยู่
(INF-16 — **ไม่ได้บล็อกเส้นทางนี้ ยืนยัน 2026-08-07**)

### 7.1 ต้องมี AVD ก่อน — เครื่องนี้เคยไม่มีเลยสักตัว

`flutter devices` **ไม่แสดง Android อะไรเลย**และไม่บอกว่าทำไม ต้องเช็คเอง:
```bash
SDK=~/Library/Android/sdk
"$SDK/emulator/emulator" -list-avds            # ว่าง = ยังไม่มี AVD
ls "$SDK/system-images"                        # ดูว่ามี image อะไรให้ใช้บ้าง
"$SDK/cmdline-tools/latest/bin/avdmanager" create avd \
  -n posternung_api31 -k "system-images;android-31;google_apis_playstore;arm64-v8a" -d pixel_6
```
`adb`/`emulator` **ไม่อยู่ใน PATH** ต้องเรียกด้วย path เต็มจาก `$SDK` เสมอ
(`flutter doctor` เขียวได้โดยที่ทั้งสองตัวไม่อยู่ใน PATH — มันหาเจอเอง เราไม่เจอ)

### 7.2 บูตด้วย flag ชุดนี้ ไม่ใช่รันเปล่า ๆ

```bash
"$SDK/emulator/emulator" -avd posternung_api31 -no-snapshot-load \
  -gpu host -memory 1536 -cores 2 -no-boot-anim > /tmp/emu.log 2>&1 &
until [ "$("$SDK/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 8; done
```

🔴 **รันเปล่า ๆ แล้วตายเงียบบนเครื่องนี้** — emulator ขอ RAM 5120 MB เจอว่าง 2843 MB
จึงถอยไป software GL แล้ว QEMU ค้างจนถูกฆ่า อาการที่เห็นคือ `adb devices` ว่างตลอด
ส่วนสาเหตุจริงอยู่ใน log เท่านั้น:
```
WARNING | Software GL rendering will be used due to system memory pressure ... (Available Memory: 2843 MB, Required: 5120 MB)
ERROR   | detected a hanging thread 'QEMU2 main loop'. No response for 18139 ms
```
ตัวกินหลักคือ docker stack ของ backend ที่เปิดค้าง — `docker ps` ก่อนถ้าบูตไม่ขึ้นซ้ำ

### 7.3 🔴 baseURL ของ emulator ไม่ใช่ `127.0.0.1`

`apiBaseUrlFor()` (`lib/core/config/api_base_url_resolver.dart`) คืน **LAN IP** สำหรับ `sit`
ซึ่ง **emulator เข้าไม่ถึง** เพราะเน็ตของมันถูก virtualize — host คือ `10.0.2.2` เสมอ

```bash
flutter build apk --flavor sit --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
"$SDK/platform-tools/adb" install -r build/app/outputs/flutter-apk/app-sit-debug.apk
```

⚠️ **`--dart-define` เป็นค่า compile-time** เปลี่ยนทีต้อง**บิลด์ใหม่** ติดตั้ง APK เดิมซ้ำไม่ช่วย
· **อาการเวลาลืม: ค้างที่วงกลมหมุนไม่มี error ไม่มี banner** เพราะ request ไม่ timeout สักที
ดูเหมือนแอปแฮงก์ทั้งที่ตัวแอปปกติ — เจอจริง 2026-08-07

### 7.4 เปิดแอปและกดหน้าจอ

`monkey` **ไม่น่าเชื่อถือ** (คืน `VM exiting with result code -5` แล้วไม่เปิดอะไรเลย)
ใช้ `am start` พร้อมชื่อ activity ที่ resolve มาจริง — **applicationId มี suffix `.sit`
แต่ชื่อคลาสไม่มี** จึงเดาเองไม่ได้:
```bash
ADB="$SDK/platform-tools/adb"
$ADB shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER com.frameshine.posternung.sit | tail -1
$ADB shell am start -W -n com.frameshine.posternung.sit/com.frameshine.posternung.MainActivity
$ADB exec-out screencap -p > /tmp/s.png      # ถ่ายรูปก่อนแตะทุกครั้ง
$ADB shell input tap 940 195                 # 🔴 พิกัดเป็น "pixel" ไม่ใช่ point — ต่างจาก iOS §4
$ADB shell input swipe 800 1200 200 1200 300
$ADB shell input keyevent KEYCODE_BACK       # ← ตัวที่ widget test แทนไม่ได้
```
`am start -W` ขึ้น `Status: timeout` ได้ทั้งที่แอปเปิดสำเร็จ — **ยืนยันด้วย
`Fully drawn` ใน logcat หรือ `dumpsys activity activities | grep ResumedActivity` แทน**

### 7.5 อ่านผลจาก logcat

```bash
$ADB logcat -c                                   # ล้างก่อนเริ่มทุกครั้ง
$ADB logcat -d | grep -iE 'overflow|RenderFlex|FATAL|GoError|nothing to pop|Exception'
```
`logcat -b crash` **ว่างเปล่าได้แม้แอปไม่ทำงาน** (เช่นตอน `monkey` ไม่เปิดอะไรเลย) —
อย่าอ่านว่า "ไม่ crash = เปิดสำเร็จ" ต้องเช็ค `ps -A | grep poster` ด้วย

### 7.6 เก็บกวาด

```bash
$ADB emu kill        # แล้วเช็คซ้ำ — ps aux | grep "[e]mulator -avd"
```
emulator กิน RAM หลาย GB บนเครื่องที่ swap เกือบเต็มอยู่แล้ว **ปิดทุกครั้งที่ verify เสร็จ**

### สิ่งที่ Android แทน iOS ไม่ได้

Apple Sign-In · gesture back (ปัดขอบจอ ไม่ใช่ปุ่ม back) · พฤติกรรม ATS/keychain ·
ทุกอย่างที่ AC เขียนว่า iOS ตรง ๆ — **งานพวกนี้ยังติด INF-16 อยู่จริง**

## เมื่อไหร่ควรอ่านต่อ

- reproduce แล้วเจอ auth error → skill **`debug-auth-failure`**
- สงสัย config ต่อ flavor (project/appId/URL scheme) → skill **`rotate-firebase-environment`**
