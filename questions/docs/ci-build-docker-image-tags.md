# ECR Image Tagging — Problem & Solution

## Problem

After re-running the "Build and Push Images to ECR" pipeline, older image tags disappeared from the ECR repository (`ecs-demo/cron-report`) 

Before:
![ci-issue-solution](../images/ci-issue-solution.png)

After rerun:
![ci-tags-issue](../images/ci-tags-issue.png)

### Root causes identified

- **Tag reuse on re-run of the same commit**
  - Image tag was set from the short git SHA: `IMAGE_TAG=${GITHUB_SHA::7}`.
  - Re-running the workflow (`workflow_dispatch`) without a new commit means `GITHUB_SHA` is identical to the previous run.
  - ECR repositories are **mutable by default** — pushing to an existing tag does not create a new tagged image, it **overwrites the tag pointer** to the new digest.
  - The image the tag previously pointed to isn't deleted, but it becomes **untagged / orphaned** (shown as `-` in the Image tags column).

- **Active lifecycle policy silently cleaning up**
  - A lifecycle policy was running in the background, expiring untagged and/or excess tagged images.
  - This was actively reducing the image count before it was manually deleted, which is why the drop looked sudden.

- **Fewer manifests per push (secondary factor)**
  - Buildx by default pushes both an image manifest and an attestation/provenance (SBOM) manifest (`Image Index` + `Other` types).
  - If `provenance`/`sbom` are disabled, each push produces one manifest instead of two, so the repo naturally accumulates fewer rows per run even without any deletion happening.

### Why this matters

- Rolling back to "the image from 3 deploys ago" becomes unreliable if that image's tag has already been silently overwritten by a later run on the same commit.
- Debugging "which image is actually running in production" becomes ambiguous when tags are mutable and reused.

## Solution — How real organizations handle this

### 1. Multi-tag strategy (push several tags per build, same digest)

```yaml
tags: |
  ${{ registry }}/${{ repo }}:${{ github.sha }}                          # full SHA - immutable audit trail
  ${{ registry }}/${{ repo }}:${{ github.sha }}-${{ github.run_number }} # unique per pipeline run
  ${{ registry }}/${{ repo }}:${{ env.BRANCH_NAME }}                     # rolling pointer per branch
  ${{ registry }}/${{ repo }}:${{ steps.version.outputs.semver }}        # e.g. v2.4.1, for actual releases
```

- **Full SHA** — used by deploy manifests (ECS task defs, Helm, Terraform) for exact traceability back to a commit; avoids short-SHA collision risk at scale.
- **SHA + run number** — guarantees a unique tag even when re-running the same commit.
- **Branch tag** — rolling pointer per environment/branch, instead of a single global `latest`.
- **Semver tag** — for genuine releases, cut from a git tag, not every commit.
- Many organizations **avoid using `:latest`** in production repos entirely, since it's the main source of "which image is actually running" confusion.

### 2. Enable immutable tags on the ECR repository

- Set **Image tag mutability = Immutable** on repos beyond dev/sandbox.
- A second push to an existing tag is then **rejected outright** by ECR, instead of silently overwriting it.
- This forces CI to always mint a genuinely new tag per build — enforcing the discipline described above at the infrastructure level, not just by convention.
- **Trade-off:** a `buildcache` tag needs to be overwritten every run, which breaks under immutable mode. Standard fix: keep build cache in **GitHub Actions cache (`type=gha`)** instead of pushing a `buildcache` tag into the same (now-immutable) release repo — or push cache to a separate, mutable-tagged cache-only repo.

### 3. Deployments reference the immutable digest or full SHA — never a mutable tag

- ECS task definitions, Helm values, and Terraform configs should pin to `image@sha256:...` or the full commit SHA tag — never `:latest` or a branch tag.
- This ensures the deploy path can never be affected by a mutable/convenience tag being reassigned or pruned later.

### 4. Lifecycle policy — always on, managed as code

- Kept permanently active (not manually toggled), typically with two rules:
  - Expire **untagged** images after a short grace window (e.g. 7 days) — cleans up orphaned tags and cache blobs.
  - Keep the **last N tagged** images — bounds repo growth while preserving a rollback window.
