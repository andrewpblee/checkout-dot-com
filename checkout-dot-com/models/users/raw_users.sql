{{
    config(
        materialized='table',
        schema='users',
        name='raw_users',
        unique_key= concat(id::varchar, postcode)
    )
}}

select
id, 
postcode,
'{{ var("execution_date")}}' as execution_date
from {{ source('staging', 'users_extract​') }}