


with pageviews as 
    (select
    pageview_hour,
    pageview_date,
    user_id, 
    pageviews
    from {{ ref('pageviews.pageviews_agg') }}
    {% if is_incremental() %}
        where pageview_hour > 
            (select 
            max(pageview_hour) 
            from {{this}}
            )
    {% endif %}    
    )

, users_in_focus as 
    (select 
    distinct user_id
    from pageviews)

, users as 
    (select 
    execution_date, 
    id, 
    postcode, 
    last_value(postcode) over (partition by id, order by date asc) as current_postcode
    from {{ ref('users.user_history') }}) h inner join users_in_focus f
        on u.id = f.user_id
    )

select 
pvs.pageview_hour, 
postcode, 
current_postcode,
sum(pageviews) as total_pageviews
from pageviews pvs inner join users u 
    on pvs.date = u.execution_date
    and pvs.user_id = u.id
group by 1,2,3