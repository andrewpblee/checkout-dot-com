{{
    config(
        materialized='incremental',
        schema='analytics',
        name='hourly_pageviews',
        unique_key= date_part(epoch_second,pageview_hour)::varchar || postcode
                current_postcode
                ),
        tags=['hourly', 'daily']
    )
    
}}


with pageviews as 
-- incrementally selecting the latest data to add
    (select
    pageview_hour,
    pageview_date,
    user_id, 
    pageviews
    from {{ ref('pageviews.pageviews_agg') }}
    {% if is_incremental() %}
        where pageview_datetime >= {{ var('execution_hour')}}
    {% endif %}    
    )

, users_in_focus as 
-- isolating the users in the latest batch to filter user table
    (select 
    distinct user_id
    from pageviews)

, users as 
-- Creating the current postcode of each relevant user from their history
    (select 
    distinct execution_date, 
    id, 
    postcode, 
    last_value(postcode) over (partition by id, order by execution_date asc) as current_postcode
    from {{ ref('users.user_history') }}) h 
        inner join users_in_focus f
        on u.id = f.user_id)

select 
pageview_date,
pageview_hour,
postcode, 
current_postcode,
sum(pageviews) as total_pageviews
from pageviews pvs inner join users u 
    on pvs.pageview_date = u.execution_date
    and pvs.user_id = u.id
{{ dbt_utils.group_by(4) }}
