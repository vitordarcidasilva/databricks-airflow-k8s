# Export values for Airflow docker image
export IMAGE_NAME=my-dags
export IMAGE_TAG=v$(date +%Y%m%d%H%M%S)
export NAMESPACE=airflow
export RELEASE_NAME=airflow

# Build the image and load it into kind
docker build --pull --tag $IMAGE_NAME:$IMAGE_TAG -f cicd/Dockerfile .
kind load docker-image $IMAGE_NAME:$IMAGE_TAG

# Upgrade Airflow using Helm
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow \
  -f chart/values-override.yaml \
  --set postgresql.image.repository=postgres \
  --set postgresql.image.tag=16 \
  --set images.airflow.tag=$IMAGE_TAG \
  --set images.airflow.pullPolicy=IfNotPresent \
  --timeout 15m \
  --debug


# Port forward the API server
kubectl port-forward svc/$RELEASE_NAME-api-server 8080:8080 --namespace $NAMESPACE