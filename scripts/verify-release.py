"""Validate the release allowlist, nested deployment archives, and Terraform consumer."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile
import io

root = Path(__file__).resolve().parents[1]
release = root / "build/release"
metadata = json.loads((release / "release.json").read_text())
assert metadata["version"] == (root / "release-version.txt").read_text().strip()
sums = ""
for cloud, entry in [("aws", "lambdas/api-handler.zip"), ("azure", "function-app.zip")]:
    archive = release / f"terraform-{cloud}.zip"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    assert metadata["sha256"][archive.name] == digest
    sums += f"{digest}  {archive.name}\n"
    with zipfile.ZipFile(archive) as z:
        names = {n for n in z.namelist() if not n.endswith("/")}
        expected = {p.relative_to(root / cloud / "module").as_posix() for p in (root / cloud / "module").rglob("*.tf")}
        assert names == expected | {"LICENSE", entry}, names
        for name in expected:
            assert z.read(name) == (root / cloud / "module" / name).read_bytes(), f"Stale Terraform file: {name}"
        deployment = root / cloud / ("api-handler/build/dist/lambda.zip" if cloud == "aws" else "function-app/build/dist/function.zip")
        assert z.read(entry) == deployment.read_bytes(), "Stale deployment bundle"
        with zipfile.ZipFile(io.BytesIO(z.read(entry))) as app:
            assert json.loads(app.read("package.json"))["type"] == "module"
            assert ("index.js" if cloud == "aws" else "src/index.js") in app.namelist()
        # A fresh consumer directory: no backend initialization, state, or cloud calls.
        with tempfile.TemporaryDirectory(prefix="mcma-release-") as directory:
            z.extractall(directory)
            subprocess.run(["terraform", "init", "-backend=false", "-input=false", "-no-color"], cwd=directory, check=True)
            subprocess.run(["terraform", "validate", "-no-color"], cwd=directory, check=True)
    print(f"Verified {archive.name}: {digest}")
assert (release / "SHA256SUMS").read_text() == sums
