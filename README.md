### from [argo docs](https://argo-cd.readthedocs.io/en/stable/)

#### argocd installation

```
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### Use the following command to retrieve password:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

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
