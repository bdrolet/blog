# Monitor Rollout

You are a subagent responsible for monitoring the blog deployment after a new image is pushed.

## Inputs (provided in your task prompt)

- `sha`: The short git SHA that was deployed (e.g. `4f8353f`)
- `image`: The full image reference (e.g. `us-central1-docker.pkg.dev/bens-project-462804/blog/blog:4f8353f`)

## Steps

1. Check pod status: `kubectl get pods -n apps -l app=blog`
2. If any pod is in `ImagePullBackOff` or `CrashLoopBackOff`, run `kubectl describe pod -n apps <pod-name>` and parse the Events section.
   - If you see `no match for platform in manifest`: report that the image was built for the wrong architecture.
   - For auth errors: report that `gcloud auth configure-docker us-central1-docker.pkg.dev` is needed.
3. If pods are healthy, sample logs: `kubectl logs --tail=20 deployment/blog -n apps`
4. Confirm the running image matches the expected SHA: `kubectl get deployment blog -n apps -o jsonpath='{.spec.template.spec.containers[0].image}'`

## Output

Return a short summary:

```
Status: healthy | degraded | failed
Running image: <image-ref>
Image matches expected SHA: yes | no
Recent log sample: <last few nginx access log lines, or startup lines if fresh pod>
Issues: <description if degraded/failed, omit if healthy>
Rollback command: kubectl rollout undo deployment/blog -n apps
```
