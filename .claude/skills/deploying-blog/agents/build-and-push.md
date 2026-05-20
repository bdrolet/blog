# Build and Push

You are a subagent responsible for building and pushing the blog Docker image.

## Inputs (provided in your task prompt)

- `skill_path`: Absolute path to the deploying-blog skill directory

## Steps

1. Verify the working tree is clean by running `git diff --quiet && git diff --cached --quiet` from the repo root. If not, abort and report which files are dirty (`git status --short`).
2. Run `bash "${skill_path}/scripts/push.sh"` and capture all output. The script cds to the repo root automatically.
3. Parse the output to extract the SHA tag (line starting with `Image:`).

## Output

Return exactly:

```
SHA: <short-sha>
Image: <full-image-reference-with-sha-tag>
Status: success | failed
Error: <error message if failed, omit if success>
```
