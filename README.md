# mcma-module-service-registry

This repository will contain code and scripts to build MCMA modules containing the MCMA Service registry targeting AWS, Azure and GCP.

## Important note

As this is still work in progress, please checkout the [development branch](https://github.com/ebu/mcma-module-service-registry/tree/develop) for the current status.


## Building and verification

Requires Node.js 22 or newer. Run `npm ci` at the repository root to install pinned TypeScript 7.0.2 and esbuild 0.28.2, then `npm run verify`. Verification installs locked dependencies, compiles all three packages, and loads the AWS and Azure bundles outside the repository with network access blocked. It does not deploy or run the post-deployment script.

The application uses ESM and published MCMA 2.0.0 packages. Azure logs through the Functions invocation context. Deployment defaults are AWS Node.js 26 (currently preview) and Azure Node.js 24. Bundles still target Node.js 22-compatible syntax.

Run `./gradlew build` (Windows: `.\gradlew.bat build`) to create the deployment ZIPs. Bundling removes unused code and retains source maps and license notices. Azure keeps its Functions runtime and the identity SDK browser helper with their runtime dependencies as external packages. ZIP ordering and timestamps are normalized for repeatable builds.

GitHub Actions verifies Linux on Node 22, 24, and 26, plus Windows on Node 22. Local startup checks do not replace deployed AWS and Azure integration testing. Tracked deployment ZIPs remain available while release consumption is validated.


## Terraform module releases

The release version is recorded in `release-version.txt` (initially 2.0.0). After root `npm ci`, run:

```sh
./gradlew prepareRelease -PreleaseBuild
python scripts/verify-release.py
```

`-PreleaseBuild` excludes deployment and post-deployment Gradle projects and installs locked dependencies using `npm ci`. It requires no `gradle.properties`, cloud credentials, or Terraform backend. CI pins Terraform 1.16.6. Local deployment accepts Terraform 1.10 or newer. Archive verification requires Terraform and network access to download providers, but only runs `init -backend=false` and `validate` in temporary directories. It never plans or applies infrastructure.

The outputs in `build/release` are `terraform-aws.zip`, `terraform-azure.zip`, `SHA256SUMS`, and `release.json`. Each archive contains the Terraform module at its root and the freshly built deployment ZIP in its original relative location. State, variable files, credentials, and cached providers are excluded. Release metadata records the version, source commit (or `local` for local builds), runtimes, and archive hashes.

After this workflow is merged into main, select **Actions > Prepare release > Run workflow** on main. Leave **create_draft** unchecked for a dry run. The workflow runs the Node verification matrix and Terraform archive validation and uploads downloadable workflow artifacts. Select **create_draft** to additionally create a draft release using those exact artifacts. Review the draft and publish it manually when ready. A release will not overwrite an existing tag. The old Gradle `publish` task no longer pushes tags independently.

After publishing v2.0.0, consumers can use:

```hcl
module "service_registry" {
  source = "https://github.com/ebu/mcma-module-service-registry/releases/download/v2.0.0/terraform-aws.zip"
  # Supply the usual module inputs.
}
```

For Azure, use `terraform-azure.zip`. Terraform downloads and extracts the complete module during initialization, so consumers do not need Node.js or Gradle. Draft releases are not anonymously downloadable; test the workflow artifacts locally before publishing, then validate the public release URL through Job Processor. Keep published versions unchanged and update the version file for the next release.

Version 2.0.0 requires AWS provider 6.69.1 or newer within major 6 and AzureRM 5.10.0 or newer within major 5. Existing deployments must run `terraform init -upgrade` in their deployment directory and review the plan before applying. Key Vault continues to use access policies. The archive checks validate provider schemas, not live cloud behavior.


## Post-deployment endpoint check

Run `./gradlew :scripts:post-deploy:run` (Windows: `.\gradlew.bat :scripts:post-deploy:run`) to refresh Terraform outputs and query registered services through both the AWS and Azure endpoints. Both checks are attempted, results are labeled by cloud, and any failure gives a nonzero exit status. This check uses the deployment's MCMA API key and does not print the Terraform output or API key. It performs read-only service queries and currently expects `McmaApiKey` authentication for each registry.
