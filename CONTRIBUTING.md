# Contributing Guide

## Setup ครั้งแรก (ทำครั้งเดียวต่อเครื่อง)

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional husky commitizen cz-conventional-changelog
npx husky init
cp commit-msg .husky/commit-msg
chmod +x .husky/commit-msg
```

เพิ่มใน `package.json`:
```json
{
  "config": {
    "commitizen": {
      "path": "cz-conventional-changelog"
    }
  }
}
```

## วิธี Commit

**แบบมี wizard ช่วย (แนะนำสำหรับมือใหม่กับ convention นี้):**
```bash
npx git-cz
```

**แบบพิมพ์เอง (ต้องตรง format เป๊ะ ไม่งั้น commit ถูก reject):**
```bash
git commit -m "feat(cart): add reservation countdown timer"
```

## Commit Message Format

```
<type>(<scope>): <subject>
```

| Type | ใช้เมื่อ |
|---|---|
| feat | เพิ่ม feature ใหม่ |
| fix | แก้ bug |
| refactor | ปรับโค้ด behavior เดิม |
| perf | ปรับปรุงประสิทธิภาพ |
| test | เพิ่ม/แก้ test |
| docs | เอกสาร |
| style | format/lint เท่านั้น |
| chore | dependency, config, งานเบื้องหลัง |
| build | build system |
| ci | CI/CD pipeline |
| revert | ย้อน commit |

Scope ต้องตรงกับชื่อ folder ใน `lib/features/<scope>/`

## Branch Naming

```
feature/<scope>-<short-description>
fix/<scope>-<short-description>
chore/<short-description>
```

## Pull Request

ทุก PR ต้องมี description ตาม template ใน `.github/PULL_REQUEST_TEMPLATE.md`
(What / Why / How to test / Screenshots)

รายละเอียดเต็มดูที่ `CLAUDE.md`
