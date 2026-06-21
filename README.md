# Kubernetes Resource Management Lab

## Directions:
1. Clone the repository using:<br>  `git clone https://gitlab.vulcan.mil/army-software-factory/organization/sose/learning-office/practice-leads/platform-engineering/enablement/beyond-the-tech-accelerator.git`
2. Create a branch and switch to it to make changes freely:<br>
`git checkout -b <name-of-branch>`
3. Switch to docker-desktop (or other local kubernetes cluster):<br>
`kubectl config use-context docker-desktop`
4. Run the install.sh script to install ArgoCD and its CRDs:<br>
`bash install.sh`
5. To uninstall, run the uninstall.sh script:<br>
`bash uninstall.sh`

## This Lab includes the following resources:
- **bootstrap** App-in-apps configuration
- installation.yaml to pull images and create CRDs
- Helm chart with the following resource creation:
  - appProject (**ArgoCD**)
  - Application (**ArgoCD**)
  - LimitRange
  - Namespace
  - ResourceQuota
  - pre-configured *values.yaml* to deploy spoke resources
- spokes folder with a Deployment and Service
- install.sh 
- delete.sh 

## Install.sh
### Environment Variables:
**ARGO_PASSWORD**:<br> ArgoCD randomly generates a password upon creation; this sets a static password so user can log into the UI easily | default : **admin**

**PORT**:<br> port to designate for port-forward command to access via localhost | default : **8080**

### [argo docs](https://argo-cd.readthedocs.io/en/stable/)

## Below are some manual commands part of the install.sh / delete.sh script

#### argocd installation

```
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### It uses the following images:
- quay.io/argoproj/argocd:v3.4.4
- ghcr.io/dexidp/dex:v2.45.0
- public.ecr.aws/docker/library/redis:8.2.3-alpine

#### Use the following command to retrieve password:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
- Then it sets the password to be the `admin` password in the install.sh script

#### It fetches the current git credentials used to push/pull from repo
`git credential fill` [docs](https://git-scm.com/docs/git-credential#_typical_use_of_git_credential)


#### Use the following command to port-forward the ArgoCD Service to browser:

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Deletion:
- ArgoCD installation
```
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
- namespace deletion
```
kubectl delete namespace argocd
```
- manual deletion of CRDs
```
kubectl get crds | grep argoproj.io
```
- if any exists:
```
kubectl delete crd applications.argoproj.io appprojects.argoproj.io applicationsets.argoproj.io
```


#### declarative setup [guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
#### future possible work for SSO : [user management](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
