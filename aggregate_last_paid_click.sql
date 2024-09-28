with tab1 as (
select
distinct on
(s.visitor_id)
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
s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
order by
s.visitor_id asc,
s.visit_date desc),
tab2 as (
select
utm_source,
utm_medium,
utm_campaign,
to_char(visit_date,
'YYYY-MM-DD') as visit_date,
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
to_char(visit_date,
'YYYY-MM-DD'),
utm_source,
utm_medium,
utm_campaign
order by
visit_date desc),
tab3 as (
select
to_char(campaign_date,
'YYYY-MM-DD') as campaign_date,
utm_source,
utm_medium,
utm_campaign,
sum(daily_spent) as total_cost
from
vk_ads
group by
to_char(campaign_date,
'YYYY-MM-DD'),
utm_source,
utm_medium,
utm_campaign
union
select
to_char(campaign_date,
'YYYY-MM-DD') as campaign_date,
utm_source,
utm_medium,
utm_campaign,
sum(daily_spent) as total_cost
from
ya_ads
group by
to_char(campaign_date,
'YYYY-MM-DD'),
utm_source,
utm_medium,
utm_campaign)
select
	tab2.visit_date,
	tab2.utm_source,
	tab2.utm_medium,
	tab2.utm_campaign,
	tab2.visitors_count,
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