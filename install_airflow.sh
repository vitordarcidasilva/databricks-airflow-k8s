# Create or replace a kind cluster
kind delete cluster --name kind
kind create cluster --image kindest/node:v1.29.4 --config k8s/clusters/kind-cluster.yaml

# Add airflow to my Helm repo
helm repo add apache-airflow https://airflow.apache.org
helm repo update
helm show values apache-airflow/airflow > chart/values-example.yaml

# Load required images into kind cluster
docker pull postgres:16
kind load docker-image postgres:16 --name kind

docker pull quay.io/prometheus/statsd-exporter:v0.28.0
kind load docker-image quay.io/prometheus/statsd-exporter:v0.28.0 --name kind


# Export values for Airflow docker image
export IMAGE_NAME=my-dags
export IMAGE_TAG=$(date +%Y%m%d%H%M%S)
export NAMESPACE=airflow
export RELEASE_NAME=airflow

# Build the image and load it into kind
docker build --pull --tag $IMAGE_NAME:$IMAGE_TAG -f cicd/Dockerfile .
kind load docker-image $IMAGE_NAME:$IMAGE_TAG --name kind

# Create a namespace
kubectl create namespace $NAMESPACE

# Apply kubernetes secrets
kubectl apply -f k8s/secrets/git-secrets.yaml

# Create logs directory in kind nodes and set correct permissions for Airflow (UID 50000)
docker exec kind-control-plane mkdir -p /mnt/airflow-data/logs
docker exec kind-control-plane chown -R 50000:0 /mnt/airflow-data/logs
docker exec kind-worker mkdir -p /mnt/airflow-data/logs
docker exec kind-worker chown -R 50000:0 /mnt/airflow-data/logs

kubectl apply -f k8s/volumes/airflow-logs-pv.yaml
kubectl apply -f k8s/volumes/airflow-logs-pvc.yaml

# Install Airflow using Helm
helm install $RELEASE_NAME apache-airflow/airflow \
    --namespace $NAMESPACE -f chart/values-override-persistence.yaml \
    --set postgresql.image.repository=postgres \
    --set postgresql.image.tag=16 \
    --set-string images.airflow.tag="$IMAGE_TAG" \
    --debug

# Port forward the API server
kubectl port-forward svc/$RELEASE_NAME-api-server 8080:8080 --namespace $NAMESPACE