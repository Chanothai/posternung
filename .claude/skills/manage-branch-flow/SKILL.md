---
name: manage-branch-flow
description: >
  ขั้นตอนเดิน branch ของ PosterNung ตามโมเดล main/develop — แตก branch จากตัวไหน,
  PR เข้าตัวไหน, กดปุ่ม merge แบบไหนไม่ให้ ancestry ขาด, ทำ release develop→main,
  และทำ hotfix แบบไม่ลากงานที่ยังไม่ปล่อยขึ้นไปด้วย. ใช้ skill นี้เมื่อจะเริ่มงานใหม่แล้ว
  ไม่แน่ใจว่าต้องแตกจากไหน, จะเปิด PR, จะ merge, PR ขึ้น conflict ทั้งที่ไม่ได้แก้ไฟล์เดียวกัน,
  จะเตรียม release ขึ้น store, มีบั๊ก production ต้องแก้ด่วน, หรือถามว่า branch ไหนคือ
  ตัวจริง — ใช้แม้ผู้ใช้จะไม่พูดคำว่า skill
---

# เดิน branch ตามโมเดล main/develop (PosterNung)

ไฟล์นี้เก็บ **ลำดับลงมือ + กับดักที่เจอมาแล้วจริง** เท่านั้น

**ตารางว่า branch ไหนแตกจากไหน / merge ด้วยวิธีไหน อยู่ที่ `docs/git-workflow.md` หัวข้อ
`## Branch Model`** — เปิดอ่านตรงนั้นถ้ายังไม่รู้ ที่นี่ไม่ทวนซ้ำ เช่นเดียวกับ commit message
format, branch naming และข้อห้าม force-push/rebase

จำแค่หลักเดียวก็พอ: **`develop` คือ base ของงานปกติ ส่วน `main` คือสิ่งที่ (จะ) อยู่บน store**
— ห้ามเอางานที่ยังไม่ปล่อยไปกองบน `main`

## 1. เริ่มงานใหม่

```bash
git fetch origin
git checkout -b feature/<scope>-<desc> origin/develop
```

**`origin/develop` ไม่ใช่ `develop`** — branch local อาจค้างอยู่หลายวัน แตกจาก remote ref
ตรงๆ ไม่ต้อง checkout develop มา pull ก่อน

เปิด PR ต้องระบุ base ทุกครั้ง:
```bash
gh pr create --base develop --title "..." --body "..."
```

> ⚠️ **`--base` ห้ามลืมเด็ดขาด** — default branch ของ repo ยังตั้งเป็น `main` ไว้ตั้งใจ
> (repo เป็น public อยากให้คนเข้ามาเห็น `main` ก่อน) แปลว่าลืม `--base` เมื่อไหร่ PR จะยิงเข้า
> `main` **เงียบๆ ไม่มี error ไม่มีคำเตือน** ตรงนี้ไม่มีระบบกันให้ มีแต่วินัย
> ```bash
> gh pr view <n> --json baseRefName --jq .baseRefName   # ต้องได้ develop
> ```
> เปิด PR จากหน้าเว็บก็เหมือนกัน — ช่อง base จะขึ้น `main` มาให้ ต้องเปลี่ยนเอง

## 2. ทำ branch ให้ทัน develop

```bash
git fetch origin
git merge origin/develop
```

**merge เข้ามา ห้าม rebase** — branch push ขึ้น origin ไปแล้ว rebase = rewrite pushed
history ซึ่ง `docs/git-workflow.md` ห้ามไว้ถ้าไม่ถามก่อน

อยากรู้ว่าจะชนตรงไหนก่อนลงมือจริง (git 2.33 ในเครื่องนี้ใช้ form เก่า `--write-tree` ไม่มี):
```bash
git merge-tree $(git merge-base HEAD origin/develop) HEAD origin/develop | grep -c '^<<<<<<<'
```
ได้ `0` = merge ได้สะอาด ไม่ต้องแตะ working tree เลย

## 3. Release — `develop` → `main`

ทำก่อนเปิด PR release:

```bash
git fetch origin
git log origin/main..origin/develop --oneline   # มีอะไรจะปล่อยบ้าง
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib/ test/
flutter analyze --fatal-infos
flutter test
gh workflow run ci.yml --ref develop            # trigger อัตโนมัติยังเสีย ต้องสั่งเอง
```

แล้ว `gh pr create --base main --head develop`

