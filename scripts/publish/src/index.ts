import * as fs from "fs";
import * as AWS from "aws-sdk";

const AWS_CREDENTIALS = "../../deployment/aws-credentials.json";
const { MODULE_NAMESPACE, MODULE_NAME, MODULE_VERSION, MODULE_REPOSITORY } = process.env;

AWS.config.loadFromPath(AWS_CREDENTIALS);

async function main() {
    console.log("Publishing to Module Repository");
    console.log("Repository: " + MODULE_REPOSITORY);
    console.log("Namespace:  " + MODULE_NAMESPACE);
    console.log("Name:       " + MODULE_NAME);
    console.log("Version:    " + MODULE_VERSION);

    console.log("Uploading AWS version");
    const s3 = new AWS.S3();
    await s3.upload({
        Bucket: MODULE_REPOSITORY,
        Key: `${MODULE_NAMESPACE}/${MODULE_NAME}/aws/${MODULE_VERSION}/module.zip`,
        Body: fs.createReadStream("../../aws/build/dist/module.zip")
    }).promise();


}

main().then(() => console.log("Done")).catch(reason => console.error(reason));
