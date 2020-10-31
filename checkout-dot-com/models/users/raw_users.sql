{{
    config(
        materialized='table',
        schema='users',
        name='raw_users',
        unique_key= id::varchar || postcode,
        tags=['daily']
    )
}}

select
id, 
postcode,
'{{ var("execution_date")}}' as execution_date
from {{ source('staging', 'users_extract​') }}