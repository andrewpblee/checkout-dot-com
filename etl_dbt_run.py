from airflow import DAG
from airflow_dbt.operators.dbt_operator import (
    DbtRunOperator,
    DbtTestOperator
)
from datetime import datetime,timedelta

execution_date = '{{ yesterday_ds }}'
now = datetime.datetime.now()
execution_hour = datetime.now().replace(microsecond=0, second=0, minute=0) - timedelta(hours=1)

dbt_tags = 'tag:daily' if now.hour == 1 else 'tag:hourly'

default_args = {
    'dir': '/checkout-dot-com'
}


with DAG(dag_id='dbt', default_args=default_args, schedule_interval='@hourly') as dag:
    dbt_run = DbtRunOperator(
        task_id = 'dbt_run',
        models = dbt_tags,
        vars = {
            'execution_date': execution_date,
            'execution_hour': execution_hour
        }
        retries = 1
    )

    dbt_test = DbtTestOperator(
        task_id='dbt_test',
        # Run will only fail if a test does, no need to retry.
        retries=0
    )

    dbt_run >> dbt_test