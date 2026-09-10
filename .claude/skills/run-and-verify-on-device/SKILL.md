---
name: run-and-verify-on-device
description: >
  วิธีรัน PosterNung บน iOS simulator, Android emulator หรือเครื่องจริงเพื่อ verify งาน
  ด้วยตาตัวเอง — กันบิลด์ชนกับ session ที่ผู้ใช้เปิดค้างไว้, สร้าง/บูต AVD, อ่าน log ให้ออก,
  กดหน้าจอ, แล้วเก็บกวาด. ใช้ skill นี้เมื่อจะ reproduce บั๊กบนอุปกรณ์จริง, ต้องพิสูจน์ว่า
  งานที่แก้ไปใช้ได้จริงไม่ใช่แค่ unit test เขียว, ต้องทดสอบปุ่ม back ของ Android,
  ผู้ใช้ขอให้ "ลองบนเครื่อง"/"รันดูหน่อย", หรือเจอ Xcode build failed / concurrent builds /
  emulator บูตไม่ขึ้น / build ค้างไม่มี output / **`ADB exited with exit code 1` หรือ
  `INSTALL_FAILED_USER_RESTRICTED` ตอนลงเครื่อง Xiaomi-MIUI** — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
  · 🔴 ใช้เมื่อผู้ใช้บอกว่า "build ไม่ได้" ด้วย เพราะข้อความของขั้น *ติดตั้ง* อ่านเหมือน build พัง (§8)
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

🔴 **tool ตัวนี้ไม่มีในทุกเซสชัน — เช็คก่อนวางแผน** ถ้าไม่มี ยังทำได้ด้วย `xcrun simctl io …
screenshot` + `cliclick` แต่ต้อง calibrate พิกัดเอง และมีกับดักเรื่อง "คลิกลงหน้าต่างผิดเครื่อง"
ที่ไม่มี error ให้เห็นเลย → **วิธีและค่าที่ calibrate ได้อยู่ในสกิล `project-gotchas` §8**

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
| `Could not resolve package dependencies` แล้ว **รันใหม่กี่รอบก็เหมือนเดิม** และข้อความหลัง `Couldn’t fetch updates from remote repositories:` **ว่างเปล่า** | `build/ios/SourcePackages` ค้างเก่า — เจอจริง 2026-08-08 ว่ามันเก่ากว่าโค้ด 10 วันและมี `firebase_auth` ค้าง **2 เวอร์ชัน** ทั้งที่ `pubspec` resolve ตัวเดียว · cache ที่ปนกันแบบนี้ทำให้ SPM **กลืนสาเหตุจริงจนพิมพ์ออกมาเป็นบรรทัดว่าง** | `rm -rf build/ios/SourcePackages` (gitignored · สร้างใหม่ได้ แต่โหลดใหม่ทั้งหมด) → **รันอีกรอบถึงจะเห็นข้อความจริง** · 🔴 ลบแล้วต้องมีเน็ตในบริบทที่ `xcodebuild` ใช้ ไม่ใช่แค่ `curl` ผ่าน |
| SPM ฟ้อง `Failed to connect to github.com port 443 after ~40 ms` ทั้งที่ `curl https://github.com` = 200 และ `git clone` จาก shell สำเร็จ | **บริบทของ process ไม่ใช่ปลายทาง** — git ที่ `xcodebuild` spawn ต่อไม่ได้ ส่วน shell ต่อได้ (เจอจริงตอนรันจาก agent sandbox 2026-08-08) | รันจาก **terminal ของเจ้าของเครื่อง** ไม่ใช่จาก agent · 🔴 อย่าสรุปว่าเน็ตเสียจากการที่ `curl` ผ่าน — คนละ process คนละเส้น |
| กด "ถัดไป"/"ข้าม" แล้วหน้าจอไม่ขยับ | hit-test บนพื้น gradient ไม่ติด | swipe แทน (§4) |
| แอปเปิดมาเข้า Home เลยทั้งที่ยังไม่ล็อกอิน | token เก่ายังอยู่ใน secure storage → `_restore()` ยิง `/auth/me` สำเร็จ | ไม่ใช่บั๊ก ถ้าจะเทสต์ล็อกอินใหม่ต้อง sign out ก่อน |
| `timeout 90 flutter ...` ไม่ทำงาน | macOS ไม่มี `timeout` (เป็นของ GNU coreutils) | ใช้ timeout ของ Bash tool แทน |
| `flutter run` จบด้วย **`Error: ADB exited with exit code 1`** + `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` | 🔴 **ไม่ใช่ build พัง — build สำเร็จไปแล้ว** (`✓ Built app-sit-debug.apk` ขึ้นก่อนหน้า) ที่ล้มคือขั้น *ติดตั้ง* · MIUI เด้ง dialog ขออนุญาตทุกครั้งที่ `adb install` ถ้าจอล็อกอยู่ตอนนั้นมันยกเลิกเอง ⇒ คำว่า "canceled by user" แปลว่า **ระบบยกเลิกแทน** ไม่ได้แปลว่าคนกดยกเลิก | §8 |
| `adb shell settings put ...` ตอบ `SecurityException: requires android.permission.WRITE_SECURE_SETTINGS` **ทั้งที่ `dumpsys package com.android.shell` เขียนว่า `WRITE_SECURE_SETTINGS: granted=true`** | 🔴 **MIUI ซ้อนด่านของตัวเองทับ permission ของ AOSP** — permission ถูก grant จริงแต่ MIUI ปฏิเสธการเขียนอยู่ดีเมื่อ *USB debugging (Security settings)* ปิด | §8 · 🔴 **ห้ามใช้ `dumpsys` เป็นหลักฐานว่าเขียน secure settings ได้บนเครื่อง Xiaomi** — มันตอบ granted=true ทั้งที่เขียนไม่ได้ |

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

