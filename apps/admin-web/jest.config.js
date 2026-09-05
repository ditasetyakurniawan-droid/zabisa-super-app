module.exports = {
  roots: ["<rootDir>/lib"],
  testMatch: ["**/*.test.js"],
  collectCoverageFrom: ["lib/backend-url.js"],
  coverageDirectory: "coverage",
  coverageReporters: ["text", "lcov"],
};
