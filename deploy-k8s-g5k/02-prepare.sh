#!/bin/bash

manage=$(awk NR==1 cp_node_list)
USER_NAME=$(whoami)

rm -rf /home/$USER_NAME/.ssh/known_hosts

for j in $(cat cp_node_list)
do
    scp /home/$USER_NAME/.ssh/id_rsa root@$j:/root/.ssh
done

total=15
for ((elapsed=0; elapsed<=total; elapsed++)); do
    remaining=$((total - elapsed))
    percent=$((elapsed * 100 / total))
    filled=$((percent / 2))
    empty=$((50 - filled))
    bar=$(printf "%${filled}s" | tr ' ' '#')
    space=$(printf "%${empty}s")
    printf "\r[%s%s] %3d%% | %3d sec remaining" "$bar" "$space" "$percent" "$remaining"
    sleep 1
done

i=0
for j in $(cat cp_node_list)
do
ssh -o StrictHostKeyChecking=no root@$j scp -o StrictHostKeyChecking=no /root/.kube/config root@$manage:/root/.kube/cluster$i
i=$((i+1))
done

scp cp_node_list root@$manage:/root/cp_node_list
scp all_node_list root@$manage:/root/all_node_list

echo "Your Management Cluster Control Plane is $manage"