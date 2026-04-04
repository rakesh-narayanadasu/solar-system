# Install KIND

curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64

chmod +x kind
sudo mv kind /usr/local/bin/

kind --version

kind create cluster

kubectl get nodes

kind create cluster --config kind-config.yaml

kind delete cluster

# ArgoCD

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl get pods -n argocd

kubectl port-forward svc/argocd-server -n argocd 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d && echo


# Bitnami Sealed Secrets

kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml

kubectl get pods -n kube-system | grep sealed-secrets

# Install kubeseal CLI

export KUBESEAL_VERSION="0.23.0"
wget -O kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz \
  "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

kubeseal --version
