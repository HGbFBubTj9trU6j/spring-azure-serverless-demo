# Step 7: Software Supply Chain Security / DevSecOps

Step 6 continuously builds and deploys the application. Step 7 adds a separate path for understanding and reassessing the exact backend artifact that was produced.

The goal is not merely to run two security tools. It is to establish a traceable loop:

```text
Git commit
    ↓
backend:<Git SHA> in Azure Container Registry
    ↓
resolve tag to OCI digest
    ↓
Syft inventory and SBOM
    ↓
Grype vulnerability assessment
    ↓
private, access-controlled reports
    ↓
remediate, rebuild, and re-scan
```

This step covers:

- inspecting a Buildpacks-produced OCI image rather than only `pom.xml`;
- generating Syft JSON and SPDX JSON SBOMs;
- assessing the SBOM with Grype;
- scanning an existing Azure Container Registry (ACR) image without rebuilding it;
- resolving a mutable tag to an immutable OCI digest before scanning;
- separating deployment from security assessment;
- keeping detailed reports in private Azure Blob Storage;
- publishing only severity counts to the GitHub Actions summary;
- using local scripts to investigate an ACR image and retrieve stored reports; and
- verifying remediation through both Java runtime and Maven-managed dependency case studies.

> [!IMPORTANT]
> A scanner finding is evidence for investigation, not an automatic statement of exploitability. Review the detected package, match type, fixed versions, runtime architecture, application exposure, and compensating controls before making a release decision.

## Goals

By the end of Step 7, the project can answer the following questions for a deployed backend artifact:

1. Which Git commit produced it?
2. Which immutable OCI manifest was scanned?
3. Which application, runtime, operating-system, and Buildpack-provided packages are present?
4. Which known vulnerabilities matched those packages at scan time?
5. Where are the detailed reports stored, and who can read or write them?
6. Was a remediation actually present in the rebuilt artifact?

## Why the OCI image is the assessment boundary

A Maven dependency tree describes Java dependencies declared by the application. It does not fully describe the deployed image. The final OCI image also contains components supplied by the builder and its participating Buildpacks, including the Java runtime, operating-system packages, certificates, launch configuration, and Spring Boot layers.

The relevant Paketo Buildpacks include:

