import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["test/**/*.test.ts"],
    env: {
      SESSIONS_TABLE_NAME: "BronzlaSessions-test",
      SCORES_TABLE_NAME: "BronzlaScores-test",
      USERS_TABLE_NAME: "BronzlaUsers-test",
      LEADERBOARD_GSI_NAME: "LeaderboardByScope",
      SESSIONS_BY_APPLE_SUB_GSI_NAME: "SessionsByAppleSub",
      APPLE_BUNDLE_ID: "com.hmdcorp.bronzla",
    },
  },
});
