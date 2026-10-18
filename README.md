# Fixed-source Windows wheel build

Build-only repository for `VOICEVOX/pyopenjtalk` commit
`74703b034dd90a1f199f49bb70bf3b66b1728a86`.
Expected version: `0.1.dev251+g74703b0`; CPython 3.11.9 x64;
wheel tag: `cp311-cp311-win_amd64`.

## Manual execution and limits

The workflow runs only through `workflow_dispatch` on `main` in
`YOTSUHA-AUTO/yoha-voicevox-wheel-build`. Publishing files does not run it.
Publication and each dispatch require the repository owner's authorization.
There are no secrets, credentials, models, application settings or user data
in this package. No engine, microphone, audio playback or wheel import occurs.

Build dependencies are pinned with SHA-256 hashes from PyPI. Installation uses
`--require-hashes --only-binary=:all:`; source build uses
`--no-build-isolation --no-deps --no-index`. Upstream and both submodule commits
are checked. No source-version override is used.

The runner must already contain MSVC toolset **14.44.35207** and Windows SDK
**10.0.19041.0**. Missing/mismatched tools stop the run; no installation,
automatic version replacement or rerun is performed. Runner images change:
availability of this exact toolset is not yet tested. Python/build-package
versions are fixed; bit-for-bit reproducibility is not guaranteed.

The build job has only `contents: read`. A separate fresh attestation job has
the additional `id-token: write` and `attestations: write` permissions required
by GitHub. It never executes the wheel. Public repositories on current GitHub
plans support artifact attestations; legacy-plan and organization restrictions
must still be checked. Standard public runners are generally free; account
policy and artifact storage limits remain the owner's responsibility.

Artifacts are an unsigned wheel, fixed-field provenance, SHA256SUMS, and a
GitHub/Sigstore attestation bundle, retained for three days. A build artifact
alone is not an accepted/signed release. Build diagnostics are suppressed;
failure logs/caches/upstream sources are not uploaded as artifacts. Ordinary
GitHub job logs still exist and contain public workflow/build metadata only.
Upstream dependency and source licenses remain applicable.

## Verification before installation (future, not automatic)

1. Verify run success, repository, reviewed workflow commit, manual event,
   expected source/submodule commits, exact toolchain and build-lock digest.
2. Download only the three build outputs and the attestation bundle from that
   run. Verify the signed provenance for each subject and expected workflow:

   `gh attestation verify WHEEL.whl --repo YOTSUHA-AUTO/yoha-voicevox-wheel-build --signer-workflow YOTSUHA-AUTO/yoha-voicevox-wheel-build/.github/workflows/build-wheel.yml`

   Also verify `provenance.json` and `SHA256SUMS` as subjects. Check the returned
   workflow commit/run identity, not just the repository name.
3. Compare the attested SHA-256 to SHA256SUMS and run the read-only
   `verify_wheel.verify(bytes, trusted_sha256)` validator. Its success establishes
   structural consistency only, not provenance by itself or native safety.
4. Installation into an isolated environment and any native import/engine
   execution require separate authorization. This workflow does not perform
   those actions. AVX2 compatibility and native file/log behavior are untested.

## Official references

- https://github.com/VOICEVOX/pyopenjtalk
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/concepts/security/artifact-attestations
- https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations
