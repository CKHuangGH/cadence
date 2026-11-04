export DEBIAN_FRONTEND=noninteractive

sudo apt-get update

sudo apt-get install -y screen=4.9.1-3
sudo apt-get install -y chrony=4.6.1-3+deb13u2

sleep 5

cp /root/all_node_list .
cp /root/cp_node_list .

while IFS= read -r ip_address; do
  scp -o StrictHostKeyChecking=no ./all_node_list root@$ip_address:/root/
  scp -o StrictHostKeyChecking=no ./script/chrony.sh root@$ip_address:/root/
done < "all_node_list"

while IFS= read -r ip_address; do
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" sudo apt-get update
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" mkdir /var/log/chrony
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" sudo apt-get install -y chrony=4.6.1-3+deb13u2
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" "nohup bash /root/chrony.sh 2>&1 &"
done < "all_node_list"

sleep 30

CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
MON=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | sort -V | tail -1 | cut -d/ -f2)
LOAD=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | sort -V | tail -2 | head -1 | cut -d/ -f2)

kubectl label node "$CP" cadence-role=cp --overwrite
kubectl label node "$MON" cadence-role=monitoring --overwrite
kubectl label node "$LOAD" cadence-role=loadgen --overwrite

for NODE in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | sort -V | head -n -2); do
  kubectl label "$NODE" cadence-role=application --overwrite
done

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  -n kube-system \
  --set nodeSelector.cadence-role=cp \
  --set 'tolerations[0].key=node-role.kubernetes.io/control-plane' \
  --set 'tolerations[0].operator=Exists' \
  --set 'tolerations[0].effect=NoSchedule' \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait --timeout 5m

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.scrapeInterval=5s \
  --set prometheus.prometheusSpec.scrapeTimeout=4s \
  --set prometheus.prometheusSpec.nodeSelector.cadence-role=monitoring \
  --set prometheusOperator.nodeSelector.cadence-role=monitoring \
  --set kube-state-metrics.nodeSelector.cadence-role=monitoring \
  --wait --timeout 10m