#create cluster EMR e print hello world
from datetime import datetime
from airflow.sdk import DAG, task
from airflow.providers.amazon.aws.operators.emr import (
    EmrServerlessCreateApplicationOperator,
    EmrServerlessStartJobOperator,
    EmrServerlessStopApplicationOperator,
    EmrServerlessDeleteApplicationOperator
)

#role emr e configurações AWS
JOB_ROLE_ARN = "arn:aws:iam::986629373361:role/EMRServerlessJobRole"
S3_LOG_LOCATION = "s3://external-mount-volume/emr-logs"
AWS_REGION = "us-east-1"  # Altere para sua região se necessário

DEFAULT_MONITORING_CONFIG = {
    "monitoringConfiguration": {
        "s3MonitoringConfiguration": {
            "logUri": S3_LOG_LOCATION
        }
    }
}

with DAG(
    dag_id="emr_process_data",
    schedule=None,
    start_date=datetime(2025, 10, 6),
    tags=["emr"],
    catchup=False
) as dag:

        create_app_application = EmrServerlessCreateApplicationOperator(
            task_id="create_app_application",
            job_type="SPARK",
            release_label="emr-6.13.0",
            config={"name": "airflow-test"},
            aws_conn_id="aws_conn",
            region_name=AWS_REGION,
        )

        application_id = create_app_application.output

        job_1 = EmrServerlessStartJobOperator(
            task_id="job_1",
            application_id=application_id,
            execution_role_arn=JOB_ROLE_ARN,
            enable_application_ui_links=False,
            job_driver={
                "sparkSubmit": {
                    "entryPoint": "s3://external-mount-volume/emr-jobs/hello-world.py"
                }
            },
            configuration_overrides=DEFAULT_MONITORING_CONFIG,
            aws_conn_id="aws_conn",
            region_name=AWS_REGION,
        )   

        stop_application = EmrServerlessStopApplicationOperator(
            task_id="stop_application",
            application_id=application_id,
            aws_conn_id="aws_conn",
            region_name=AWS_REGION,
        )

        delete_app_application = EmrServerlessDeleteApplicationOperator(
            task_id="delete_app_application",
            application_id=application_id,
            aws_conn_id="aws_conn",
            region_name=AWS_REGION,
        )

        create_app_application >> job_1 >> stop_application >> delete_app_application