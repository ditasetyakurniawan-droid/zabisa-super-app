module.exports = {
  preset: '@react-native/jest-preset',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts', '**/*.test.tsx'],
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.test.{ts,tsx}',
    '!src/types/**',
    '!src/config/runtime.ts',
  ],
  coverageDirectory: 'coverage',
};
