#!/bin/bash

if [[ ! $@ =~ master|worker ]]
then
    echo "Specify goal for current device (master or worker)"
    exit 1
fi

function does_program_exists {
    type "$1" &> /dev/null
}

not_installed_dependencies=()

if ! does_program_exists docker
then
    not_installed_dependencies+=("Docker")
fi

if ! does_program_exists kubeadm
then
    not_installed_dependencies+=("Kubeadm")
fi

if ! does_program_exists kubelet
then
    not_installed_dependencies+=("Kubelet")
fi

if ! does_program_exists kubectl
then
    not_installed_dependencies+=("Kubectl")
fi

prerequirements_error=false

if [ ${#not_installed_dependencies[@]} -ne 0 ]
then
    echo "Please install the following dependencies:"
    for value in "${not_installed_dependencies[@]}"
    do
        echo "- $value"
    done
    prerequirements_error=true
fi

swaps=$( cat /proc/swaps )

if [[ ${#swaps} -gt 50 ]]
then
    echo "Please disable swap permanently."
    prerequirements_error=true
fi

if $prerequirements_error
then
    exit 1
fi

user_groups=$(groups)

if [[ ! ${user_groups[@]} =~ "docker" ]]
then
    sudo usermod -a -G docker $USER
    echo "Please log out and log back in again to pick up the new docker group permissions. Then run script again"
    exit 1
fi

if [[ $@ =~ "master" ]]
then
    if [[ $@ =~ "--ignore-preflight-errors" ]]
    then
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all
    else
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16
    fi

    kubeadm_init_status=$?

    if [ $kubeadm_init_status -ne 0 ]
    then
        echo "Kubeadm initialization failed. Try to fix all pre-flight errors. If you know what you are doing, you can ignore pre-flight errors with flag --ignore-preflight-errors"
        exit 1
    fi

    mkdir -p $HOME/.kube

    sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chmod 777 $HOME/.kube/config
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
else
    join_command=$(kubeadm token create --print-join-command | grep "kubeadm join")
    sudo $join_command
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
fi
