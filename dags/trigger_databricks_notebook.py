# Trigger Databricks Notebook

from airflow.sdk import DAG
from airflow.providers.databricks.operators.databricks import DatabricksRunNowOperator
from producer_data_assets import posts_asset, users_asset

with DAG(
    dag_id = "trigger_databricks_notebook",
    schedule = [posts_asset & users_asset]
):

    run_notebooks = DatabricksRunNowOperator(
        task_id = "run_notebooks",
        databricks_conn_id="databricks_conn",
        job_id = 7781132238205
    )

    run_notebooks