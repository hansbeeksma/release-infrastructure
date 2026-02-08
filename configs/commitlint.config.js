// Conventional Commit Lint Configuration
// Shared config from hansbeeksma/release-infrastructure
//
// Install in project:
//   npm install -D @commitlint/cli @commitlint/config-conventional
//   Copy this file to project root
//
// CI usage:
//   npx commitlint --from $BASE_SHA

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'refactor',
        'docs',
        'test',
        'chore',
        'perf',
        'ci',
        'security',
      ],
    ],
    'header-max-length': [1, 'always', 72],
    'subject-full-stop': [2, 'never', '.'],
    'subject-case': [1, 'always', 'lower-case'],
    'body-leading-blank': [2, 'always'],
    'footer-leading-blank': [2, 'always'],
  },
}
