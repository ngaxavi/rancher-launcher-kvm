
source ../util.sh

explain "Make sure that you are install kubectl, rke and helm"
sleep 10s

explain "Give the hostname for rancher (e.g. rancher.example.com):"
read rancher_hostname

explain "Run RKE"
tell rke up --config ../cluster.yml

explain "Add the helm Chart Repository"
tell helm --kubeconfig ../kube_config_cluster.yml repo add rancher-stable https://releases.rancher.com/server-charts/stable

explain "Create a namespace for Rancher"
tell kubectl --kubeconfig ../kube_config_cluster.yml create namespace cattle-system

explain "Installation cert-manager"
tell kubectl --kubeconfig ../kube_config_cluster.yml apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml
tell kubectl --kubeconfig ../kube_config_cluster.yml create namespace cert-manager
tell helm --kubeconfig ../kube_config_cluster.yml repo add jetstack https://charts.jetstack.io
tell helm --kubeconfig ../kube_config_cluster.yml repo update
tell helm --kubeconfig ../kube_config_cluster.yml install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.0.4
tell kubectl --kubeconfig ../kube_config_cluster.yml -n cert-manager rollout status deploy/cert-manager

explain "Install Rancher with Helm and Your Chosen Certificate Optionlink"
tell helm --kubeconfig ../kube_config_cluster.yml install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=$rancher_hostname

explain "Verify that the Rancher Server is Succcessfully deployed"
tell kubectl --kubeconfig ../kube_config_cluster.yml -n cattle-system rollout status deploy/rancher

success "Navigate to the Rancher URL and enjoy :rocket:"

