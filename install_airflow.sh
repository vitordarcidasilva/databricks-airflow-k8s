# Create or replace a kind cluster
kind delete cluster --name kind
kind create cluster --image kindest/node:v1.29.4

# Add airflow to my Helm repo
helm repo add apache-airflow https://airflow.apache.org
helm repo update
helm show values apache-airflow/airflow > chart/values-example.yaml

#add postgres 
kind load docker-image postgres:16 --name kind
# Export values for Airflow docker image
export IMAGE_NAME=my-dags
export IMAGE_TAG=v$(date +%Y%m%d%H%M%S)
export NAMESPACE=airflow
export RELEASE_NAME=airflow

# Build the image and load it into kind
docker build --pull --tag $IMAGE_NAME:$IMAGE_TAG -f cicd/Dockerfile .
kind load docker-image $IMAGE_NAME:$IMAGE_TAG

# Create a namespace
kubectl create namespace $NAMESPACE

# Apply kubernetes secrets
# kubectl apply -f k8s/secrets/git-secrets.yaml

# Install Airflow using Helm
helm install airflow apache-airflow/airflow \
  --namespace airflow \
  -f chart/values-override.yaml \
  --set postgresql.image.repository=postgres \
  --set postgresql.image.tag=16 \
  --set images.airflow.tag=$IMAGE_TAG \
  --set images.airflow.pullPolicy=IfNotPresent \
  --timeout 15m

# Port forward the API server
kubectl port-forward svc/$RELEASE_NAME-api-server 8080:8080 --namespace $NAMESPACE