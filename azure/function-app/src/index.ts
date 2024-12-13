import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { DefaultRouteCollection, McmaApiRouteCollection, McmaApiKeySecurityMiddleware } from "@mcma/api";
// import { CosmosDbTableProvider, fillOptionsFromConfigVariables } from "@mcma/azure-cosmos-db";
// import { AppInsightsLoggerProvider } from "@mcma/azure-logger";
// import { AzureFunctionApiController } from "@mcma/azure-functions-api";
// import { JobProfile, Service } from "@mcma/core";
// import { AzureKeyVaultSecretsProvider } from "@mcma/azure-key-vault";

import { AzureFunctionApiController } from "./azure-function-api-controller";
import { ConsoleLoggerProvider } from "@mcma/core";

// const loggerProvider = new AppInsightsLoggerProvider("service-registry-api-handler");
const loggerProvider = new ConsoleLoggerProvider("service-registry-api-handler");

// const dbTableProvider = new CosmosDbTableProvider(fillOptionsFromConfigVariables());
// const secretsProvider = new AzureKeyVaultSecretsProvider();

// const securityMiddleware = new McmaApiKeySecurityMiddleware({ secretsProvider });
// //
// const restController =
//     new AzureFunctionApiController(
//         {
//             routes: new McmaApiRouteCollection()
//                 .addRoutes(new DefaultRouteCollection(dbTableProvider, Service))
//                 .addRoutes(new DefaultRouteCollection(dbTableProvider, JobProfile)),
//             loggerProvider,
//             middleware: [securityMiddleware],
//         });

const restController2 = new AzureFunctionApiController({
    routes: new McmaApiRouteCollection(),
    loggerProvider
})

export async function handler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log(`Http function processed request for url "${request.url}"`);

    const logger = await loggerProvider.get(context.invocationId);

    try {
        logger.functionStart(context.invocationId);
        logger.debug(context);
        logger.debug(request);

        // await restController2.handleRequest(request);
    } catch (e) {
        context.error(e);
    } finally {
        logger.functionEnd(context.invocationId);
        // loggerProvider.flush();
    }

    return {
        status: 200,
        jsonBody: { "Hello": "world 3!" }
    };
}

app.http("api-handler", {
    route: "{*path}",
    methods: ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "TRACE", "CONNECT"],
    authLevel: "anonymous",
    handler
});