- Applied via Terraform/CDK across **all service repos at once**, rather than manually configured per repo in the console — required once there are more than 2–3 services/repos to manage.

### 5. Rollback relies on deploy/release history, not the ECR image list

- ECR is treated as a **content-addressable artifact store with a retention window**, not a permanent audit log.
- The actual audit trail is git history + CI workflow run history + deployment history (e.g. ECS task definition revisions, ArgoCD/Helm release history) — all referencing the SHA, which stays reproducible even if the built artifact is eventually pruned.


### Problem: Handle the "Same Commit Rebuilt" Edge Case

![ci-tags-issue-2](../images/ci-tags-issue-2.png)

- After enabling immutable tags, re-running the pipeline on the same commit produced ONE image with MULTIPLE tags (e.g. `81da6b4-29`, `81da6b4-30`, `e8e0ede`) — all pointing to the same digest.
- Later, pushing a genuinely NEW commit (`707447f`) still landed on the SAME existing digest, adding yet another tag to the same image instead of creating a new one.
- This is NOT a bug — it's expected, content-addressed behavior:
  - Docker builds are content-based, not commit-based. The digest is a hash of the final image layers, not of git history.
  - Same build inputs (files inside the build context) → same layers → same digest, regardless of which commit or how many times it's built.
  - ECR immutability blocks overwriting an EXISTING tag, but still allows attaching a NEW tag name to an EXISTING digest.
  - Result: new tag gets added to the same image instead of creating a duplicate or overwriting anything.

Why a new commit still produced the same digest:

- The commit almost certainly changed something OUTSIDE this service's build context (e.g. `context: services/cron-report`) — such as a different service's folder, a root-level file (README, `.github/workflows/`), or docs.
- Other possible causes: change excluded by `.dockerignore`, a comment/whitespace-only change, or a source change whose compiled/bundled output is byte-identical.
- No build arg or label currently embeds the commit SHA into the image, so nothing forces the digest to change per commit.

How to confirm the cause:

- Run: `git diff <old-sha> <new-sha> -- services/cron-report/`
- Empty result → confirms the build context genuinely didn't change; current behavior is expected and correct.
- Non-empty result → worth investigating further (e.g. `.dockerignore` misconfiguration).

Optional controls organizations add to make this intentional (not just incidental):

- Duplicate-build guard — check if an image already exists for the current SHA before building; skip build if so.
- Trigger restriction — use `push` on protected branches as the primary trigger (one commit = one build); keep `workflow_dispatch` as a gated, exceptional fallback.
- Concurrency groups — prevent two runs on the same ref from racing and pushing at the same time.
- Digest pinning in deploy manifests — record `service: digest` pairs so drift between "what SHA I think I deployed" and "what's actually running" is caught by a diff, not manual inspection.

Optional fix if per-commit uniqueness is required regardless of content:

- Bake the commit SHA into the image as a label so the digest always changes, even when build output is otherwise identical:
```dockerfile
  ARG GIT_SHA
  LABEL org.opencontainers.image.revision=$GIT_SHA
```
```yaml
  build-args: |
    GIT_SHA=${{ github.sha }}
```
- Trade-off: guarantees strict 1:1 commit-to-image traceability (useful for audit-heavy orgs) at the cost of losing the storage/build-time efficiency of content-addressed reuse.

## Summary comparison

| Area | Before (current setup) | After (org best practice) |
|---|---|---|
| Tagging | Mutable tag, short SHA only, reused on re-run | Immutable tags: full SHA + run number + branch + semver |
| Repo mutability | Mutable (default) | Immutable, enforced at repo level |
| Build cache | `buildcache` tag pushed into same repo | Moved to GitHub Actions cache (`type=gha`) or a separate cache-only repo |
| Lifecycle policy | Manually toggled on/off | Always-on, IaC-managed across all repos |
| Deploy reference | Likely `:latest` or short-SHA tag | Full SHA or digest — never a mutable tag |
| Rollback method | Scrolling through ECR image list | Deploy/release history (task def revisions, Helm/Argo releases) |