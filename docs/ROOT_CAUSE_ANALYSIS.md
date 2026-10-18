# Root Cause Analysis — Java CI/CD & GitOps Platform

**Project:** [java-maven-sonar-argocd-helm-k8s](https://github.com/minabisa/java-maven-sonar-argocd-helm-k8s)  
**Environment:** Jenkins and SonarQube on AWS EC2; Java 17 / Maven; Docker Hub; Argo CD and Kubernetes on local Minikube  
**Document type:** Engineering incident retrospective  
**Scope:** Issues observed while building and validating the project. Some diagnoses are inferred from error messages rather than independently verified with system logs.

## 1. Executive summary

I implemented an end-to-end CI/CD and GitOps workflow: GitHub → Jenkins → Maven tests → SonarQube Quality Gate → Docker Hub → GitHub Kubernetes manifests → Argo CD → Minikube. During integration I encountered failures involving runtime compatibility, scanner configuration, container permissions, credentials, GitOps manifests, service networking, and webhook-triggered build loops. I isolated each failure using Jenkins console output, targeted CLI checks, and Kubernetes/Argo CD status messages. The application ultimately reached **Healthy** in Argo CD and was accessible via `kubectl port-forward`; the CI pipeline also completed successfully.

## 2. Incident register

| ID | Component | Observed symptom | Root cause / assessment | Resolution |
|---|---|---|---|---|
| RCA-01 | Maven / Jenkins agent | `release version 17 not supported` | Agent JDK older than the project's Java 17 target (**confirmed by fix**) | Switched Maven agent to `maven:3.9-eclipse-temurin-17` |
| RCA-02 | SonarScanner | `No plugin found for prefix 'sonar'` | Maven could not resolve shorthand plugin prefix (**confirmed by error**) | Used fully qualified `org.sonarsource.scanner.maven:sonar-maven-plugin:sonar` |
| RCA-03 | SonarQube connectivity | Malformed URL `http://http://.../:9000/...` | Invalid Jenkins SonarQube server URL (**confirmed**) | Corrected configured URL to `http://<server>:9000` |
| RCA-04 | SonarScanner filesystem | `AccessDeniedException: /.sonar` | Scanner attempted to create cache at unwritable filesystem root (**confirmed**) | Set `sonar.userHome` to writable workspace directory |
| RCA-05 | Jenkins integration | `SonarQube installation ... does not match any configured installation` | Name mismatch between `withSonarQubeEnv(...)` and configured server (**confirmed**) | Aligned pipeline name with Jenkins server entry |
| RCA-06 | Quality Gate | Task `PENDING` followed by 10-minute timeout | Processing delay or missing webhook; **exact cause not proven** | Checked task state and webhook; later run returned `SUCCESS`, Quality Gate `OK` |
| RCA-07 | Docker / Jenkins | `docker: not found` during build and `docker inspect` | Maven Docker agent lacked Docker CLI; stage-level Docker agent was being launched from nested container context (**supported by logs**) | Used host-level `agent any` for Docker build/push and Maven Docker agents for build/scan |
| RCA-08 | Docker Hub | `access token has insufficient scopes` | Token lacked required repository push authorization (**strongly indicated**) | Updated Jenkins Docker Hub credential with appropriate read/write token |
| RCA-09 | Argo CD cluster | `cluster "Minikube Kubernetes cluster" not found` | Human-readable label entered where API server URL required (**confirmed**) | Used `https://kubernetes.default.svc` for in-cluster destination |
| RCA-10 | Kubernetes Deployment | `spec.template.spec.containers: Required value` | Missing/misindented container list (**confirmed**) | Corrected YAML under `spec.template.spec.containers` |
| RCA-11 | Git collaboration | Merge/rebase conflict in `deployment.yml`; push rejected `fetch first` | Jenkins pushed manifest changes while local branch lagged (**supported by workflow**) | Resolved YAML conflict; `git pull --rebase origin main`, then pushed |
| RCA-12 | Kubernetes networking | `Service ... does not have a service port 8080` | Port-forward used container port rather than actual Service port (**confirmed**) | Forwarded local 8080 to Service port 80: `8080:80` |
| RCA-13 | Maven unit test | Expected `Version 2!`, actual `hello CI/CD with mina bisa` | Test expectation and application return value diverged (**confirmed**) | Updated application response to match test; reran tests |
| RCA-14 | GitHub / Jenkins | Repeated builds after successful pipeline | Jenkins manifest commit generated another GitHub push event (**likely, consistent with configuration**) | Disabled webhook trigger temporarily; added SCM Skip handling for `[skip ci]` commits; re-enable only after verifying behavior |

## 3. Selected incident deep dives

### RCA-01 — Java build toolchain mismatch

**Impact:** Jenkins stopped at Maven compilation; later stages did not run.  
**Evidence:** `release version 17 not supported`.  
**Analysis:** The `pom.xml` targets Java 17, but the original Jenkins Docker agent used an incompatible JDK. A Maven image name alone does not guarantee the compiler version.  
**Fix:** Use `maven:3.9-eclipse-temurin-17` and verify with `java -version`, `javac -version`, `mvn -version`.  
**Prevention:** Pin the JDK in CI and add an early toolchain-version check.

### RCA-04 — SonarScanner cache permission denied

**Impact:** Static analysis failed before quality evaluation.  
**Evidence:** `java.nio.file.AccessDeniedException: /.sonar`.  
**Analysis:** The scanner attempted to write to `/.sonar` from a restricted container filesystem. This was a filesystem permissions issue, not a Java compilation issue.  
**Fix:** Create `$WORKSPACE/.sonar` and set `-Dsonar.userHome="$WORKSPACE/.sonar"`.  
**Prevention:** Explicitly configure writable cache directories for tools running in containers; avoid assuming the container's home directory is writable.

### RCA-06 — Quality Gate timeout

**Impact:** Jenkins waited 10 minutes and canceled `waitForQualityGate`.  
**Evidence:** Task reported `PENDING`; later a different task transitioned from `PENDING` to `SUCCESS`, and Jenkins reported `Quality gate is 'OK'`.  
**Analysis:** A pending task can indicate queued Compute Engine processing. A missing or unreachable SonarQube-to-Jenkins webhook can also prevent the waiting step from receiving completion events. The supplied logs do not prove which condition caused the original timeout.  
**Resolution/verification:** Inspected task state with `/api/ce/task?id=<task-id>`; later observed a successful Quality Gate.  
**Prevention:** Configure and test the webhook ending in `/sonarqube-webhook/`, monitor background task queue and container resources, and retain bounded timeouts.

### RCA-07 — Docker command unavailable inside Jenkins agent

**Impact:** Docker image build did not start.  
**Evidence:** `docker: not found` and `docker inspect ... docker:27-cli` failed; `sudo -u jenkins docker ps` succeeded on EC2.  
**Analysis:** The host had Docker installed and Jenkins had access to the daemon, but the Maven container did not contain the Docker CLI. Mounting `/var/run/docker.sock` alone does not install the client. The attempted nested stage-level Docker agent still required a Docker command in its execution context.  
**Fix:** Run Docker build/push stages on the EC2 Jenkins host (`agent any`) and use a Maven Docker agent only for Java/analysis stages.  
**Prevention:** Document where commands execute (host vs container) and validate CLI availability before stages run. Docker socket access is privileged; use a dedicated trusted agent.

### RCA-10 — Invalid Kubernetes Deployment manifest

**Impact:** Argo CD could not apply the Deployment; sync failed.  
**Evidence:** `Deployment.apps "spring-boot-app" is invalid: spec.template.spec.containers: Required value`.  
**Analysis:** The Deployment pod template lacked a valid `containers` array. Argo CD connected to Git successfully; the error was Kubernetes schema validation, not repository access.  
**Fix:** Define `spec.template.spec.containers` with image, name, and port; validate with `kubectl apply --dry-run=client --validate=true -f spring-boot-app-manifests/deployment.yml`.  
**Prevention:** Add Kubernetes manifest linting/schema validation to CI before pushing GitOps changes.

### RCA-14 — GitHub webhook feedback loop

**Impact:** Jenkins repeatedly started new builds, consuming time and resources.  
**Evidence:** Jenkins both listened to GitHub push events and committed image-tag changes back to the same repository.  
**Analysis:** Each image-tag commit was another push event. `[skip ci]` in the commit message is only a convention; a standard Jenkins Pipeline does not automatically honor it.  
**Containment:** Disable GitHub build trigger and cancel queued builds.  
**Mitigation implemented:** Added an SCM Skip step to detect `[skip ci]` on manifest-update commits. **Effectiveness after re-enabling the trigger was not verified in the supplied conversation.**  
**Preferred long-term prevention:** Use separate application and GitOps repositories, or reliable webhook/path filtering; also consider skipping the image update when no source changes require a new build.

## 4. Diagnostic commands used

```bash
# Confirm Java and Maven runtime
java -version
javac -version
mvn -version

# Confirm Jenkins host Docker access
which docker
sudo -u jenkins docker ps

# Inspect SonarQube background task
curl -s 'http://localhost:9000/api/ce/task?id=<TASK_ID>'
sudo docker logs --tail 100 sonarqube

# Validate and inspect Kubernetes workloads
kubectl apply --dry-run=client --validate=true -f spring-boot-app-manifests/deployment.yml
kubectl get pods,deployments,services
kubectl describe deployment spring-boot-app
kubectl rollout status deployment/spring-boot-app

# Check Argo CD Application sync result
kubectl -n argocd get application java-maven-sonar-argocd-helm-k8s \
  -o jsonpath='{.status.operationState.message}{"\n"}'

# Integrate Jenkins-generated commits without overwriting remote history
git pull --rebase origin main
git push origin main
```

## 5. Corrective and preventive actions

| Priority | Action | Reason |
|---|---|---|
| High | Confirm webhook-trigger skip behavior before re-enabling automation | Avoid build loops |
| High | Separate application source and GitOps manifests into different repositories (recommended) | Avoid CI self-triggering |
| High | Add Maven tests and Kubernetes manifest validation to CI | Fail early before release |
| Medium | Pin CI tool versions and verify Java/Docker CLI availability | Prevent environment drift |
| Medium | Use dedicated least-privilege Jenkins credentials and rotate exposed tokens | Reduce credential risk |
| Medium | Monitor SonarQube Compute Engine and webhook delivery | Reduce Quality Gate timeouts |
| Medium | Review Docker socket access and move builds to a dedicated trusted agent | Reduce host security exposure |
| Low | Keep runbooks for port-forwarding, Argo CD status, and Git rebases | Speed up troubleshooting |

## 6. Outcome and engineering lessons

**Observed successful outcomes:** Maven/CI pipeline success; SonarQube Quality Gate `OK`; Docker image published; Argo CD application became Healthy; application was accessible through the Kubernetes Service.  
**Not fully verified:** Long-term reliability of webhook-loop prevention and unattended end-to-end triggering after the SCM Skip change.

The main lesson was to isolate failures by **layer**: build toolchain → scanner/plugin → network/configuration → filesystem permissions → container runtime → registry authorization → Kubernetes schema → GitOps reconciliation → automation triggers. Reading the first meaningful exception and validating the execution environment was more effective than changing multiple components at once.

---

*Prepared as a technical retrospective based on observed pipeline logs and troubleshooting notes. Replace generic placeholders and add screenshots/log excerpts if publishing as an external case study.*
