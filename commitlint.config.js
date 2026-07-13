// commitlint.config.js
// บังคับ format ของ commit message ตาม Conventional Commits
// ติดตั้ง: npm install --save-dev @commitlint/cli @commitlint/config-conventional

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'refactor',
        'perf',
        'test',
        'docs',
        'style',
        'chore',
        'build',
        'ci',
        'revert',
      ],
    ],
    'scope-empty': [1, 'never'], // แนะนำให้ใส่ scope (warning ไม่ error)
    'subject-case': [2, 'always', 'lower-case'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
  },
};
