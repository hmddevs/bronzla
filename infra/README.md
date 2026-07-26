# Bronzla backend (AWS CDK)

Backend for the Bronzla iOS app: Sign in with Apple, a score, and a global
leaderboard. Single CDK stack, `BronzlaBackendStack-dev`, deployed nowhere
yet (see "Deployment" below).

## What this builds

- Three DynamoDB tables (`PAY_PER_REQUEST`): `BronzlaUsers-dev`,
  `BronzlaSessions-dev` (with a TTL on `expiresAt` and a GSI on `appleSub`),
  `BronzlaScores-dev` (with a leaderboard GSI keyed by a constant scope and a
  score-encoding sort key, see the comments in `lib/bronzla-backend-stack.ts`
  and `lambda/shared/dynamo.ts`).
- Four Lambda functions (Node.js 20.x, TypeScript, bundled with esbuild via
  `aws-lambda-nodejs`) behind an API Gateway HTTP API:
  - `POST /auth/apple` — verifies an Apple identity token, upserts the user,
    issues a session token.
  - `PUT /score` — authenticated, upserts the caller's score.
  - `GET /leaderboard` — authenticated, returns the top N scores
    (`displayName` and `score` only, never `appleSub`).
  - `DELETE /account` — authenticated, deletes the caller's user, score and
    all sessions.
- Each Lambda has least-privilege IAM: only the DynamoDB actions and
  tables/GSIs it actually touches.

## Prerequisites

- Node.js 20.x and npm.
- No AWS credentials are required for `synth` or the test suite; both run
  entirely offline.

## Install

```
cd infra
npm install
```

## Synth (no deployment)

```
npx cdk synth
```

This renders the CloudFormation template into `cdk.out/` and validates the
CDK app. It does not touch AWS in any way.

## Tests

```
npm test
```

Runs the vitest suite: Apple identity token verification (valid, expired,
wrong-audience, wrong-signing-key, malformed tokens, all against a locally
generated test keypair with a mocked JWKS fetch — no network calls to Apple),
the leaderboard score-sort-key encoding, and the `PUT /score`,
`GET /leaderboard` and `DELETE /account` handlers against a mocked DynamoDB
client (`aws-sdk-client-mock`), including the account-delete fan-out across a
paginated session query and its atomic transaction.

Table, GSI and bundle-id names the handlers read from `process.env` at
import time are set in `vitest.config.ts` (`test.env`), applied before any
test module is imported — setting `process.env` inside a test file itself is
too late, since ES module imports are hoisted ahead of a file's own
top-level statements.

## Configuration

The Apple bundle identifier (`com.hmdcorp.bronzla`) is set in exactly one
place: the `bronzla:bundleId` key in `cdk.json`'s `context` block. `bin/
bronzla-backend.ts` reads it once and passes it into the stack as a prop,
which threads it into the `auth-apple` Lambda's `APPLE_BUNDLE_ID` environment
variable. Do not hardcode the bundle ID anywhere else.

## Deployment — NOT YET RUN

Neither `cdk bootstrap` nor `cdk deploy` has been run against any AWS
account. This stack has not touched real AWS credentials or infrastructure.

Bronzla is a new product; the AWS credentials available in this development
environment belong to a different, unrelated product's shared account.
Deploying Bronzla's infrastructure into that account (or any account) is an
account-ownership decision for a human to make explicitly before any deploy
is attempted — it is not something to infer or default into.

Once a target AWS account and region have been confirmed:

```
# One-off per account/region, sets up the CDK bootstrap stack (S3 bucket,
# ECR repo, IAM roles) that cdk deploy depends on.
npx cdk bootstrap aws://<ACCOUNT_ID>/<REGION> --profile <PROFILE_NAME>

# Deploys BronzlaBackendStack-dev to that account/region.
npx cdk deploy --profile <PROFILE_NAME>
```

Both commands should be run with an explicit `--profile` (or equivalent
credential scoping) rather than whatever credentials happen to be active in
the shell, to avoid an accidental deploy into the wrong account.
