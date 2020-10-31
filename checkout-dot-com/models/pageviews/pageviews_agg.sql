{{
    config(
        materialized='incremental',
        schema='pageviews',
        name='pageviews_agg',
        unique_key= user_id::varchar || date_part(epoch_second,pageview_hour)::varchar
        tags=['hourly', 'daily']
        )
    )
}}

select
user_id,
date_trunc('DATE', pageview_datetime) as pageview_date,
date_trunc('HOUR', pageview_datetime) as pageview_hour,
count(0) as pageviews
from {{ source('staging', 'pageviews_extract​') }}
{% if is_incremental() %}
   where pageview_datetime >= {{ var('execution_hour')}}
{% endif %}
group by 1,2