| Buildpack | Responsibility in the build |
|---|---|
| [CA Certificates](https://github.com/paketo-buildpacks/ca-certificates) | Contributes trusted CA certificates when required. |
| [BellSoft Liberica](https://github.com/paketo-buildpacks/bellsoft-liberica) | Contributes the JDK or JRE selected for the application. |
| [Syft](https://github.com/paketo-buildpacks/syft) | Provides Syft integration used by the Buildpacks lifecycle for software inventory metadata. |
| [Executable JAR](https://github.com/paketo-buildpacks/executable-jar) | Detects and configures executable JAR applications and their launch process. |
| [Spring Boot](https://github.com/paketo-buildpacks/spring-boot) | Contributes Spring Boot dependency metadata and application layers. |

The Syft Buildpack that participates during image creation and the standalone Syft CLI used in this step are related but distinct:

- the Buildpack runs as part of the Cloud Native Buildpacks lifecycle; and
- the standalone CLI inspects the completed OCI image from outside the build.

The external scan is the verification boundary used here because it evaluates the artifact stored in ACR—the artifact that can actually be deployed.

## Architecture and responsibility boundaries

The CI/CD and security workflows intentionally have different responsibilities.

```text
.github/workflows/cicd.yml
    ├── test the application
    ├── build backend:<Git SHA>
    ├── push the image to ACR
    ├── deploy it to Azure Container Apps
    └── verify the deployment

.github/workflows/security-scan.yml
    ├── accept an existing 40-character Git SHA
    ├── resolve backend:<Git SHA> to an OCI digest
    ├── scan that digest with Syft
    ├── assess the generated SBOM with Grype
    ├── generate scan metadata
    ├── upload detailed reports to private Blob Storage
    └── write severity counts to the GitHub Actions summary
```

The security workflow does **not** rebuild the application. Rebuilding could produce a different artifact because builder contents, Buildpack dependencies, vulnerability databases, and upstream packages can change. Scanning the existing ACR artifact preserves the identity established by Step 6.

## Artifact identity: Git SHA, tag, and digest

Step 6 tags each backend image with the full Git commit SHA:

```text
<acr-login-server>/backend:<40-character Git SHA>
```

A tag is a useful human-readable link to source control, but an OCI tag can be moved. Before scanning, Step 7 resolves the tag to its manifest digest:

```text
backend:<Git SHA>
    ↓
sha256:<OCI manifest digest>
    ↓
<acr-login-server>/backend@sha256:<OCI manifest digest>
```

Syft scans the digest-qualified reference. The scan metadata records both the source tag and resolved digest so that the result can be traced back to Git while remaining bound to immutable image content.

## Prerequisites

### Tools

Install and verify:

- PowerShell 7 or later;
- Azure CLI;
- Syft;
- Grype; and
- Git.

```powershell
pwsh --version
az version
syft version
grype version
git --version
```

The examined toolchain referenced [Syft 1.57.1](https://github.com/anchore/syft/releases/tag/v1.57.1). Treat tool versions as part of the scan metadata and update them deliberately; a newer scanner or vulnerability database can produce different findings for the same image.

### Azure sign-in and subscription

Sign in with the identity that has access to the project resources:

```powershell
az login
az account show -o table
```

If more than one subscription is available, select the intended subscription before scanning or downloading reports:

```powershell
az account set --subscription "<subscription-id-or-name>"
```

### Project configuration

Environment-specific, non-secret values are loaded from `config/dev.psd1`. Step 7 uses these settings:

```powershell
@{
    AcrName                          = "<acr-name>"
    BackendBuilderImage             = "<builder-image>@sha256:<digest>"
    SecurityReportStorageAccountName = "<storage-account-name>"
    SecurityReportContainerName      = "security-reports"
}
```

Do not place access tokens, Storage Account keys, or other credentials in this file.

### Required access

The least-privilege model is:

| Principal | Resource scope | Role / permission | Purpose |
|---|---|---|---|
| GitHub Actions user-assigned managed identity | ACR | Read/pull access | Resolve and scan the backend image. |
| GitHub Actions user-assigned managed identity | `security-reports` Blob container | `Storage Blob Data Contributor` | Upload the four detailed report files. |
| Human reviewer | ACR | Read/pull access | Run the local ACR scan. |
| Human reviewer | `security-reports` Blob container | `Storage Blob Data Reader` | Download stored reports. |

Assign Blob data roles at the container scope rather than the storage-account or subscription scope when broader access is unnecessary.

## 7.1 Inspect a local Buildpacks image

Start by making the contents of a locally built image visible.

```powershell
.\mvnw.cmd spring-boot:build-image
```

If the generated image is `backend:0.0.1-SNAPSHOT`, list its packages:

```powershell
syft "docker:backend:0.0.1-SNAPSHOT"
```

Generate both project formats:

```powershell
New-Item -ItemType Directory -Force -Path ".\security-reports\local" | Out-Null

syft "docker:backend:0.0.1-SNAPSHOT" `
  -o "syft-json=.\security-reports\local\sbom.syft.json" `
  -o "spdx-json=.\security-reports\local\sbom.spdx.json"
```

Use Syft JSON as the machine-oriented input for Grype and retain SPDX JSON as the interoperable SBOM representation.

```powershell
grype "sbom:.\security-reports\local\sbom.syft.json" `
  -o json `
  --file ".\security-reports\local\grype-report.json"
```

Keep `security-reports/` outside version control. SBOMs and vulnerability reports can reveal package names, versions, file paths, and unpatched components.

## 7.2 Scan an ACR image locally

The repository includes `scripts/scan-backend-image.ps1` for repeatable local investigation.

### Scan the newest backend tag

```powershell
.\scripts\scan-backend-image.ps1
```

The script chooses the newest ACR `backend` tag according to registry metadata, resolves it to a digest, and scans that immutable reference.

### Scan a specific CI/CD artifact

```powershell
.\scripts\scan-backend-image.ps1 `
  -ImageTag "<40-character Git SHA>"
```

The SHA is validated with `^[0-9a-f]{40}$` before it is used as an image tag.

### Authentication flow

The script does not require `docker pull` or a running Docker daemon. It obtains a short-lived ACR token from the current Azure CLI session:

```text
az login identity
    ↓
az acr login --expose-token
    ↓
short-lived ACR access token
    ↓
Syft registry source
    ↓
private ACR image by digest
```

The important distinction is that `az acr login --expose-token` returns a token instead of asking the Docker client to store credentials. Syft then reads the registry directly.

Equivalent manual commands are shown below for learning and troubleshooting. Prefer the script for normal operation because it also resolves the digest, restores authentication-related environment variables, generates all reports, and records metadata.

```powershell
$config = Import-PowerShellDataFile ".\config\dev.psd1"
$acrName = $config.AcrName
$acrLoginServer = "$acrName.azurecr.io"
$imageTag = "<40-character Git SHA>"

$acrToken = az acr login `
  --name $acrName `
  --expose-token `
  --query accessToken `
  -o tsv

$env:SYFT_REGISTRY_AUTH_USERNAME = "00000000-0000-0000-0000-000000000000"
$env:SYFT_REGISTRY_AUTH_PASSWORD = $acrToken

$image = "$acrLoginServer/backend:$imageTag"
syft "registry:$image"
```

Treat the returned token as a credential. Do not write it to logs or persist it in the repository.

### Local outputs

The script writes:

```text
security-reports/
└── <Git SHA>/
    ├── sbom.syft.json
    ├── sbom.spdx.json
    ├── grype-report.json
    └── scan-metadata.json
```

It prints a severity summary to the console but does not upload local results to Blob Storage. The GitHub Actions workflow is the authoritative path for generating and retaining shared reports.

## 7.3 Understand the generated reports

### `sbom.syft.json`

Syft's native JSON representation contains detailed package and relationship data. It is the input used by Grype in this project.

### `sbom.spdx.json`

The SPDX JSON representation supports interchange with tools and processes that consume the SPDX standard. It is retained alongside Syft JSON rather than generated later from a potentially different image.

### `grype-report.json`

The Grype JSON report contains matched artifacts, vulnerability identifiers, severity, fix information, match details, and scanner metadata. Interpret findings in context:

- `Critical`, `High`, `Medium`, `Low`, `Negligible`, and `Unknown` are prioritization signals;
- exact direct or indirect matches generally carry stronger package evidence than broad CPE-based matches;
- an empty fix-version list does not mean the package is safe;
- the same vulnerability can appear through more than one advisory or package relationship; and
- scanner and database versions affect the result.

### `scan-metadata.json`

The metadata file binds the reports to their execution context. It should include, at minimum:

- Git SHA / image tag;
- tagged image reference;
- resolved digest-qualified image reference;
- OCI digest;
- scan timestamp in UTC;
- Syft version;
- Grype version; and
- report schema or file names used by the workflow.

Do not treat `scan-metadata.json` as a cryptographic signature. It is traceability metadata. Image signing and attestation are future controls.

## 7.4 Security Scan workflow

The independent workflow is defined in:

```text
.github/workflows/security-scan.yml
```

It is manually triggered with `workflow_dispatch` and a full Git SHA. The expected sequence is:

1. Validate the 40-character lowercase hexadecimal SHA.
2. Check out the repository configuration and workflow code.
3. Authenticate to Azure through GitHub OIDC and the user-assigned managed identity.
4. Read `AcrName`, storage account name, and container name from `config/dev.psd1`.
5. Resolve `backend:<SHA>` to its OCI digest.
6. Acquire a short-lived ACR token and scan the digest-qualified image with Syft.
7. Produce Syft JSON and SPDX JSON SBOMs.
8. Run Grype against the Syft JSON SBOM.
9. Create `scan-metadata.json`.
10. Calculate severity counts for the GitHub Actions job summary.
11. Upload all four detailed files to private Blob Storage with Microsoft Entra authorization.

A successful run preserves this relationship:

```text
Git SHA
  = ACR tag
  → OCI digest
  → SBOMs
  → Grype report
  → scan metadata
  → private report prefix
```

### Why the workflow is manual

The first implementation uses `workflow_dispatch` so that an operator can select an existing artifact and investigate it without changing the deployment path. This keeps Step 7 focused on inventory, traceability, report protection, and verified remediation.

A schedule can be added later for continuous vulnerability re-evaluation. A newly published vulnerability can affect an unchanged image, so periodic re-scanning is useful even when no application code changed.

## 7.5 Private report storage

Detailed reports are uploaded under a per-artifact prefix:

```text
security-reports/
└── backend/
    └── <Git SHA>/
        ├── sbom.syft.json
        ├── sbom.spdx.json
        ├── grype-report.json
        └── scan-metadata.json
```

The storage design applies the following controls:

- Blob container access is private;
- anonymous public access is disabled;
- Shared Key authorization is disabled;
- HTTPS is required;
- TLS 1.2 or later is required;
- GitHub Actions writes with Microsoft Entra ID and container-scoped RBAC; and
- reviewers read with Microsoft Entra ID and container-scoped RBAC.

Azure CLI data operations explicitly use:

```text
--auth-mode login
```

Omitting `--auth-mode login` can cause Azure CLI to attempt account-key authorization. The scripts and workflow make the intended identity path explicit.

## 7.6 GitHub Actions summary disclosure boundary

The GitHub Actions summary displays only aggregate counts, for example:

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 2 |
| Medium | 8 |
| Low | 4 |
| Negligible | 1 |
| Unknown | 0 |

The summary must not include:

- package or executable names;
- installed package versions;
- CVE descriptions;
- fixed versions;
- file paths;
- the full SBOM; or
- the full Grype report.

This is a disclosure boundary, not a complete authorization control. Repository permissions still govern who can view workflow runs, and detailed reports remain protected by Azure RBAC.

The first implementation reports findings without applying a release gate. A rule such as “fail whenever `Critical > 0`” is intentionally deferred until match quality, exploitability, accepted risk, exceptions, and remediation SLAs are defined.

## 7.7 Download a stored report

Use `scripts/download-security-report.ps1` to retrieve reports through the signed-in Azure identity.

### Download the newest completed report

```powershell
.\scripts\download-security-report.ps1
```

With no `-ImageTag`, the script lists `backend/*/scan-metadata.json` blobs and selects the newest completed report by Blob `lastModified` time. It does not assume that the current Git `HEAD` already has a completed scan.

### Download a specific report

```powershell
.\scripts\download-security-report.ps1 `
  -ImageTag "<40-character Git SHA>"
```

The script downloads the four expected files to:

```text
security-reports/<Git SHA>/
```

It uses `az storage blob` commands with `--auth-mode login`; it does not retrieve or use a Storage Account key.

## 7.8 Review report data locally

Pretty-print JSON with PowerShell:

```powershell
Get-Content ".\security-reports\<Git SHA>\grype-report.json" -Raw |
  ConvertFrom-Json |
  ConvertTo-Json -Depth 100
```

Display the severity distribution:

```powershell
$report = Get-Content ".\security-reports\<Git SHA>\grype-report.json" -Raw |
  ConvertFrom-Json

$report.matches |
  Group-Object { $_.vulnerability.severity } |
  Sort-Object Name |
  Select-Object Name, Count |
  Format-Table -AutoSize
```

List Critical and High findings with available fixes:

```powershell
$report.matches |
  Where-Object { $_.vulnerability.severity -in @("Critical", "High") } |
  Select-Object `
    @{Name="Package"; Expression={$_.artifact.name}},
    @{Name="Installed"; Expression={$_.artifact.version}},
    @{Name="Vulnerability"; Expression={$_.vulnerability.id}},
    @{Name="Severity"; Expression={$_.vulnerability.severity}},
    @{Name="FixedIn"; Expression={$_.vulnerability.fix.versions -join ", "}} |
  Format-Table -AutoSize
```

Review match details in the full JSON before deciding that a finding is a false positive or release blocker.

## 7.9 Verified remediation case study: Java4Shell

The project exercised the complete detect, trace, remediate, and verify loop against `CVE-2026-114938`, commonly referred to as Java4Shell.

### Initial observation

Syft showed that the completed backend image contained OpenJDK `21.0.12`. Grype matched `CVE-2026-114938` to that runtime.

The important finding was not only the CVE. It was the provenance of the affected component:

```text
pom.xml
    └── does not select the packaged JRE

Spring Boot Buildpacks
    ↓
Paketo builder
    ↓
BellSoft Liberica Buildpack
    ↓
Liberica JRE in the final OCI image
```

Because the issue was in the runtime, changing an application dependency would not remediate the packaged JRE.

### Remediation

The builder was updated to a version containing the corrected BellSoft Liberica dependency, then pinned by digest in `config/dev.psd1`:

```powershell
BackendBuilderImage = "paketobuildpacks/builder-noble-java-tiny@sha256:<verified-digest>"
```

Local builds and GitHub Actions both consume this value, preventing an unnoticed difference between developer and CI builder selection.

The rebuilt image contained BellSoft Liberica JRE `21.0.13.1+5`, corresponding to the published archive:

```text
bellsoft-jre21.0.13.1+5-linux-amd64.tar.gz
```

See the [BellSoft Liberica release artifact](https://github.com/bell-sw/Liberica/releases/download/21.0.13.1+5/bellsoft-jre21.0.13.1+5-linux-amd64.tar.gz) and [BellSoft guidance for CVE-2026-114938](https://bell-sw.com/blog/addressing-java4shell-in-liberica-jdk/).

### Verification

The remediated application was rebuilt, pushed as a new Git-SHA-tagged image, resolved to its new digest, and scanned again. The target CVE was no longer detected.

```text
OpenJDK 21.0.12
    ↓
CVE-2026-114938 detected
    ↓
trace runtime to BellSoft Liberica Buildpack and Paketo builder
    ↓
update and digest-pin the builder
    ↓
BellSoft Liberica JRE 21.0.13.1+5
    ↓
rebuild and re-scan
    ↓
CVE-2026-114938 not detected
```

This verifies two separate properties:

1. **Remediation** — the fixed runtime is present in the rebuilt image.
2. **Provenance** — the runtime came from the builder and Buildpack supply chain, not from Maven dependencies alone.

The non-detection is specific to the image, scanner, and vulnerability database used for the verification. It does not prove the image has no other vulnerabilities.

## 7.10 Verified remediation case study: Netty Maven dependencies

The project also exercised the remediation loop for a Netty vulnerability introduced transitively through the Azure SDK.

### Initial observation and dependency trace

Grype detected affected Netty components in the Buildpacks-produced OCI image. The affected range included 4.2.19.Final, and 4.2.20.Final was identified as the corrected version. Because the finding covered both `netty-handler` and the QUIC classes, updating only one Netty module would not have been sufficient.

The dependency path was confirmed with Maven:

```powershell
.\mvnw.cmd dependency:tree "-Dincludes=io.netty"
```

In PowerShell, quote the entire `-Dincludes=io.netty` argument. Without the quotes, Maven can receive `.netty` as a separate argument and report `Unknown lifecycle phase ".netty"`.

The resolved path was:

```text
com.azure:azure-identity:1.18.7
  └── com.azure:azure-core-http-netty:1.16.8
      └── io.netty:*:4.2.19.Final
```

This confirmed that Netty was a transitive dependency of `azure-identity`, not a dependency declared directly by the application.

### Locate the managed version

Before changing `pom.xml`, the effective POM was generated and inspected:

```powershell
.\mvnw.cmd help:effective-pom > effective-pom.xml
Select-String -Path .\effective-pom.xml -Pattern "netty.version"
```

The effective POM contained:

```xml
<netty.version>4.2.19.Final</netty.version>
```

`effective-pom.xml` is generated diagnostic output and must not be committed.

### Remediation

The existing managed property was overridden in `pom.xml`:

```xml
<properties>
    <!-- Other managed versions omitted -->
    <netty.version>4.2.20.Final</netty.version>
</properties>
```

The project did not add a direct dependency on `netty-handler` and did not import an additional Netty BOM. Using the existing property preserved the dependency-management boundary and kept related modules aligned.

### Verification

The dependency tree was checked again. The affected and related modules resolved consistently to 4.2.20.Final, including:

```text
io.netty:netty-handler:4.2.20.Final
io.netty:netty-codec-classes-quic:4.2.20.Final
io.netty:netty-codec-http3:4.2.20.Final
io.netty:netty-common:4.2.20.Final
```

`netty-tcnative-boringssl-static` uses a separate version line and moved from 2.0.84.Final to 2.0.85.Final through the managed dependency set.

The backend OCI image was then rebuilt with Buildpacks and scanned again with Grype. The target Netty finding was no longer present. Maven verifies the dependency graph; the final Grype scan verifies the content of the distributable OCI artifact.

```text
Grype finding in OCI image
    ↓
trace azure-identity → azure-core-http-netty → Netty
    ↓
confirm netty.version in the effective POM
    ↓
update 4.2.19.Final → 4.2.20.Final
    ↓
verify aligned modules with dependency:tree
    ↓
rebuild the Buildpacks OCI image
    ↓
re-scan with Grype
    ↓
target Netty finding not detected
```

### Findings requiring a different response

The same scan showed three different remediation states:

- **Remediate and verify:** Netty had a compatible corrected version, so the project updated it and re-scanned the image.
- **Track and re-evaluate:** `tomcat-embed-core` 11.0.29 listed 11.0.30 as the corrected version, but 11.0.30 was not yet available from Maven Central at the time of investigation. The project did not declare an unavailable version merely to silence the finding.
- **Validate provenance and match quality:** OpenSSL appeared through both binary and Ubuntu-package detection. Review the Ubuntu package version and advisory status rather than assuming that the upstream version string alone proves a backported fix is absent.

This case demonstrates why updating only the package named in a scanner row can be unsafe. Related modules may remain affected, or the application may end up with an unsupported mixed-version set.

## 7.11 Builder pinning and updates

Pinning the builder by digest makes builds reproducible, but a digest pin does not update itself. Treat the builder as a maintained dependency:

1. Identify a candidate builder update.
2. Review the builder and relevant Buildpack release information.
3. Resolve and record the new builder digest.
4. Update `BackendBuilderImage` in `config/dev.psd1`.
5. Build the backend locally.
6. Inspect the resulting image with Syft.
7. Scan the SBOM with Grype.
8. Commit the configuration change.
9. Let CI/CD build and deploy the Git-SHA-tagged artifact.
10. Run the independent security scan against that ACR artifact.

Do not replace a digest pin with a floating `latest` tag merely to receive security updates automatically. Controlled update plus re-verification preserves both security and reproducibility.

## 7.12 ACR artifact lifecycle

Git-SHA tags accumulate as development continues. ACR is a billed service, but tag count alone does not equal consumed storage because OCI layers can be shared.

Before deleting artifacts:

- identify the image currently deployed to Azure Container Apps;
- preserve artifacts associated with a release;
- preserve artifacts needed for the remediation case study or an active investigation;
- decide whether reports may outlive their corresponding image; and
- review ACR usage with `az acr show-usage`.

A demo environment can start with a policy such as:

```text
keep: currently deployed image
keep: release-associated images
keep: investigation and case-study images
keep: recent development images for a defined period or count
delete candidate: old non-release images
delete candidate: local *-dirty tags after verification
```

Always list candidates first and delete by an explicit, reviewed condition. A time-based rule must not remove a currently deployed, released, or investigation-relevant image.

## 7.13 Failure handling and troubleshooting

### `manifest unknown` or image not found

- Confirm that the full Git SHA exists as a tag in the `backend` repository.
- List tags with `az acr repository show-tags`.
- Confirm that `config/dev.psd1` points to the intended ACR and subscription.

### ACR authorization failure

- Run `az account show` and verify the tenant and subscription.
- Confirm the reviewer or managed identity has read/pull access to the registry.
- Acquire a new token; exposed ACR tokens are short-lived.
- Do not fall back to the ACR admin account for routine scanning.

### Syft cannot authenticate

- Confirm that both registry authentication environment variables are set for the process invoking Syft.
- Confirm that the digest-qualified image reference uses the correct login server.
- Remove or restore temporary environment variables after the scan.
- Never print the token value.

### Grype database update fails

- Check network access to the configured Grype database source.
- Record the database status and scanner version.
- Do not present a stale or unavailable database scan as a current clean result.

### Blob upload or download is denied

- Confirm `--auth-mode login` is present.
- Confirm the principal has the required Blob data role, not only an Azure management-plane role.
- Confirm the assignment scope is the intended `security-reports` container.
- Allow for RBAC propagation after a new role assignment.

### Report set is incomplete

Treat a report as complete only when all four expected files exist. The download script uses `scan-metadata.json` when discovering the newest completed report so that a partially uploaded prefix is not selected as a successful result.

## 7.14 Verification checklist

Use this checklist before considering Step 7 complete for an artifact:

- [ ] The source Git SHA is known.
- [ ] `backend:<Git SHA>` exists in the intended ACR.
- [ ] The tag was resolved to an OCI digest before scanning.
- [ ] Syft scanned the digest-qualified reference.
- [ ] `sbom.syft.json` was generated.
- [ ] `sbom.spdx.json` was generated.
- [ ] `grype-report.json` was generated from the Syft SBOM.
- [ ] `scan-metadata.json` records the tag, digest, timestamp, and tool versions.
- [ ] The GitHub Actions summary contains severity counts only.
- [ ] All four detailed files were uploaded to the private Blob prefix.
- [ ] The writer and reader roles are scoped to the report container.
- [ ] Shared Key and anonymous access are not used.
- [ ] Local `security-reports/` remains excluded from Git.
- [ ] Any remediation was verified by scanning the rebuilt ACR artifact.

## Future extensions

The next useful improvements are deliberately outside the Step 7 completion boundary:

1. **Scheduled re-scanning** — assess unchanged images against a newer vulnerability database.
2. **Documented retention automation** — protect deployed and release artifacts while removing eligible old images and reports.
3. **Exception and risk workflow** — record accepted risk, false-positive rationale, ownership, and expiry.
4. **Release policy** — define `PASS`, `REVIEW`, and `FAIL` from reviewed policy rather than a raw severity count.
5. **Image signing and verification** — add cryptographic identity to OCI artifacts.
6. **Provenance and attestations** — publish verifiable build and SBOM attestations.
7. **Additional SBOM formats** — add CycloneDX only when a consumer requires it.

A release gate should be introduced only after the team defines match-confidence handling, exploitability context, remediation SLAs, exception ownership, and an emergency override process.

## Related files

```text
.github/workflows/cicd.yml
.github/workflows/security-scan.yml
config/dev.psd1
scripts/scan-backend-image.ps1
scripts/download-security-report.ps1
docs/step06-cicd.md
docs/step06-cicd.ja.md
docs/step07-software-supply-chain-security.md
docs/step07-software-supply-chain-security.ja.md
```

## References

- [Paketo Buildpack for CA Certificates](https://github.com/paketo-buildpacks/ca-certificates)
- [Paketo Buildpack for BellSoft Liberica](https://github.com/paketo-buildpacks/bellsoft-liberica)
- [Paketo Buildpack for Syft](https://github.com/paketo-buildpacks/syft)
- [Paketo Buildpack for Executable JARs](https://github.com/paketo-buildpacks/executable-jar)
- [Paketo Buildpack for Spring Boot](https://github.com/paketo-buildpacks/spring-boot)
- [Syft 1.57.1 release](https://github.com/anchore/syft/releases/tag/v1.57.1)
- [Syft private registry authentication](https://github.com/anchore/syft/wiki/Private-Registry-Authentication)
- [Grype getting started](https://oss.anchore.com/docs/guides/vulnerability/getting-started/)
- [Understanding Grype results](https://oss.anchore.com/docs/guides/vulnerability/interpreting-results/)
- [Working with Grype JSON](https://oss.anchore.com/docs/guides/vulnerability/json/)
- [Authenticate with Azure Container Registry](https://learn.microsoft.com/azure/container-registry/container-registry-authentication)
- [Authorize Azure Blob data operations with Azure CLI](https://learn.microsoft.com/azure/storage/blobs/authorize-data-operations-cli)
- [GitHub Actions secure use reference](https://docs.github.com/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [BellSoft guidance for Java4Shell / CVE-2026-114938](https://bell-sw.com/blog/addressing-java4shell-in-liberica-jdk/)
