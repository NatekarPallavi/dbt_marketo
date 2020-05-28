{{ 
    config(
        materialized='incremental',
        partition_by = {'field': 'date_day', 'data_type': 'date'},
        unique_key='lead_day_id'
        ) 
}}

{% if execute -%}
    {% set results = run_query('select restname from ' ~ var('lead_describe')) %}
    {% set results_list = results.columns[0].values() %}
{% endif -%}

with change_data as (

    select *
    from {{ var('change_data_value') }}
    {% if is_incremental() %}
    where cast({{ dbt_utils.dateadd('day', -1, 'activity_date') }} as date) >= (select max(date_day) from {{ this }})
    {% endif %}

), lead_describe as (

    select *
    from {{ var('lead_describe') }}

), joined as ( 

    -- Join the column names from the describe table onto the change data table

    select 
        change_data.*,
        lead_describe.restname as primary_attribute_column
    from change_data
    left join lead_describe
        on change_data.primary_attribute_value_id = lead_describe.lead_describe_id

), pivot as (

    -- For each column that is in both the lead_history_columns variable and the restname of the lead_describe table,
    -- find whether a change occurred for a given column on a given day for a given lead. 
    -- This will feed the daily slowly changing dimension model.

    select 
        lead_id,
        cast({{ dbt_utils.dateadd('day', -1, 'activity_date') }} as date) as date_day,

        {% for col in results_list if col|lower|replace("__c","_c") in var('lead_history_columns') %}
        {% set col_xf = col|lower|replace("__c","_c") %}
        max(case when lower(primary_attribute_column) = '{{ col|lower }}' then True else False end) as {{ col_xf }}
        {% if not loop.last %} , {% endif %}
        {% endfor %}
    
    from joined
    where cast(activity_date as date) < current_date
    group by 1,2

), surrogate_key as (

    select 
        *,
        {{ dbt_utils.surrogate_key(['lead_id','date_day'])}} as lead_day_id
    from pivot

)

select *
from surrogate_key