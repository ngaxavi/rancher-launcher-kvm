#!/bin/bash
source ./provision.vars
source ./util.sh

add_node_to_cluster() {
  local VM_IP=$((110 + $1))

  echo "  - address: "192.168.122.$VM_IP"
    user: rke
    ssh_key_path: ~/.ssh/id_rsa
    role: [controlplane, worker, etcd]" >> cluster.yml
}

create_vm () {
  local VM_NB=$1
  local VM_KS="ks-$VM_NB.cfg"
  local VM_IP=$((110 + $VM_NB))
  local VM_PORT=$((5900 + $VM_NB))

  explain "Using port $VM_PORT"

  explain "Cleaning up old kickstart file..."
  tell rm -f $VM_KS

  explain "Creating new ks.cfg file..."
  tell cp ks.cfg.template $VM_KS
  tell sed -i 's/TMPL_PSWD/rancher/g' $VM_KS
  tell sed -i 's/TMPL_HOSTNAME/'$vm_prefix-$VM_NB'/g' $VM_KS
  tell sed -i 's/TMPL_IP/192.168.122.'$VM_IP'/g' $VM_KS
  tell sed -i "s;TMPL_SSH_KEY;$SSH_KEY;g" $VM_KS

  explain "Creating disc image..."
  tell qemu-img create -f qcow2 $image_location/$vm_prefix-$VM_NB.qcow2 $vm_disc_size

  explain "Creating virtual machine and running installer..."
  tell virt-install --name $vm_prefix-$VM_NB \
    --description "$vm_description-$VM_NB" \
    --ram $vm_ram \
    --vcpus $vm_vcpu \
    --disk path=$image_location/$vm_prefix-$VM_NB.qcow2,size=15 \
    --os-type linux \
    --os-variant $vm_variant \
    --network bridge=virbr0 \
    --graphics vnc,listen=127.0.0.1,port=$VM_PORT \
    --location $vm_iso \
    --noautoconsole \
    --initrd-inject $VM_KS --extra-args="ks=file:/$VM_KS" 

}

explain "Enter your cluster name (default: local)"
read k8s_name
k8s_name=${k8s_name:-local}


explain "Enter your Network Plugin (default=1)"
echo "1) Canal"
echo "2) Flannel"
echo "3) Calico"
echo "4) Weave" 
echo "5) None" 

read opt
 case $opt in
    1) k8s_network="canal";;
    2) k8s_network="flannel";;
    3) k8s_network="calico";;
    4) k8s_network="weave";;
    5) k8s_network="none";;
    *) k8s_network="canal";;
esac

# Check if ssh keys exists
if [ -f ~/.ssh/id_rsa.pub ]; then
  SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
else
  error "Public Key not found. It will be left blank..."
  SSH_KEY=""
fi

# Check if no input, then set number of servers to 1
SRV_NB=$1
if [[ -z "$SRV_NB" ]]; then
  SRV_NB=1
fi

explain "Creating Machines and Writing cluster.yml..."

if [ "$k8s_name" != "local" ]; then
  echo "cluster_name: $k8s_name" > cluster.yml
fi

if [ -n $k8s_version]; then
  echo "kubernetes_version: \"$k8s_version\"" >> cluster.yml
fi


echo "" > hosts_entries

echo "nodes:" >> cluster.yml
explain "Creating $SRV_NB of servers..."

for i in $( seq 1 $SRV_NB )
do
  explain "Creating VM $i"
  create_vm $i & 
  add_node_to_cluster $i
  echo "192.168.122.$((110 + $i)) $vm_prefix-$i" >> hosts_entries
done

# Wait for machine commands to finish
wait

# Increase timeout for addons 
# Workaround for issue : https://github.com/rancher/rke/issues/1652
echo "
addon_job_timeout: 60" >> cluster.yml

explain "Add ssh agent"
  echo "
ssh_agent_auth: true" >> cluster.yml


explain "Add Service to snapshot etcd"
echo "
services:
  etcd:
    snapshot: true
    creation: 6h
    retention: 24h" >> cluster.yml


explain "Add Network Plugin"
if [[ ("$k8s_network" != "canal") && ("$k8s_network" != "none") ]]; then
  echo "
network:
    plugin: $k8s_network" >> cluster.yml
fi

explain "Disable build in Nginx ingress if needed"
if [ "$k8s_ingress" == "false" ]; then
  echo "ingress:
      provider: none" >> cluster.yml
else
  echo "
ingress:
  provider: nginx
  options:
    use-forwarded-headers: "true"" >> cluster.yml
fi

explain "Add these entries to your hosts /etc/hosts"
cat hosts_entries

explain "

If you want to run Sonobuoy, you need to run this command after you ran rke up
kubectl label --overwrite node --selector node-role.kubernetes.io/controlplane=\"true\" node-role.kubernetes.io/master=\"true\"

Fixing issue https://github.com/vmware-tanzu/sonobuoy/issues/574
"

success "RKE Cluster and VM Creation are successfully operated"
