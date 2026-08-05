import * as cdk from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as apigwv2 from "aws-cdk-lib/aws-apigatewayv2";
import { HttpLambdaIntegration } from "aws-cdk-lib/aws-apigatewayv2-integrations";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as path from "node:path";

export interface BronzlaBackendStackProps extends cdk.StackProps {
  /** Apple app bundle identifier, e.g. com.hmdcorp.bronzla. Lives in exactly one place: CDK context. */
  readonly bundleId: string;
  /** Deployment stage suffix baked into resource names, e.g. "dev". */
  readonly stageName: string;
}

const LEADERBOARD_GSI_NAME = "LeaderboardByScope";
const SESSIONS_BY_APPLE_SUB_GSI_NAME = "SessionsByAppleSub";

export class BronzlaBackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: BronzlaBackendStackProps) {
    super(scope, id, props);

    const { bundleId, stageName } = props;

    // --- DynamoDB tables ---------------------------------------------------

    const usersTable = new dynamodb.Table(this, "UsersTable", {
      tableName: `BronzlaUsers-${stageName}`,
      partitionKey: { name: "appleSub", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const sessionsTable = new dynamodb.Table(this, "SessionsTable", {
      tableName: `BronzlaSessions-${stageName}`,
      // SHA-256 of the session token, never the token itself. The raw value
      // is returned to the client once at sign-in and is not persisted, so
      // read access to this table yields nothing replayable. See
      // hashSessionToken in lambda/shared/session-auth.ts.
      partitionKey: { name: "sessionTokenHash", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: "expiresAt",
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // GSI over appleSub so DELETE /account can find every session belonging
    // to a user directly. A scan-and-filter alternative would read the
    // entire sessions table on every account deletion and get slower and
    // more expensive as the user base grows; the GSI keeps that lookup an
    // O(sessions-for-this-user) query regardless of total table size.
    // KEYS_ONLY is sufficient: the only field the delete-account handler
    // needs from a matched item is the base table's partition key
    // (sessionTokenHash), which every GSI projection includes automatically.
    sessionsTable.addGlobalSecondaryIndex({
      indexName: SESSIONS_BY_APPLE_SUB_GSI_NAME,
      partitionKey: { name: "appleSub", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.KEYS_ONLY,
    });

    const scoresTable = new dynamodb.Table(this, "ScoresTable", {
      tableName: `BronzlaScores-${stageName}`,
      partitionKey: { name: "appleSub", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Leaderboard GSI: a constant partition key ("global") fans all scores
    // into one logical partition, with a sort key that encodes score so a
    // single ascending query returns the top scores first with no full
    // table scan. The sort key is `MAX_SCORE - score`, zero-padded to a
    // fixed width (see lambda/shared/dynamo.ts): plain numeric score would
    // sort ascending by default, forcing every caller to remember
    // ScanIndexForward: false, and DynamoDB sort keys compare
    // lexicographically, so numbers must be zero-padded to sort correctly
    // as strings. Inverting first means a plain ascending query already
    // yields highest-score-first. ALL projection is required (not
    // KEYS_ONLY) because the leaderboard response needs displayName and
    // score, which live only on the base table item.
    scoresTable.addGlobalSecondaryIndex({
      indexName: LEADERBOARD_GSI_NAME,
      partitionKey: { name: "leaderboardScope", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "scoreSortKey", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // --- Lambda functions ---------------------------------------------------

    const commonBundling: NonNullable<import("aws-cdk-lib/aws-lambda-nodejs").NodejsFunctionProps["bundling"]> = {
      minify: true,
      sourceMap: true,
      target: "node20",
    };

    const authAppleFn = new NodejsFunction(this, "AuthAppleFunction", {
      functionName: `bronzla-auth-apple-${stageName}`,
      entry: path.join(__dirname, "..", "lambda", "auth-apple.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      timeout: cdk.Duration.seconds(10),
      memorySize: 256,
      bundling: commonBundling,
      environment: {
        USERS_TABLE_NAME: usersTable.tableName,
        SESSIONS_TABLE_NAME: sessionsTable.tableName,
        APPLE_BUNDLE_ID: bundleId,
      },
    });
    // Auth handler: looks up and upserts a single Users row by primary key
    // (GetItem + PutItem only, never Query/Scan), writes Sessions. No access
    // to Scores.
    authAppleFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem", "dynamodb:PutItem"],
        resources: [usersTable.tableArn],
      })
    );
    // Only ever PutItem's a session row on successful auth, never updates
    // or deletes one, so the grant is scoped to that single action.
    authAppleFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:PutItem"],
        resources: [sessionsTable.tableArn],
      })
    );

    const signoutFn = new NodejsFunction(this, "SignoutFunction", {
      functionName: `bronzla-signout-${stageName}`,
      entry: path.join(__dirname, "..", "lambda", "signout.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      timeout: cdk.Duration.seconds(10),
      memorySize: 256,
      bundling: commonBundling,
      environment: {
        SESSIONS_TABLE_NAME: sessionsTable.tableName,
        USERS_TABLE_NAME: usersTable.tableName,
      },
    });
    // Signout handler, least privilege per table:
    // - Users: GetItem only, for the shared session-auth existence check. It
    //   never reads or writes anything else about the user.
    // - Sessions: GetItem (session-auth) plus DeleteItem for the one row it
    //   revokes. No Query, so it cannot enumerate anyone's sessions, and no
    //   PutItem/UpdateItem, so it cannot mint or extend one.
    // No access at all to the Scores table.
    signoutFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: [usersTable.tableArn],
      })
    );
    signoutFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem", "dynamodb:DeleteItem"],
        resources: [sessionsTable.tableArn],
      })
    );

    const putScoreFn = new NodejsFunction(this, "PutScoreFunction", {
      functionName: `bronzla-put-score-${stageName}`,
      entry: path.join(__dirname, "..", "lambda", "put-score.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      timeout: cdk.Duration.seconds(10),
      memorySize: 256,
      bundling: commonBundling,
      environment: {
        SESSIONS_TABLE_NAME: sessionsTable.tableName,
        SCORES_TABLE_NAME: scoresTable.tableName,
        USERS_TABLE_NAME: usersTable.tableName,
      },
    });
    // Score handler: resolves the bearer token (GetItem on Sessions only,
    // never Query/Scan), the shared session-auth existence check needs
    // GetItem on Users, and it writes Scores only.
    putScoreFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: [sessionsTable.tableArn, usersTable.tableArn],
      })
    );
    // Only ever PutItem's a score row on submission, never updates or
    // deletes one, so the grant is scoped to that single action.
    putScoreFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:PutItem"],
        resources: [scoresTable.tableArn],
      })
    );

    const getLeaderboardFn = new NodejsFunction(this, "GetLeaderboardFunction", {
      functionName: `bronzla-get-leaderboard-${stageName}`,
      entry: path.join(__dirname, "..", "lambda", "get-leaderboard.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      timeout: cdk.Duration.seconds(10),
      memorySize: 256,
      bundling: commonBundling,
      environment: {
        SESSIONS_TABLE_NAME: sessionsTable.tableName,
        SCORES_TABLE_NAME: scoresTable.tableName,
        USERS_TABLE_NAME: usersTable.tableName,
        LEADERBOARD_GSI_NAME,
      },
    });
    // Leaderboard handler: resolves the bearer token (GetItem on Sessions
    // only), the shared session-auth existence check needs GetItem on
    // Users, and it reads the leaderboard via Query on the scores table's
    // leaderboard GSI only, not full table access.
    getLeaderboardFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem"],
        resources: [sessionsTable.tableArn, usersTable.tableArn],
      })
    );
    getLeaderboardFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:Query"],
        resources: [`${scoresTable.tableArn}/index/${LEADERBOARD_GSI_NAME}`],
      })
    );

    const deleteAccountFn = new NodejsFunction(this, "DeleteAccountFunction", {
      functionName: `bronzla-delete-account-${stageName}`,
      entry: path.join(__dirname, "..", "lambda", "delete-account.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_20_X,
      architecture: lambda.Architecture.ARM_64,
      timeout: cdk.Duration.seconds(15),
      memorySize: 256,
      bundling: commonBundling,
      environment: {
        USERS_TABLE_NAME: usersTable.tableName,
        SESSIONS_TABLE_NAME: sessionsTable.tableName,
        SCORES_TABLE_NAME: scoresTable.tableName,
        SESSIONS_BY_APPLE_SUB_GSI_NAME,
      },
    });
    // Delete-account handler, least privilege per table:
    // - Users: GetItem (session-auth existence check) + DeleteItem. Never
    //   written after creation by this handler, so no PutItem/UpdateItem.
    // - Scores: DeleteItem only. This handler never reads a score.
    // - Sessions: GetItem on the base table (session-auth), Query scoped to
    //   the SessionsByAppleSub GSI only (never table-wide Scan), and
    //   DeleteItem to remove every session batch.
    deleteAccountFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem", "dynamodb:DeleteItem"],
        resources: [usersTable.tableArn],
      })
    );
    deleteAccountFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:DeleteItem"],
        resources: [scoresTable.tableArn],
      })
    );
    deleteAccountFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:GetItem", "dynamodb:DeleteItem"],
        resources: [sessionsTable.tableArn],
      })
    );
    deleteAccountFn.addToRolePolicy(
      new cdk.aws_iam.PolicyStatement({
        actions: ["dynamodb:Query"],
        resources: [`${sessionsTable.tableArn}/index/${SESSIONS_BY_APPLE_SUB_GSI_NAME}`],
      })
    );

    // --- HTTP API -------------------------------------------------------------

    const httpApi = new apigwv2.HttpApi(this, "HttpApi", {
      apiName: `bronzla-api-${stageName}`,
      description: "Bronzla backend: Apple Sign In, scores and leaderboard.",
      // No stage-level throttle option on HttpApiProps itself: create the
      // stage explicitly below with throttling instead of the implicit
      // default stage.
      createDefaultStage: false,
    });

    // Stage-level throttling across every route. /auth/apple in particular
    // does RSA signature verification per unauthenticated request, so an
    // unthrottled endpoint would let a single caller burn Lambda budget and
    // hammer Apple's JWKS endpoint with no rate limit at all.
    httpApi.addStage("DefaultStage", {
      stageName: "$default",
      autoDeploy: true,
      throttle: {
        rateLimit: 50,
        burstLimit: 100,
      },
    });

    httpApi.addRoutes({
      path: "/auth/apple",
      methods: [apigwv2.HttpMethod.POST],
      integration: new HttpLambdaIntegration("AuthAppleIntegration", authAppleFn),
    });

    httpApi.addRoutes({
      path: "/auth/signout",
      methods: [apigwv2.HttpMethod.POST],
      integration: new HttpLambdaIntegration("SignoutIntegration", signoutFn),
    });

    httpApi.addRoutes({
      path: "/score",
      methods: [apigwv2.HttpMethod.PUT],
      integration: new HttpLambdaIntegration("PutScoreIntegration", putScoreFn),
    });

    httpApi.addRoutes({
      path: "/leaderboard",
      methods: [apigwv2.HttpMethod.GET],
      integration: new HttpLambdaIntegration("GetLeaderboardIntegration", getLeaderboardFn),
    });

    httpApi.addRoutes({
      path: "/account",
      methods: [apigwv2.HttpMethod.DELETE],
      integration: new HttpLambdaIntegration("DeleteAccountIntegration", deleteAccountFn),
    });

    new cdk.CfnOutput(this, "ApiUrl", { value: httpApi.apiEndpoint });
  }
}