> ⚠️ **ตอนกด merge ต้องเลือก "Create a merge commit" ห้ามแตะ "Squash and merge"**
> squash จะสร้าง commit ใหม่บน `main` ที่ `develop` ไม่รู้จัก → รอบหน้า git มองว่าทั้งสองฝั่ง
> แก้บรรทัดเดียวกันแล้วชน ทั้งที่เนื้อหาเหมือนกันเป๊ะ **แล้ว `develop` จะชนไปตลอด** ไม่หายเอง
> ตรวจหลัง merge: `git cat-file -p origin/main | grep -c '^parent'` ต้องได้ **2** ไม่ใช่ 1

`main` เขียว **ไม่ได้แปลว่าส่ง store ได้** — release build ยังเซ็นด้วย debug keystore
(`docs/phone-auth-setup.md`), `pubspec.yaml` ยังเป็น `1.0.0+1`, ยังไม่มี tag/fastlane
รอบนี้คุมแค่ branch ยังไม่มี release pipeline

## 4. Hotfix — บั๊กบน production

แตกจาก `main` ไม่ใช่ `develop` เพราะ `develop` มีงานที่ยังไม่ผ่านการปล่อยค้างอยู่:

```bash
git fetch origin
git checkout -b hotfix/<scope>-<desc> origin/main
# แก้ + test
gh pr create --base main
```

**merge เข้า `main` แล้ว back-merge กลับ `develop` ทันที ห้ามค้างข้ามวัน** — `develop` มี branch
protection ต้องผ่าน PR ห้าม push ตรง:
```bash
git fetch origin
git checkout -b chore/backmerge-<hotfix-name> origin/develop
git merge origin/main
git push -u origin chore/backmerge-<hotfix-name>
gh pr create --base develop --title "chore: back-merge <hotfix-name> into develop"
```
ตอน merge PR นี้ **กด "Create a merge commit"** เหมือน release — squash จะทำให้ ancestry ขาดอีกจุด

ลืมขั้นนี้ = release รอบหน้าจะ **ลบ hotfix ทิ้ง** เพราะ `develop` ยังถือโค้ดเวอร์ชันก่อนแก้

## กับดักที่เจอมาแล้ว

| อาการ | สาเหตุจริง | ทางแก้ |
|---|---|---|
| PR ชนทั้งที่ไม่ได้แก้ไฟล์เดียวกับใคร | มีคน squash งานที่ branch เราถืออยู่แล้วเข้า base → SHA คนละตัวแต่เนื้อหาเดียวกัน (เกิดกับ PR #10: `92c3130`/`3afc09d` บน `main` เป็น single-parent squash ส่วน branch ถือ `b4ff3f2`+`a2277e7`) | §3 — `develop→main` ต้อง merge commit เท่านั้น ที่ชนไปแล้วแก้ด้วย `git merge` + เลือกฝั่งเอง |
| PR ไปโผล่ base `main` ทั้งที่ตั้งใจเข้า `develop` | `gh pr create` ไม่ใส่ `--base` แล้วมันใช้ default branch ของ repo | §1 — ใส่ `--base` เสมอ แล้ว `gh pr view --json baseRefName` ยืนยัน |
| ancestry งงว่างานไหนอยู่ PR ไหน | ใช้ branch เดิมซ้ำข้าม PR (`feature/design-tokens-and-assets` = ทั้ง #8 และ #9, `feature/onboarding-authenticate-screen` = ทั้ง #2 และ #3) + repo ตั้ง `deleteBranchOnMerge: false` | 1 branch ต่อ 1 PR แล้วลบเองหลัง merge |
| push เข้า branch แล้ว CI ไม่รัน | `on.push.branches` มีแค่ `main` กับ `develop` — feature branch ต้องอาศัย `pull_request` trigger | เปิด PR ก่อน หรือ `gh workflow run ci.yml --ref <branch>` |
| `gh workflow run` แล้วก็ยังไม่มี check บน PR | trigger อัตโนมัติของ repo เสียระดับบัญชี (`check-suites` คืน `total_count: 0` ตั้งแต่ commit ที่มีมาก่อนหน้า) ไม่ใช่ YAML พัง | สั่งเองทุกครั้ง แล้วอ่านผลจาก `gh run view` ไม่ใช่จากหน้า PR |
| back-merge hotfix แล้วเจอ conflict เต็มไปหมด | ปล่อยให้ `main` นำหน้า `develop` ข้ามหลายวัน | §4 — back-merge ทันทีในวันเดียวกัน |

## เมื่อไหร่ควรอ่านต่อ

- format ของ commit message / ข้อห้าม push → **`docs/git-workflow.md`**
- จะลงมือเขียน feature ที่แตก branch ไปแล้ว → skill **`add-feature-slice`**
- ต้อง verify บนอุปกรณ์จริงก่อนเปิด PR release → skill **`run-and-verify-on-device`**
