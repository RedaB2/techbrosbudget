# Release Pipeline

This repo uses the conventional iOS release split:

- Pull requests: build and test only.
- `dev`: publish an external TestFlight beta and submit it for beta review.
- `main`: publish an external TestFlight release candidate and submit it for beta review.
- `v*` tags: publish an App Store build and submit it for review.
- Manual dispatch: run the external TestFlight or App Store lane with an explicit version.

CI runs the full test suite against an iOS `26.5` simulator. It also runs the
app/unit-test path against an iOS `27.0` simulator when that runtime is available
on the runner; hosted GitHub runners may temporarily skip this optional lane
until Apple/GitHub publish the runtime. The app and widget deployment target
stays at `26.5`, so one TestFlight binary supports iOS 26.5 and newer.

## Versioning

The current beta version is `0.1`.

Use the marketing version for product milestones:

- `0.1`: first TestFlight beta.
- `0.2`, `0.3`: later beta milestones.
- `1.0`: first public launch.

Build numbers are not hardcoded. CI asks App Store Connect for the next safe
build number for the selected marketing version, then archives with:

```text
MARKETING_VERSION=<version>
CURRENT_PROJECT_VERSION=<next build number>
```

This keeps the app and widget extension aligned, for example:

```text
0.1 (1)
0.1 (2)
0.1 (3)
```

## Required GitHub Secrets

Create these in GitHub repository settings under **Secrets and variables > Actions > Secrets**:

- `ASC_APP_ID`: numeric App Store Connect app ID.
- `ASC_KEY_ID`: App Store Connect API key ID.
- `ASC_ISSUER_ID`: App Store Connect issuer ID.
- `ASC_PRIVATE_KEY`: contents of the `.p8` App Store Connect API private key.

The API key needs enough access to manage builds, TestFlight, and App Store
submission. For first setup, use an Admin-capable key if possible, then narrow
permissions after the pipeline is proven.

## Required GitHub Variables

Create these under **Secrets and variables > Actions > Variables**:

- `IOS_MARKETING_VERSION`: default marketing version, currently `0.1`.
- `TESTFLIGHT_EXTERNAL_GROUP`: external group name, for example `Tech Bros Budget Beta`.

If group variables are omitted, the workflow falls back to those example names.

## Required GitHub Environments

Create these GitHub Environments:

- `testflight-external`
- `appstore-production`

Recommended protection:

- `testflight-external`: optional required reviewer if you want a human gate before beta review submission.
- `appstore-production`: required reviewer before deployment.

Do not push `v*` tags until `appstore-production` has a required reviewer.

## Required App Store Connect Setup

Before the first successful release job:

1. Create the app record for `Tech Bros Budget`.
2. Register and enable signing/capabilities for:
   - `reda.techbrosbudget`
   - `reda.techbrosbudget.widgets`
   - `group.reda.techbrosbudget`
   - `iCloud.reda.techbrosbudget`
3. Create the TestFlight groups named by the GitHub variables.
4. Deploy the CloudKit schema to production before broad TestFlight use.
5. Complete App Privacy and metadata before App Store submission.

The workflow uses Xcode automatic signing with the App Store Connect API key and
`-allowProvisioningUpdates`. If automatic signing is blocked by account policy,
switch to a stored signing-asset flow such as `asc signing sync`.

## Manual Runs

Open **Actions > iOS > Run workflow** and choose:

- `external-testflight`: upload to external TestFlight. The checkbox controls beta review submission.
- `appstore`: upload/attach an App Store build. The checkbox controls App Review submission.

For normal branch-based automation:

```bash
git push origin dev
git push origin main
git tag v0.1
git push origin v0.1
```
