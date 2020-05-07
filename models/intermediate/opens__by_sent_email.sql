{{ config(materialized='ephemeral') }}

with activity as (

    select *
    from {{ ref('stg_activity_open_email') }}

), aggregate as (

    select 
        email_send_id,
        count(*) as count_opens
    from activity
    group by 1

)

select * 
from aggregate