## 8. Android เครื่องจริงที่เป็น Xiaomi / MIUI — ด่านที่ไม่เหมือนเครื่องอื่น

‹บันทึก 2026-09-10 · เจอจริงบน **Redmi Note 9 (`M2003J15SC`) · MIUI `V13.0.2.0.SJOMIXM` · Android 12**›

**อาการที่ผู้ใช้เห็น** คือข้อความที่อ่านแล้วเข้าใจว่า build พัง:

```
Error: ADB exited with exit code 1
adb: failed to install .../app-sit-debug.apk:
  Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]
Error launching application on M2003J15SC.
```

🔴 **build ไม่ได้พัง** — บรรทัด `✓ Built build/app/outputs/flutter-apk/app-sit-debug.apk`
ขึ้นไปก่อนหน้านั้นแล้ว · รอบที่เจอจริง ตรวจครบทุกเส้นแล้วเขียวหมด:
`flutter build apk --flavor sit` · `flutter build ios --flavor sit` (ทั้ง device และ
`--simulator`) · `analyze --fatal-infos` · `flutter test` · `dart format` — **exit 0 ทั้งหมด**

**อย่าเริ่มไล่จากโค้ดหรือ Gradle** ให้แยกสองขั้นออกจากกันก่อนเสมอ:

```bash
flutter build apk --flavor sit --debug          # ขั้น build — ถ้าผ่าน ปัญหาไม่ได้อยู่ที่นี่
adb install -r -t build/app/outputs/flutter-apk/app-sit-debug.apk   # ขั้น install
```

### 8.1 ทำไมมันล้มเป็นระยะ ไม่ใช่ทุกครั้ง

MIUI เด้ง dialog ขออนุญาตติดตั้งบนหน้าจอมือถือทุกครั้งที่ `adb install`
**ถ้าจอดับ/ล็อกอยู่ตอนนั้น dialog ถูกยกเลิกอัตโนมัติ** แล้วคืนค่า `INSTALL_FAILED_USER_RESTRICTED`

ตัวเร่งที่ทำให้เกิดซ้ำ ๆ คือค่านี้:

```bash
adb shell settings get global stay_on_while_plugged_in    # 0 = จอดับเองแม้เสียบสายอยู่
```

Gradle build กิน **13–70 วินาที** — นานพอให้จอดับไปแล้วก่อน `adb install` จะยิง
⇒ **build นานเท่าไร โอกาสตกยิ่งสูง** และมันดูเหมือนสุ่มทั้งที่ไม่สุ่ม

รอบที่เจอจริง: สั่ง `adb install` ซ้ำตอนจอเปิดอยู่ **โดยไม่ได้แก้ค่าอะไรบนเครื่องเลย →
`Success` ทันที** — นั่นคือหลักฐานว่าไม่ใช่ปัญหาของ APK

