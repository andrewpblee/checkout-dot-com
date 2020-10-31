{{
    config(
        materialized='incremental',
        schema='users',
        name='user_history',
        unique_key= id::varchar || to_varchar(execution_date)
    )
}}

select
id, 
postcode, 
execution_date
from {{ ref('users.raw_users') }}
{% if is_incremental() %}
    where execution_date = '{{ var("execution_date")}}'
{% endif %}
