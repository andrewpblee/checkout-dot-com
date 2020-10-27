{{
    config(
        materialized='incremental',
        schema='pageviews',
        name='pageviews_agg',
        unique_key= concat(
            user_id::varchar, 
            date_part(epoch_second,pageview_hour)::varchar
            )
        )
    )
}}

select
user_id,
date_trunc('DATE', pageview_datetime) as pageview_date,
date_trunc('HOUR', pageview_datetime) as pageview_hour,
count(0) as pageviews
from {{ ref('pageviews.raw_pageviews​') }}
{% if is_incremental() %}
    where pageview_datetime >= 
        (select 
        max(pageview_hour) 
        from {{this}}
        )
{% endif %}
group by 1,2