### 8.2 🔴 แก้ผ่าน adb ไม่ได้ และ `dumpsys` จะโกหกคุณ

```bash
adb shell settings put global stay_on_while_plugged_in 7
# → java.lang.SecurityException: Permission denial:
#   writing to settings requires:android.permission.WRITE_SECURE_SETTINGS
```

แต่:

```bash
adb shell dumpsys package com.android.shell | grep WRITE_SECURE_SETTINGS
# → android.permission.WRITE_SECURE_SETTINGS: granted=true
```

**สองอย่างนี้ขัดกันและทั้งคู่พูดจริง** — permission ถูก grant ในระดับ AOSP จริง แต่ MIUI
มีด่านของตัวเองซ้อนอยู่บน `SettingsProvider` ซึ่งผูกกับตัวเลือก
*USB debugging (Security settings)* ที่ปิดอยู่

🔴 **บทเรียนที่ใช้ได้กว้างกว่าเคสนี้: บนเครื่อง Xiaomi ห้ามใช้ `dumpsys` ยืนยันว่า adb
ทำอะไรได้** — ต้องลองทำจริงแล้วดูผล การอ่านสถานะ permission ให้คำตอบที่ผิด

### 8.3 ต้องกดบนมือถือ — เปิดหน้าให้เร็วด้วย intent

```bash
adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS
```

ในหน้านั้นเปิดสามอย่าง (ถ้ายังไม่เห็นเมนู: **การตั้งค่า → เกี่ยวกับโทรศัพท์ → กด MIUI
version 7 ครั้ง**):

| ตัวเลือก | แก้อะไร | ต้องมี Mi account ไหม |
|---|---|---|
| **เปิดหน้าจอค้างไว้** (Stay awake) | ตัวเร่งของ §8.1 — จอไม่ดับระหว่างบิลด์ | ไม่ต้อง |
| **ติดตั้งผ่าน USB** (Install via USB) | ทำให้ `adb install` ไม่ต้องรอคนกด | ต้อง |
| **USB debugging (Security settings)** | ปลดด่าน §8.2 · หลังเปิดแล้ว `adb shell settings put` ถึงจะทำงาน | ต้อง |

เปิด *USB debugging (Security settings)* แล้วค่อยตั้งค่าที่เหลือด้วย adb ได้:

```bash
adb shell settings put global stay_on_while_plugged_in 7   # 7 = AC + USB + wireless · 0 = ปิด
```

### 8.4 ยืนยันว่าติดตั้งและเปิดได้จริง (ไม่ต้องเชื่อ `flutter run`)

```bash
adb shell pm list packages | grep posternung        # → package:com.frameshine.posternung.sit
ACT=$(adb shell cmd package resolve-activity --brief \
        -c android.intent.category.LAUNCHER com.frameshine.posternung.sit | tail -1)
adb shell am start -n "$ACT"
adb shell pidof com.frameshine.posternung.sit       # มี pid = แอปรันอยู่จริง
```

### 8.5 🔴 ทำไมเรื่องนี้สำคัญกับงานวัดผล

`INF-40` ขั้น 2 และขั้น 6 ต้องรัน **cold start 20 รอบติดกัน** บนเครื่องนี้
ถ้าจอดับกลางชุด รอบนั้นจะตกด้วยเหตุผลที่ **ไม่เกี่ยวกับสิ่งที่กำลังวัด** และแยกจาก
"ตกเพราะ gate ตัดสินผิด" ไม่ได้เลยจาก log ⇒ **ต้องตั้ง §8.3 ให้ครบก่อนเริ่มนับ ไม่ใช่ระหว่างนับ**

⚠️ และ **ห้าม `pm clear` ตลอดงานวัด** — รอบก่อนล้างไปแล้วสร้าง session ใหม่ไม่ได้เลย
ทำให้ 4 เคสวัดไม่ได้ทั้งหมด (`project-gotchas` §8)

## เมื่อไหร่ควรอ่านต่อ

- reproduce แล้วเจอ auth error → skill **`debug-auth-failure`**
- สงสัย config ต่อ flavor (project/appId/URL scheme) → skill **`rotate-firebase-environment`**
