const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const npm = process.env.npm_execpath;
if (!npm) throw new Error('Run through npm run verify');
function run(args, cwd) {
 const result = spawnSync(process.execPath, args, {cwd, stdio:'inherit'});
 if (result.error) throw result.error;
 if (result.status !== 0) throw new Error(`Verification failed: ${args.join(' ')}`);
}
for (const directory of ['aws/api-handler', 'azure/function-app', 'scripts/post-deploy']) {
 const cwd = path.join(root, directory);
 run([npm, 'ci', '--no-audit', '--no-fund'], cwd);
 const output = path.join(cwd, 'build/staging');
 if (!output.startsWith(root + path.sep)) throw new Error('Unexpected output path');
 fs.rmSync(output, {recursive:true, force:true});
 run([path.join(root,'node_modules/typescript/bin/tsc'), '-p', 'tsconfig.json'], cwd);
 if (!directory.startsWith('scripts/')) run([path.join(root,'scripts/bundle.cjs'),cwd,directory.split('/')[0]],root);
}
console.log('All packages compiled and deployment bundles loaded in isolation.');
