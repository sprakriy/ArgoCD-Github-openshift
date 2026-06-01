# ArgoCD-Github-openshift
to integrate aws github with openshift using ArgoCD
Markdown
# GitOps Infrastructure Control Plane: ArgoCD, Tekton, and Terraform

This repository documents the architecture and implementation of a zero-trust, GitOps-driven infrastructure automation pipeline running inside a local `k3d` Kubernetes cluster. The framework coordinates **ArgoCD** for lifecycle tracking and **Tekton Pipelines** to securely execute isolated `terraform apply` and `terraform destroy` workflows against AWS using short-lived STS tokens.

---

## 🏗️ Architectural Overview

This design isolates cloud infrastructure manipulation from developer workstations. Instead of running Terraform locally, the workflow operates through a cluster-bound pipeline:

1. **ArgoCD** continuously syncs the infrastructure definition pipeline resources from GitHub.
2. An engineering action (Git Commit/Sync) triggers a Tekton **TaskRun** utilizing specialized lifecycle hooks.
3. The temporary Tekton pod mounts verified, short-lived **AWS STS Credentials** from cluster secrets.
4. An ephemeral, cached workspace (`tf-pvc`) clones target code configurations and securely finishes execution.

---

## 🛠️ Cluster Initialization & Setup

### 1. Cluster Stabilization (WSL Engine Recovery)
If your local environment experiences network dropouts (`EOF`) or Docker daemon resets, recover and query your `k3d` backend using the following sequences:

```bash
# Restart the base WSL host virtualization engine
sudo service docker restart

# Recover and verify your dedicated target cluster topology
k3d cluster start mycluster

# Verify cluster host capacity allocations
kubectl top nodes
2. Tekton Pipeline Engine Installation
Deploy the core pipeline controllers directly from the official Google release repositories using the no-tag resource definitions:

Bash
# Clean out older, conflicting pipeline versions if present
kubectl delete -f [https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.60.2/release.notags.yaml](https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.60.2/release.notags.yaml) --ignore-not-found

# Download and apply the stabilized Tekton compilation manifests
curl -L -o tekton-latest-release.yaml [https://storage.googleapis.com/tekton-releases/pipeline/latest/release.notags.yaml](https://storage.googleapis.com/tekton-releases/pipeline/latest/release.notags.yaml)
kubectl apply -f tekton-latest-release.yaml

# Watch core execution services transition into a stable state
kubectl get pods -n tekton-pipelines -w
🔒 Configuration & Pipeline Assembly
1. Provision Core Workspace Storage
Create the shared scratchpad storage volume mapped for checking out remote configurations:

Bash
kubectl apply -f tekton/pvc.yaml
2. Inject Ephemeral Cloud Security Tokens (AWS STS)
Generate fresh, temporary access tokens via your AWS CLI and construct a native Kubernetes secret inside your automated gateway.

Execute the token generation command:

Bash
aws sts get-session-token --duration-seconds 43200
Map the JSON output values into a Secret manifest named aws-creds within the tf-automation-gate namespace:

YAML
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: tf-automation-gate
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <BASE64_ENCODED_ACCESS_KEY>
  AWS_SECRET_ACCESS_KEY: <BASE64_ENCODED_SECRET_KEY>
  AWS_SESSION_TOKEN: <BASE64_ENCODED_SESSION_TOKEN>
3. Deploy the Pipeline Task Engine
Apply the custom Terraform runner task that contains your operational logic, parameters, and variable substitutions:

Bash
kubectl apply -f tekton/tasks/terraform-task.yaml
🚀 Execution & GitOps Integration
The pipeline uses explicit ArgoCD Sync Hooks to automate lifecycles. By defining argocd.argoproj.io/hook: Sync paired with a BeforeHookCreation deletion policy, ArgoCD will cleanly purge old execution metadata automatically before launching a new container instance.

The Lifecycle Blueprint (tekton/runs/infra-run.yaml)
YAML
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: terraform-infra-run
  namespace: tf-automation-gate
  annotations:
    argocd.argoproj.io/hook: Sync                       # Triggers execution exclusively during app synchronization
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation # Automatically cleans out old runs
spec:
  serviceAccountName: tf-runner-sa                      # Custom account linked to aws-creds
  taskRef:
    name: terraform-executor                            # Points to our verified Task Engine
  params:
    - name: git-url
      value: "[https://github.com/sprakriy/ci-cd-testing.git](https://github.com/sprakriy/ci-cd-testing.git)"
    - name: terraform-dir
      value: "."                                        # Root-level configuration directory
    - name: action
      value: "destroy"                                  # Toggle to 'apply' or 'destroy' for environment control
  workspaces:
    - name: source
      persistentVolumeClaim:
        claimName: tf-pvc
Triggering Operations
Execute the resource template via the terminal to trigger manual orchestration testing, or let ArgoCD's automated manager intercept changes pushed to your tracking tracking directories:

Bash
kubectl apply -f tekton/runs/infra-run.yaml
Stream Pipeline Progress Live
Track and stream log output logs directly from the running Terraform initialization container using the exact resource identifier:

Bash
oc logs -f taskrun/terraform-infra-run -n tf-automation-gate -c step-tf-init-execute# Triggering automated test run
