import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { DefaultRouteCollection, McmaApiRouteCollection, McmaApiKeySecurityMiddleware } from "@mcma/api";
import { JobProfile, Service } from "@mcma/core";
import { CosmosDbTableProvider, fillOptionsFromConfigVariables } from "@mcma/azure-cosmos-db";
import { AzureKeyVaultSecretsProvider } from "@mcma/azure-key-vault";
import { AppInsightsLoggerProvider } from "@mcma/azure-logger";
import { AzureFunctionApiController } from "@mcma/azure-functions-api";

const dbTableProvider = new CosmosDbTableProvider(fillOptionsFromConfigVariables());
const loggerProvider = new AppInsightsLoggerProvider("service-registry-api-handler");
const secretsProvider = new AzureKeyVaultSecretsProvider();
const securityMiddleware = new McmaApiKeySecurityMiddleware({ secretsProvider });

const restController =
    new AzureFunctionApiController(
        {
            routes: new McmaApiRouteCollection()
                .addRoutes(new DefaultRouteCollection(dbTableProvider, Service))
                .addRoutes(new DefaultRouteCollection(dbTableProvider, JobProfile)),
            loggerProvider,
            middleware: [securityMiddleware],
        });

export async function handler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    const logger = await loggerProvider.get(context.invocationId);

    try {
        logger.functionStart(context.invocationId);
        logger.debug(request);
        logger.debug(context);

        return await restController.handleRequest(request);
    } finally {
        logger.functionEnd(context.invocationId);
        loggerProvider.flush();
    }
}

app.http("api-handler", {
    route: "{*path}",
    methods: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "TRACE", "CONNECT"],
    authLevel: "anonymous",
    handler
});
