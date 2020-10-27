{{
    config(
        materialized='incremental',
        schema='pageviews',
        name='raw_pageviews',
        unique_key= concat(
            user_id::varchar, 
            url, 
            date_part(epoch_second,pageview_datetime)::varchar
            )
        )
}}

select
user_id, 
url, 
pageview_datetime
from {{ source('staging', 'pageviews_extract​') }}
{% if is_incremental() %}
    where pageview_datetime > 
        (select 
        max(pageview_datetime) 
        from {{this}}
        )
{% endif %}