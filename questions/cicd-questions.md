# CI/CD Questions

### Question: How are Docker image layers cached during the CI build process when the CI runner/VM is ephemeral, and what are the best practices for leveraging Amazon ECR as a cache source?

Context
- The CI pipeline runs on ephemeral build agents/VMs.
- Each build starts on a fresh environment with no local Docker layer cache.
- After the image is built, it is pushed to Amazon ECR.

Key Considerations
- How can image layers be reused across builds when local cache is not available?
- Can Amazon ECR be used as a remote cache source?
- What Docker BuildKit options should be used for cache import/export?
- How can build times be optimized while maintaining reproducibility?
- What are the best practices for structuring the Dockerfile to maximize cache hits?

Best Practices
- Enable Docker BuildKit.
- Use remote cache in ECR with --cache-from and --cache-to.
- Structure Dockerfiles so that infrequently changing layers (OS packages, dependencies) appear before frequently changing layers (application code).
- Use multi-stage builds to reduce image size and improve cache efficiency.
- Persist build cache in ECR or a dedicated cache registry rather than relying on local runner storage.
- Pull the latest image or cache manifest from ECR before building to maximize cache reuse across ephemeral runners.

Example Flow
- CI runner starts (empty environment).
- Pull cache/image metadata from ECR.
- Build image using remote cache.
- Only changed layers are rebuilt.
- Push updated image and cache back to ECR.
- Runner is destroyed after job completion.

This approach ensures that even though CI runners are ephemeral, Docker layer caching remains effective by using ECR as a remote cache backend.

#### My Solution

Link: [ci-cache-doc-link](docs/ci-cache.md)

Solution Flow (GitHub Actions cache + ECR)

- CI runner starts (empty, ephemeral VM — no local Docker layer cache).
- Checkout code, configure AWS credentials, login to ECR.
- Set up Docker Buildx (needed for cache-from/cache-to support).
- Pull build cache from GitHub Actions cache storage, scoped per service (type=gha, scope: matrix.service).
- Build image using Buildx with the pulled cache.
- Only changed layers are rebuilt — unchanged layers (e.g. dependency install) are reused from cache.
- Push the built image (tagged with short SHA + latest) to ECR.
- Push updated cache layers back to GitHub Actions cache (not to ECR — keeps ECR clean of buildcache clutter).
- Runner is destroyed after job completion — next run starts fresh but re-pulls the same GHA-scoped cache.

### Question: After re-running the "Build and Push Images to ECR" pipeline, older image tags disappeared from the ECR repository. Why did this happen, and how can it be resolved?

Symptoms
- Older image tags are no longer visible in the Amazon ECR repository.
- Only the latest image tag remains after the pipeline execution.
- Historical image versions cannot be pulled using previous tags.

Possible Reasons
1. ECR Lifecycle Policy Automatically Deleted Older Images

- A lifecycle policy may be configured to retain only a limited number of images (for example, keeping only the latest image and expiring older ones).

```
{
  "rulePriority": 1,
  "selection": {
    "tagStatus": "any",
    "countType": "imageCountMoreThan",
    "countNumber": 1
  },
  "action": {
    "type": "expire"
  }
}
```
Impact: Only the most recent image is retained, and older images are deleted automatically.

Solution:

- Review ECR Lifecycle Policies.
- Increase the retention count.
- Retain images based on age or tag patterns instead of keeping only one image.

2. Tags Are Being Overwritten

- ECR repositories are **mutable by default**.
- There is no new commit resulting in the existing image being overwritten.
- The image the tag previously pointed to isn't deleted, but it becomes **untagged / orphaned** (shown as `-` in the Image tags column). 

Impact: Previous images may become untagged and subsequently deleted by lifecycle policies.

Solution:

Use unique tags for every build.

Example:
- Build Number
- Git Commit SHA
- Release Version

#### My solution

link: [ci-build-docker-image-tags](docs/ci-build-docker-image-tags.md)

Solution Flow (Immutable Tagging + ECR)

- CI runner starts (empty, ephemeral VM — no memory of previous runs).
- Checkout code, configure AWS credentials, login to ECR.
- Compute a unique image identity: full git SHA + workflow run number (not short SHA alone).
- Build image using Buildx (with GHA cache from the caching flow, unchanged).
- Tag the image with multiple purpose-specific tags: full SHA, SHA+run-number, branch name, and semver (if applicable) — never only `latest`.
- Push image to ECR — since the repo is set to Immutable, ECR rejects any push that would overwrite an existing tag.
- If tag already exists (e.g. re-run on same commit with no run-number suffix), push fails fast instead of silently overwriting — surfacing the mistake immediately rather than losing history.
- Deploy step references the full SHA tag (or digest) explicitly — never a mutable/floating tag like `latest` or branch name.
- Old images are not deleted by re-runs — they simply accumulate under distinct tags.
- Lifecycle policy (always-on, IaC-managed) later expires old untagged/excess tagged images on a schedule — not as a side effect of a new push.