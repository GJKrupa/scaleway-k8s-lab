#!/usr/bin/env bash

DOMAIN=krupa.me.uk

ALL_NODES=$(scw ps | grep k8s- | awk '{print $1}')
for NODE in ${ALL_NODES}; do
	PUBLIC_IP=$(scw inspect ${NODE} | jq -r '.[0].public_ip.address')
	KUBEADM=$(ssh root@${PUBLIC_IP} "which kubeadm")
	if [[ "${KUBEADM}" == "" ]]; then
		echo "Installing packages on $NODE (${PUBLIC_IP})"
		scp install.sh root@${PUBLIC_IP}:/root/install.sh
		ssh root@${PUBLIC_IP} /root/install.sh
	else
		echo "Packages already installed on $NODE"
	fi
done

MASTER_PUBLIC_IP=$(scw inspect k8s-master | jq -r '.[0].public_ip.address')
MASTER_PRIVATE_IP=$(scw inspect k8s-master | jq -r '.[0].private_ip')
MASTER_PUBLIC_DNS=$(scw inspect k8s-master | jq -r '.[0].dns_public')
MASTER_PRIVATE_DNS=$(scw inspect k8s-master | jq -r '.[0].dns_private')

TOKEN=$(ssh root@${MASTER_PUBLIC_IP} "kubeadm token generate")

ssh root@${MASTER_PUBLIC_IP} "kubeadm reset"
ssh root@${MASTER_PUBLIC_IP} "kubeadm init \
	--apiserver-advertise-address=${MASTER_PUBLIC_IP} \
	--apiserver-cert-extra-sans=${MASTER_PUBLIC_IP},${MASTER_PRIVATE_IP},${MASTER_PUBLIC_DNS},${MASTER_PRIVATE_DNS},k8s-master.${DOMAIN} \
	--token=${TOKEN}"

WORKER_NODES=$(scw ps | grep k8s-worker | awk '{print $1}')
for NODE in ${WORKER_NODES}; do
	PUBLIC_IP=$(scw inspect ${NODE} | jq -r '.[0].public_ip.address')
	ssh root@${PUBLIC_IP} "kubeadm reset"
	ssh root@${PUBLIC_IP} "kubeadm join --token=${TOKEN} ${MASTER_PUBLIC_DNS}:6443"
done

scp root@${MASTER_PUBLIC_IP}:/etc/kubernetes/admin.conf admin.conf
sed -i bak -e "s/${MASTER_PRIVATE_IP}/k8s-master.${DOMAIN}/" admin.conf
kubectl --kubeconfig=admin.conf apply -f https://git.io/weave-kube-1.6
while [[ "$(kubectl --kubeconfig=admin.conf get nodes | grep NotReady)" != "" ]]; do
	echo Waiting for nodes to be ready
	sleep 2
done

ssh root@${MASTER_PUBLIC_IP} "curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh"
ssh root@${MASTER_PUBLIC_IP} "chmod 700 get_helm.sh"
ssh root@${MASTER_PUBLIC_IP} "./get_helm.sh"
ssh root@${MASTER_PUBLIC_IP} "mkdir -p /root/.kube"
ssh root@${MASTER_PUBLIC_IP} "cp /etc/kubernetes/admin.conf /root/.kube/config"
ssh root@${MASTER_PUBLIC_IP} "helm init"

while [[ "$(kubectl --kubeconfig=admin.conf get pods -n kube-system | grep tiller | awk '{print $3}')" != "Running" ]]; do
	echo Waiting for Tiller pod to be ready
	sleep 2
done
sleep 5

kubectl --kubeconfig=admin.conf create -f ingress-user.yaml
ssh root@${MASTER_PUBLIC_IP} "helm install --name lego --set config.LEGO_EMAIL=letsencrypt@${DOMAIN},config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory stable/kube-lego --namespace=kube-system"
ssh root@${MASTER_PUBLIC_IP} "helm install stable/nginx-ingress --name ingress --set controller.hostNetwork=true --namespace=kube-system"
