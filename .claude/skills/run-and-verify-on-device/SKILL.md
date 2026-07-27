---
name: run-and-verify-on-device
description: >
  วิธีรัน PosterNung บน iOS simulator หรือเครื่องจริงเพื่อ verify งานด้วยตาตัวเอง —
  กันบิลด์ชนกับ session ที่ผู้ใช้เปิดค้างไว้, อ่าน log ให้ออก, กดหน้าจอผ่าน simulator
  tool, แล้วเก็บกวาด. ใช้ skill นี้เมื่อจะ reproduce บั๊กบนอุปกรณ์จริง, ต้องพิสูจน์ว่า
  งานที่แก้ไปใช้ได้จริงไม่ใช่แค่ unit test เขียว, ผู้ใช้ขอให้ "ลองบนเครื่อง"/"รันดูหน่อย",
  หรือเจอ Xcode build failed / concurrent builds / build ค้างไม่มี output
  — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
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

## เมื่อไหร่ควรอ่านต่อ

- reproduce แล้วเจอ auth error → skill **`debug-auth-failure`**
- สงสัย config ต่อ flavor (project/appId/URL scheme) → skill **`rotate-firebase-environment`**
