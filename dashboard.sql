-- Исходный набор данных
with tab1 as (
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
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
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
        to_char(
            visit_date,
            'YYYY-MM-DD'
        ),
        utm_source,
        utm_medium,
        utm_campaign
    order by
        visit_date desc
),

tab3 as (
    select
        to_char(
            campaign_date,
            'YYYY-MM-DD'
        ) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        to_char(
            campaign_date,
            'YYYY-MM-DD'
        ),
        utm_source,
        utm_medium,
        utm_campaign
    union
    select
        to_char(
            campaign_date,
            'YYYY-MM-DD'
        ) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        to_char(
            campaign_date,
            'YYYY-MM-DD'
        ),
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
        count(*) as count_organic
    from
        sessions
    where
        medium = 'organic'
    group by
        visit_date
),

daily_costs as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from
        vk_ads
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from
        ya_ads
),

source_and_costs as (
    select
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content,
        dc.daily_spent
    from
        sessions as s
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
        sum(daily_spent) as total_cost
    from
        source_and_costs
    group by
        visit_date
)

select
    o.visit_date,
    tc.total_cost,
    o.count_organic
from
    organic as o
inner join total_costs as tc
    on
        o.visit_date = tc.visit_date
order by
    o.visit_date;
-- дата закрытия лидов:
with table1 as (
    select distinct on
    (s.visitor_id)
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
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by
        s.visitor_id asc,
        s.visit_date desc
),

