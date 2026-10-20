# mcma-module-service-registry

This repository will contain code and scripts to build MCMA modules containing the MCMA Service registry targeting AWS, Azure and GCP.

## Important note

As this is still work in progress, please checkout the [development branch](https://github.com/ebu/mcma-module-service-registry/tree/develop) for the current status.


## Building and verification

Requires Node.js 22 or newer. Run `npm ci` at the repository root to install pinned TypeScript 7.0.2 and esbuild 0.28.2, then `npm run verify`. Verification installs locked dependencies, compiles all three packages, and loads the AWS and Azure bundles outside the repository with network access blocked. It does not deploy or run the post-deployment script.

The application uses ESM and published MCMA 2.0.0 packages. Azure logs through the Functions invocation context. Both cloud runtimes require Node.js 22 or newer.

Run `./gradlew build` (Windows: `.\gradlew.bat build`) to create the deployment ZIPs. Bundling removes unused code and retains source maps and license notices. Azure keeps its Functions runtime and the identity SDK browser helper with their runtime dependencies as external packages. ZIP ordering and timestamps are normalized for repeatable builds.

GitHub Actions verifies Linux on Node 22, 24, and 26, plus Windows on Node 22. Local startup checks do not replace deployed AWS and Azure integration testing. Terraform modules currently continue to include their deployment ZIPs; GitHub Release distribution will be introduced separately after deployment validation.
