#!/bin/bash
set -e

number_clusters=$(awk -F '=' '/^number_k8s/ {gsub(/[[:space:]]/, "", $2); print $2}' 00-config.toml)

for ((i=0; i<number_clusters; i++)); do
    suffix=$(printf "%02d" "$i")

    echo "Deleting cluster ${suffix}......"

    python3 ./delete-cluster.py "$suffix" &
    
	sleep 1
done

wait

echo "All Kubernetes clusters have been deleted."