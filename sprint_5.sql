-- втирина по качеству знаний
drop table if exists mart.mart_quality_of_knowledge;

create table mart.mart_quality_of_knowledge
(
    period_id                integer,
    region_id                integer,
    region_name              text,
    department_id            integer,
    department_name          text,
    school_id                integer,
    school_name              text,
    group_id                 integer,
    class_name               text,
    subject_id               integer,
    subject_name             text,
    total_marks              bigint,
    count_fives              bigint,
    count_fours              bigint,
    count_threes             bigint,
    count_twos               bigint,
    avg_mark                 numeric(3,2),
    quality_of_knowledge_pct numeric(5,2),
    academic_performance_pct numeric(5,2)
);
alter table mart.mart_quality_of_knowledge owner to intern;

truncate table mart.mart_quality_of_knowledge;

insert into mart.mart_quality_of_knowledge (
    period_id, region_id, region_name, department_id, department_name,
    school_id, school_name, group_id, class_name, subject_id, subject_name,
    total_marks, count_fives, count_fours, count_threes, count_twos,
    avg_mark, quality_of_knowledge_pct, academic_performance_pct
)
with calculated_marks as (
    select
        fm.*,
        case
            when fm.mark_max > 0 then (fm.mark::numeric / fm.mark_max) * 100
            else 0
        end as mark_pct,
        case
            when fm.mark_max <= 0 then 2
            when (fm.mark::numeric / fm.mark_max) * 100 >= 85 then 5
            when (fm.mark::numeric / fm.mark_max) * 100 >= 65 then 4
            when (fm.mark::numeric / fm.mark_max) * 100 >= 40 then 3
            else 2
        end as traditional_mark
    from dwh.fact_marks fm
    where fm.mark is not null and fm.mark_max is not null
)
select
    cm.period_id,
    ds.region_id,
    ds.region_name,
    ds.department_id,
    ds.department_name,
    cm.school_id,
    ds.school_name,
    cm.group_id,
    concat(dg.grade, '-', dg.letter) as class_name,
    cm.subject_id,
    dsub.subject_name,

    -- Метрики на основе рассчитанной традиционной оценки
    count(cm.traditional_mark) as total_marks,
    count(case when cm.traditional_mark = 5 then 1 end) as count_fives,
    count(case when cm.traditional_mark = 4 then 1 end) as count_fours,
    count(case when cm.traditional_mark = 3 then 1 end) as count_threes,
    count(case when cm.traditional_mark = 2 then 1 end) as count_twos,
    round(avg(cm.traditional_mark), 2) as avg_mark,

    -- Качество знаний % (Доля 4 и 5)
    round(
        case when count(cm.traditional_mark) > 0
             then (count(case when cm.traditional_mark in (4,5) then 1 end) * 100.0) / count(cm.traditional_mark)
             else 0
        end, 2
    ) as quality_of_knowledge_pct,

    -- Успеваемость % (Доля 3, 4 и 5)
    round(
        case when count(cm.traditional_mark) > 0
             then (count(case when cm.traditional_mark in (3,4,5) then 1 end) * 100.0) / count(cm.traditional_mark)
             else 0
        end, 2
    ) as academic_performance_pct
from calculated_marks cm
inner join dwh.dim_school ds   on cm.school_id = ds.school_id
inner join dwh.dim_group dg    on cm.group_id = dg.group_id
inner join dwh.dim_subject dsub on cm.subject_id = dsub.subject_id
group by
    cm.period_id, ds.region_id, ds.region_name, ds.department_id, ds.department_name,
    cm.school_id, ds.school_name, cm.group_id, dg.grade, dg.letter, cm.subject_id, dsub.subject_name;

--витрина по посещаемости
drop table if exists mart.mart_attendance;

create table mart.mart_attendance
(
    attendance_date    date,
    region_id          integer,
    region_name        text,
    department_id      integer,
    department_name    text,
    school_id          integer,
    school_name        text,
    group_id           integer,
    class_name         text,
    subject_id         integer,
    subject_name       text,
    total_lessons      bigint,
    count_presents     bigint,
    count_absences     bigint,
    total_minutes_late bigint
);
alter table mart.mart_attendance owner to intern;

insert into mart.mart_attendance (
    attendance_date, region_id, region_name, department_id, department_name,
    school_id, school_name, group_id, class_name, subject_id, subject_name,
    total_lessons, count_presents, count_absences, total_minutes_late
)
select
    fa.attendance_date,
    ds.region_id,
    ds.region_name,
    ds.department_id,
    ds.department_name,
    fa.school_id,
    ds.school_name,
    fa.group_id,
    concat(dg.grade, '-', dg.letter) as class_name,
    fa.subject_id,
    dsub.subject_name,
    count(fa.attendance_id) as total_lessons,
    count(case when fa.status in ('present','late') or fa.status is null then 1 end) as count_presents,
    count(case when fa.status not in ('present', 'late') and fa.status is not null then 1 end) as count_absences,
    coalesce(sum(fa.minutes_late), 0) as total_minutes_late
from dwh.fact_attendance fa
inner join dwh.dim_school ds   on fa.school_id = ds.school_id
inner join dwh.dim_group dg    on fa.group_id = dg.group_id
inner join dwh.dim_subject dsub on fa.subject_id = dsub.subject_id
group by
    fa.attendance_date, ds.region_id, ds.region_name, ds.department_id, ds.department_name,
    fa.school_id, ds.school_name, fa.group_id, dg.grade, dg.letter, fa.subject_id, dsub.subject_name;