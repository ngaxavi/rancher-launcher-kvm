# Rancher Launcher KVM

A easy way to get a Rancher Kubernetes cluster up and running on KVM/Libvirt.
Make sure that you have installed **PYTHON**, **RKE** and **HELM**.

Download the ISO image for VM

> Currently the centos 7 image is only supported. The installation of VM with other images will be added later

```bash
python download-image.py
```

This script will create machines in KVM prepared with docker and ssh key. It will also generate a cluster.yml that can be used by RKE to provision a Kubernetes cluster. This cluster can then be joined to a Rancher manager UI.

Create 3 nodes by running.

```bash
chmod +x provision.sh

./provision.sh 3
```

You will end up with 3 virtual machines having a user named rke with the SSH keys found in ~/.ssh/ on your host. Also, a cluster.yml will be generated.

By default, all nodes will be running etcd, controlplane and worker containers. Edit cluster.yml to change this to your liking.

Then, simply run the following commands

```bash
cd scripts && chmod +x install_rancher_server.sh

./install_rancher_server.sh
```

Go take a coffee 😊 it takes several minutes to set up the cluster and the Rancher UI.

When it finished navigate to your specified rancher url and enjoy it 🚀 💯 .
