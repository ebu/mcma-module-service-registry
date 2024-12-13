import * as fs from "fs";
import { ResourceManagerConfig, ResourceManager, AuthProvider, mcmaApiKeyAuth } from "@mcma/client";
import { Service } from "@mcma/core";

const TERRAFORM_OUTPUT = "../../deployment/terraform.output.json";

export function log(entry?: any) {
    if (typeof entry === "object") {
        console.log(JSON.stringify(entry, null, 2));
    } else {
        console.log(entry);
    }
}

async function main() {
    return;
    const terraformOutput = JSON.parse(fs.readFileSync(TERRAFORM_OUTPUT, "utf8"));

    log(terraformOutput);

    const apiKey = terraformOutput.deployment_api_key.value;

    const serviceRegistryUrl = terraformOutput.service_registry_azure.value.service_url;
    const serviceRegistryAuthType = terraformOutput.service_registry_azure.value.auth_type;

    const resourceManagerConfig: ResourceManagerConfig = {
        serviceRegistryUrl,
        serviceRegistryAuthType,
    };

    const resourceManager = new ResourceManager(resourceManagerConfig, new AuthProvider().add(mcmaApiKeyAuth({ apiKey })));
    const services = await resourceManager.query(Service);
    log(services);

}

main().catch(console.error);

