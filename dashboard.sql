-- Исходный набор данных
with tab1 as (
    select distinct on (s.visitor_id)
        s.visitor_id as visitor_id,
        s.visit_date as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id as lead_id,
        l.created_at as created_at,
        l.amount as amount,
        l.closing_reason as closing_reason,
        l.status_id as status_id
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc', 'cpm', 'cpa', 'youtube', 'cpp',
            'tg', 'social'
        )
    order by
        s.visitor_id asc,
        s.visit_date desc
),
tab2 as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        to_char(visit_date, 'YYYY-MM-DD') as visit_date,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(
            case
                when
                    closing_reason = 'Успешно реализовано'
                    or status_id = 142 then 1
            end
        ) as purchases_count,
        sum(amount) as revenue
    from
        tab1
    group by
        to_char(visit_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
    order by
        visit_date desc
),
tab3 as (
    select
        to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        to_char(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
    union
    select
        to_char(campaign_date, 'YYYY-MM-DD') as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        to_char(campaign_date, 'YYYY-MM-DD'),
        utm_source,
        utm_medium,
        utm_campaign
)
select
    tab2.visit_date,
    tab2.visitors_count,
    tab2.utm_source,
    tab2.utm_medium,
    tab2.utm_campaign,
    tab3.total_cost,
    tab2.leads_count,
    tab2.purchases_count,
    tab2.revenue
from
    tab2
left join tab3
    on
        lower(tab2.utm_source) = lower(tab3.utm_source)
        and lower(tab2.utm_medium) = lower(tab3.utm_medium)
        and lower(tab2.utm_campaign) = lower(tab3.utm_campaign)
        and tab2.visit_date = tab3.campaign_date
order by
    tab2.revenue desc nulls last,
    tab2.visit_date asc,
    tab2.visitors_count desc,
    tab2.utm_source asc,
    tab2.utm_medium asc,
    tab2.utm_campaign asc;
-- корреляция между запуском рекламной кампании и ростом органики:
with organic as (
    select
        visit_date::date as visit_date,
        COUNT(*) as count_organic
    from sessions
    where medium = 'organic'
    group by 1
),
daily_costs as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from vk_ads
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from ya_ads
),
source_and_costs as (
    select
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content,
        dc.daily_spent
    from sessions as s
    inner join daily_costs as dc
        on
            s.source = dc.utm_source
            and s.medium = dc.utm_medium
            and s.campaign = dc.utm_campaign
            and s.content = dc.utm_content
),
total_costs as (
    select
        visit_date::date as visit_date,
        SUM(daily_spent) as total_cost
    from source_and_costs
    group by 1
)
select
    o.visit_date,
    tc.total_cost,
    o.count_organic
from organic as o
inner join total_costs as tc
    on o.visit_date = tc.visit_date
order by 1;
-- дата закрытия лидов:
with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),
visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),
date_close as (
    select
        lead_id,
        created_at as date_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)
select
    date_close::date,
    COUNT(*) as leads_count
from date_close
group by 1
order by 1;
-- кол-во дней с момента перехода по рекламе до закрытия лида
with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),
visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),
days_close as (
    select
        lead_id,
        created_at::date - visit_date::date as days_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)
select
    days_close,
    COUNT(*) as leads_count
from days_close
group by 1
order by 1;
-- конверсия из клика в лид, из лида в оплату
select
	ROUND(SUM(tab2.leads_count) / SUM(tab2.visitors_count) * 100,
	2) as conversion_leads,
	ROUND(SUM(tab2.purchases_count) / SUM(tab2.leads_count) * 100,
	2) as conversion_paid
from
	tab2;
-- CUSTOM SQL для поля "cpu" в таблице "Метрики".
select
    case when sum(visitors_count) = 0 then 0 else round(
        sum(total_cost) / sum(visitors_count),
        2
    ) end as cpu
from dataset;
-- CUSTOM SQL для поля "выручка" в таблице "Окупаемость рекламы"
select sum(
    coalesce(revenue, 0)
) as income from dataset;
-- CUSTOM SQL для поля "прибыль" в таблице "Окупаемость рекламы"
select sum(
    coalesce(revenue, 0)
) - sum(total_cost) as profit from dataset;