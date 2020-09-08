import * as fs from "fs";
import * as AWS from "aws-sdk";
import { AuthProvider, ResourceManager, ResourceManagerConfig } from "@mcma/client";
import { awsV4Auth } from "@mcma/aws-client";
import { ResourceEndpoint, Service } from "@mcma/core";

const AWS_CREDENTIALS = "../../deployment/aws-credentials.json";
const TERRAFORM_OUTPUT = "../../deployment/terraform.output.json";

AWS.config.loadFromPath(AWS_CREDENTIALS);

async function main() {
    try {
        const terraformOutput = JSON.parse(fs.readFileSync(TERRAFORM_OUTPUT, "utf8"));

        const servicesUrl = terraformOutput.service_registry_aws.value.services_url;
        const jobProfilesUrl = terraformOutput.service_registry_aws.value.job_profiles_url;
        const servicesAuthType = terraformOutput.service_registry_aws.value.auth_type;

        const resourceManagerConfig: ResourceManagerConfig = {
            servicesUrl,
            servicesAuthType
        };

        const resourceManager = new ResourceManager(resourceManagerConfig, new AuthProvider().add(awsV4Auth(AWS)));

        let retrievedServices = await resourceManager.query(Service);

        // 1. Inserting / updating service registry
        let serviceRegistry = new Service({
            name: "Service Registry",
            resources: [
                new ResourceEndpoint({ resourceType: "Service", httpEndpoint: servicesUrl }),
                new ResourceEndpoint({ resourceType: "JobProfile", httpEndpoint: jobProfilesUrl })
            ],
            authType: servicesAuthType
        });

        for (const retrievedService of retrievedServices) {
            if (retrievedService.name === "Service Registry") {
                if (!serviceRegistry.id) {
                    serviceRegistry.id = retrievedService.id;

                    console.log("Updating Service Registry");
                    await resourceManager.update(serviceRegistry);
                } else {
                    console.log("Removing duplicate Service Registry '" + retrievedService.id + "'");
                    await resourceManager.delete(retrievedService);
                }
            }
        }

        if (!serviceRegistry.id) {
            console.log("Inserting Service Registry");
            await resourceManager.create(serviceRegistry);
        }
    } catch (error) {
        if (error.response && error.response.data) {
            console.error(JSON.stringify(error.response.data, null, 2));
        } else {
            console.error(error);
        }
    }
}

main().then(() => console.log("Done"));
