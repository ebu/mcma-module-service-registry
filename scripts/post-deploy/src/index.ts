import { readFileSync } from "node:fs";
import { ResourceManager, AuthProvider, mcmaApiKeyAuth } from "@mcma/client";
import { Service } from "@mcma/core";

const TERRAFORM_OUTPUT = new URL("../../../../deployment/terraform.output.json", import.meta.url);

async function main() {
    const terraformOutput = JSON.parse(readFileSync(TERRAFORM_OUTPUT, "utf8"));
    const apiKey = terraformOutput.deployment_api_key?.value;
    if (typeof apiKey !== "string" || !apiKey) {
        throw new Error("Terraform output is missing deployment_api_key; refresh the deployment outputs first.");
    }

    const failed: string[] = [];
    for (const cloud of ["aws", "azure"]) {
        try {
            const endpoint = terraformOutput[`service_registry_${cloud}`]?.value;
            if (!endpoint?.service_url) throw new Error("Missing Service Registry endpoint in Terraform output");
            if (endpoint.auth_type !== "McmaApiKey") {
                throw new Error(`Unsupported authentication type: ${endpoint.auth_type}; this check expects McmaApiKey`);
            }
            console.log(`[${cloud.toUpperCase()}] Checking ${endpoint.service_url}`);
            const manager = new ResourceManager({
                serviceRegistryUrl: endpoint.service_url,
                serviceRegistryAuthType: endpoint.auth_type,
            }, new AuthProvider().add(mcmaApiKeyAuth({ apiKey })));
            const services = await manager.query(Service);
            console.log(`[${cloud.toUpperCase()}] PASS: Service query succeeded`);
            console.log(JSON.stringify(services, null, 2));
        } catch (error) {
            failed.push(cloud.toUpperCase());
            // Do not dump HTTP error objects: their request configuration may contain the API key.
            console.error(`[${cloud.toUpperCase()}] FAIL: ${error instanceof Error ? error.message : "Endpoint check failed"}`);
        }
    }
    if (failed.length) throw new Error(`Service Registry checks failed: ${failed.join(", ")}`);
}

main().catch(error => {
    console.error(error instanceof Error ? error.message : "Post-deployment verification failed");
    process.exitCode = 1;
});
