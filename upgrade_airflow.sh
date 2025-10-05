# Export values for Airflow docker image
export IMAGE_NAME=my-dags
export IMAGE_TAG=$(date +%Y%m%d%H%M%S)
export NAMESPACE=airflow
export RELEASE_NAME=airflow

# Build the image and load it into kind
docker build --pull --tag $IMAGE_NAME:$IMAGE_TAG -f cicd/Dockerfile .
kind load docker-image $IMAGE_NAME:$IMAGE_TAG --name kind

# Ensure logs directory has correct permissions (in case it was lost)
docker exec kind-control-plane chown -R 50000:0 /mnt/airflow-data/logs 2>/dev/null || true
docker exec kind-worker chown -R 50000:0 /mnt/airflow-data/logs 2>/dev/null || true

# Upgrade Airflow using Helm
helm upgrade $RELEASE_NAME apache-airflow/airflow \
    --namespace $NAMESPACE -f chart/values-override-persistence.yaml \
    --set postgresql.image.repository=postgres \
    --set postgresql.image.tag=16 \
    --set-string images.airflow.tag="$IMAGE_TAG" \
    --debug

# Wait for rollout to complete
kubectl rollout status deployment/$RELEASE_NAME-scheduler -n $NAMESPACE --timeout=120s
kubectl rollout status deployment/$RELEASE_NAME-dag-processor -n $NAMESPACE --timeout=120s

echo ""
echo "✅ Airflow upgrade completed successfully!"
echo "📦 New image tag: $IMAGE_TAG"
echo ""
echo "To access the Airflow UI, run:"
echo "  kubectl port-forward svc/$RELEASE_NAME-api-server 8080:8080 --namespace $NAMESPACE"