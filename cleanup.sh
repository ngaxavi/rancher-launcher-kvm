#!/bin/bash

virsh undefine k8s-1 --remove-all-storage
virsh undefine k8s-2 --remove-all-storage
virsh undefine k8s-3 --remove-all-storage