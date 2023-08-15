import { APIGatewayProxyEventV2, Context } from "aws-lambda";
import * as AWSXRay from "aws-xray-sdk-core";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";

import { ConsoleLoggerProvider, JobProfile, Service } from "@mcma/core";
import { DefaultRouteCollection, McmaApiKeySecurityMiddleware, McmaApiMiddleware, McmaApiRouteCollection } from "@mcma/api";
import { DynamoDbTableProvider } from "@mcma/aws-dynamodb";
import { ApiGatewayApiController } from "@mcma/aws-api-gateway";
import { AwsSecretsManagerSecretsProvider } from "@mcma/aws-secrets-manager";

const dynamoDBClient = AWSXRay.captureAWSv3Client(new DynamoDBClient({}));

const loggerProvider = new ConsoleLoggerProvider("service-registry-api-handler");
const dbTableProvider = new DynamoDbTableProvider({}, dynamoDBClient);

const middleware: McmaApiMiddleware[] = [];

if (process.env.MCMA_API_KEY_SECURITY_CONFIG_SECRET_ID) {
    const secretsProvider = new AwsSecretsManagerSecretsProvider();
    const securityMiddleware = new McmaApiKeySecurityMiddleware({ secretsProvider });
    middleware.push(securityMiddleware);
}

const restController =
    new ApiGatewayApiController({
        routes: new McmaApiRouteCollection()
            .addRoutes(new DefaultRouteCollection(dbTableProvider, Service))
            .addRoutes(new DefaultRouteCollection(dbTableProvider, JobProfile)),
        loggerProvider,
        middleware,
    });

export async function handler(event: APIGatewayProxyEventV2, context: Context) {
    const logger = loggerProvider.get(context.awsRequestId);
    try {
        logger.functionStart(context.awsRequestId);
        logger.debug(event);
        logger.debug(context);

        return await restController.handleRequest(event, context);
    } catch (error) {
        logger.error(error);
        throw error;
    } finally {
        logger.functionEnd(context.awsRequestId);
    }
}