visitors_and_leads as (
    select *
    from
        table1
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

date_close as (
    select
        lead_id,
        created_at as date_close
    from
        visitors_and_leads
    where
        lead_id is not null
    order by
        date_close
)

select
    date_close::date,
    count(*) as leads_count
from
    date_close
group by
    date
order by
    date;

-- кол-во дней с момента перехода по рекламе до закрытия лида
with table1 as (
    select distinct on
    (s.visitor_id)
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
    from
        sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by
        s.visitor_id asc,
        s.visit_date desc
),

visitors_and_leads as (
    select *
    from
        table1
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

days_close as (
    select
        lead_id,
        created_at::date - visit_date::date as days_close
    from
        visitors_and_leads
    where
        lead_id is not null
    order by
        days_close
)

select
    days_close,
    count(*) as leads_count
from
    days_close
group by
    days_close
order by
    days_close;
-- конверсия из клика в лид, из лида в оплату
select
    round(
        sum(tab2.leads_count) / sum(tab2.visitors_count) * 100,
        2
    ) as conversion_leads,
    round(
        sum(tab2.purchases_count) / sum(tab2.leads_count) * 100,
        2
    ) as conversion_paid
from
    tab2;
-- CUSTOM SQL для поля "cpu" в таблице "Метрики".
select
    case
        when sum(visitors_count) = 0 then 0
        else
            round(sum(total_cost) / sum(visitors_count), 2)
    end as cpu
from dataset;
-- CUSTOM SQL для поля "выручка" в таблице "Окупаемость рекламы"
select
    sum(
        coalesce(revenue, 0)
    ) as income
from
    dataset;
-- CUSTOM SQL для поля "прибыль" в таблице "Окупаемость рекламы"
select
    sum(
        coalesce(revenue, 0)
    ) - sum(total_cost) as profit
from
    dataset;

--Расчет кол-ва каналов привлечения
select count(distinct source)
from sessions;

--Расчет кол-ва общих и уникальных визитов по всем каналам привлечения трафика
select
    sessions.source,
    count(sessions.visitor_id) as count_all,
    count(distinct sessions.visitor_id) as count_distinct
from sessions
group by
    sessions.source;

--Расчет суммарных и уникальных посещений сайта онлайн-школы
select
    count(visitor_id) as count_all,
    count(distinct visitor_id) as count_distinct
from sessions;

--Расчет кол-ва лидов
select sum(leed) as leads_count
from
    (select
        1 as leed,
        amount,
        closing_reason,
        case
            when amount > 0 then 1
            else 0
        end as leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date11
    from leads
    order by date11) as tab21;

--Расчет кол-ва закрытых лидов
select sum(leed_amount) as purchases_count
from
    (select
        1 as leed,
        amount,
        closing_reason,
        case
            when amount > 0 then 1
            else 0
        end as leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date22
    from leads
    order by date22) as tab22;

--Расчет дохода
select sum(amount) as revenue
from
    (select
        1 as leed,
        amount,
        closing_reason,
        case
            when amount > 0 then 1
            else 0
        end as leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date33
    from leads
    order by date33) as tab23;

--Расчет дохода
select sum(amount) as revenue
from
    (select
        1 as leed,
        amount,
        closing_reason,
        case
            when amount > 0 then 1
            else 0
        end as leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date44
    from leads
    order by date44) as tab23;

--Расчет дохода
select sum(amount) as revenue
from
    (select
        1 as leed,
        amount,
        closing_reason,
        case
            when amount > 0 then 1
            else 0
        end as leed_amount,
        to_char(date_trunc('day', created_at), 'YYYY-MM-DD') as date55
    from leads
    order by date55) as tab23;

--Расчет расходов
select sum(total_daily_spent) as consumption
from
    (
        select
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            sum(daily_spent) as total_daily_spent
        from
            (select
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            from vk_ads
            union all
            select
                campaign_name,
                utm_source,
                utm_medium,
                utm_campaign,
                utm_content,
                campaign_date,
                daily_spent
            from ya_ads) as combined_ads
        group by
            campaign_name,
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date
    ) as tab24;

--Сводная таблица
with tab as (
    select
        sessions.visitor_id,
        sessions.visit_date,
        sessions.source,
        sessions.medium,
        sessions.campaign,
        leads.created_at,
        leads.closing_reason,
        leads.status_id,
        coalesce(leads.amount, 0) as amount,
        case
            when leads.created_at < sessions.visit_date then 'delete' else leads.lead_id
            end as lead_id,
        row_number()
            over (partition by sessions.visitor_id order by sessions.visit_date desc)
        as rn
    from sessions
    left join leads
        on sessions.visitor_id = leads.visitor_id
    where sessions.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

tab2 as (
    select
        tab.visitor_id,
        tab.source as utm_source,
        tab.medium as utm_medium,
        tab.campaign as utm_campaign,
        tab.created_at,
        tab.amount,
        tab.closing_reason,
        tab.status_id,
        date_trunc('day', tab.visit_date) as visit_date,
        case
            when tab.created_at < tab.visit_date then 'delete' else lead_id
        end as lead_id
    from tab
    where (tab.lead_id != 'delete' or tab.lead_id is null) and tab.rn = 1
),

amount as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,
        sum(case when lead_id is not null then 1 else 0 end) as leads_count,
        sum(
            case
                when
                    closing_reason = 'Успешная продажа' or status_id = 142
                    then 1
                else 0
            end
        ) as purchases_count,
        sum(amount) as revenue
    from tab2
    group by
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
),

tab4 as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from vk_ads
    union all
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from ya_ads
),

cost as (
    select
        campaign_date as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from tab4
    group by
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
),

tab5 as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        null as revenue,
        null as visitors_count,
        null as leads_count,
        null as purchases_count,
        total_cost
    from cost
    union all
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        revenue,
        visitors_count,
        leads_count,
        purchases_count,
        null as total_cost
    from amount
),

tab6 as (
select
    utm_source,
    utm_medium,
    utm_campaign,
    sum(coalesce(visitors_count, 0)) as visitors_count,
    sum(coalesce(total_cost, 0)) as total_cost,
    sum(coalesce(leads_count, 0)) as leads_count,
    sum(coalesce(purchases_count, 0)) as purchases_count,
    sum(coalesce(revenue, 0)) as revenue
from tab5
group by
    utm_source,
    utm_medium,
    utm_campaign
order by total_cost desc)
select *,
    case when visitors_count = 0 then null 
    else total_cost / visitors_count end as cpu,
    case when leads_count = 0 then null 
    else total_cost / leads_count end as cpl,
    case when purchases_count = 0 then null 
    else total_cost / purchases_count end as cppu,
    case when total_cost = 0 then null 
    else ((revenue - total_cost) / total_cost) * 100 end as roi
from tab6
order by roi asc;
