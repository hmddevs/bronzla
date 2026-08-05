#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { BronzlaBackendStack } from "../lib/bronzla-backend-stack";

const app = new cdk.App();

// com.hmdcorp.bronzla lives in exactly one place: CDK context, read once
// here and threaded into the stack as a prop, then into the auth Lambda as
// an environment variable. Never re-declared as a literal elsewhere.
const bundleId = app.node.tryGetContext("bronzla:bundleId") as string | undefined;
if (!bundleId) {
  throw new Error("Missing required CDK context value 'bronzla:bundleId'");
}

new BronzlaBackendStack(app, "BronzlaBackendStack-dev", {
  bundleId,
  stageName: "dev",
});
