# Checkout.com Data Analytics Task - Andrew Lee

The aim of the task was to create a performant data pipeline that will allows us to answer the following questions:

1. The number of pageviews by a given time period based on the user's current postcode.
2. The number of pageviews by a given time period based on the user's postcode at the time of the pageview.

## How to Run

This pipeline sits within a dbt project, that is scheduled via airflow.

The airflow dag is designed to run hourly, however as not every table needs to be updated this frequently (user tables are only updated daily), each table is tagged with either `hourly` or `daily`, and if the hour of the day is 1 (1am), the daily tagged tables will be refreshed, otherwise the hourly tagged tables will refresh.


The dag is composed of two operators, a run operator triggering `dbt run`, and a test operator triggering `dbt test` downstream.

Once connected to the snowflake datawarehouse with the correct credentials and hosted on the correct server, this pipeline shoud update automatically. If we need to run the pipeline manually, we can manually trigger the dag in airflow(removing the tag if a full refresh of every table is needed), or run the models using `dbt run` on the command line.

## My Approach

My overall approach was to create 3 schemas:

- Users (containing tables related to user data)
- Pageviews (containing tables related to pageview data)
- Analytics (containing the combined table designed to be queried)


Each column has at least one test to ensure accuracy, and each schema has its own yml file to include documentation.

### Users

Users contains the following tables:

`raw_users`

- This table is basically replicating the `user_extract` table as defined in the task, but is adding in the execution in order to build an incremental model downstream.
- This table fully refreshes daily and pulls in the id of the user and the postcode

`user_history`

- This table runs incrementally downstream of the `raw_users` and adds any new data for each user from the previous day, assigning the date of the postcode to `execution_date`, the date the incremental runs are focussing on, which should be yesterday.

* An alternative to this approach would be to use a snapshot table, which would in effect build the history of the user for us, and provide `updated_at` details from which we could ascertain the most recent postcode. To use this approach we would need to create a snapshot table, similar to this:

```
{% snapshot users_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='timestamp',
      updated_at='updated_at',
    )
}}

select * from {{ source('staging', 'users_extract') }}

{% endsnapshot %}
```

- We would then need to add a snapshot operator within our dag, upstream of dbt run.
- This approach could turn out to be more efficient and viable than my current solution, so is definitely worth considering moving forward. (I've left my current solution due to time restraints)

### Pageviews

Pageviews contains the following table:

`pageviews_agg`

- This table runs incrementally downstream of `pageviews_extract` and aggregates the pageviews of the user truncated to the hour (I go through this decision in more detail further down).
- I used `count(0)` to count pageviews, as I have created a unique key for this table, and have distincted the data upstream, in order to remove duplication.

### Analytics

`hourly_pageviews`

- This is the main denormalised table from which we can answer our two questions.
- For this table I took the following approach:

  - Incrementally select the pageviews and users from the pageviews table.

  - Distinctly select the users that are present within this table and use this to inner join on the users table.I chose this approach for the following reasons:

    - I am relying on last value to calculate the most recent postcode of the user, which means I cannot rely on incrementally running this table as I would not be able to overwrite existing data.
    - I need to look at the entire history of a user, but I only care about the users who are present in the most recent pageview refresh. Therefore if I inner join on these users I can reduce the data volume and optimise the query.

  - Finally I join the users and pageview tables together, and aggregate the pageviews to hour, date, postcode and most recent postcode level.
  - This approach allows the full table to be connected to looker, and the two questions can be answered by grouping to the relevant postcode and aggregating the pageviews.

- For this table there were a couple other options I considered:

| Option                                                                                               | Picked | Pros                                                                                                  | Cons                                                                                   | Notes                                                             |
| ---------------------------------------------------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Aggregate any postcode and most recent post in separate tables or final table, then join on postcode |        | Avoids creating a matrix of postcodes                                                                 | Requires more joins and tables to create, and pageviews are less obvious to understand | This is a very viable option and would not take long to implement. |
| Keep any postcode and current postcode separate and grouped by both                                  | Yes    | Less joins and processing is required, and pageviews are in one column which can be aggregated later. | More rows are needed to store the data and postcode are less obivous.                  | I've gone with this option in favour of performance.              |

## Assumptions:

For this task I've made a few assumptions and detailed my approach accordingly.

### Assumption 1: Within the `users_extracts` table, only one postcode will be present per user.

One of the main difficulties with this table is that there is no date or time associated with the postcode value of each user. My approach relies on there only being one postcode per user, from which we can attribute a date based off the execution date and incrementally build a history for each user.

If a user can have multiple postcodes, we would not be able to tell which postcode is the most recent for each run of the table, and therefore would not be able to accurately to answer the final questions.

If this is possible however, we could look to find if it possible to catch the timestamp of each postcode view and pass this data downstream to users_extract.

### Assumption 2: The smallest time period required is hour.

My approach to dealing with the large amount of pageviews that can come through is to aggregate this quickly and pass this downstream. To this end I have truncated to hour and counted pageviews per user at the hour level, which can be aggregated further to larger date intervals.

If minute level data is required, this can be added in a similar fashion, adding a column that truncates at minute level. To err on the side of performance I have left this out, but this can easily be added in.

Any deeper and this approach would not be much more performant than leaving the pageviews at page level, and I would question how much valuable information we can gather from know the count of pageviews at a second level.

### Assumption 3: Pageviews are not unique

I've assumed that the number of pageviews does not refer to unique pageviews. This could easily be changed by changing the `count(0)` to `count(distinct url)`.
