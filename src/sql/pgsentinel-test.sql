CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION pgsentinel;
select pg_sleep(3);
select count(*) > 0 AS has_data from pg_active_session_history where queryid in (select queryid from pg_stat_statements);
select pg_sleep(3);
select count(*) > 0 AS has_pgssh_data from pg_stat_statements_history;

ALTER SYSTEM SET pgsentinel_ash.sampling_period = 3;
ALTER SYSTEM SET pgsentinel_pgssh.sampling_period = 1;
select pg_reload_conf();
CREATE TEMP TABLE sampling_start AS SELECT clock_timestamp() AS t;
select pg_sleep(4);
select count(distinct ash_time) between 1 and 2 AS ash_sampling_period_works
from pg_active_session_history where ash_time >= (select t from sampling_start);
select count(distinct ash_time) between 3 and 4 AS pgssh_sampling_period_works_1s
from pg_stat_statements_history where ash_time >= (select t from sampling_start);

ALTER SYSTEM SET pgsentinel_ash.sampling_period = 1;
ALTER SYSTEM SET pgsentinel_pgssh.sampling_period = 3;
select pg_reload_conf();
TRUNCATE sampling_start;
INSERT INTO sampling_start SELECT clock_timestamp();
select pg_sleep(4);
select count(distinct ash_time) between 1 and 2 AS pgssh_sampling_period_works_3s
from pg_stat_statements_history where ash_time >= (select t from sampling_start);
select count(distinct ash_time) between 3 and 4 AS ash_sampling_period_works_1s
from pg_active_session_history where ash_time >= (select t from sampling_start);

ALTER SYSTEM RESET pgsentinel_pgssh.sampling_period;
select pg_reload_conf();

begin;
\! sleep 3
commit;

select count(*) > 0 AS has_idle_data from pg_active_session_history where state  = 'idle in transaction';

ALTER SYSTEM SET pgsentinel_ash.track_idle_trans = true;
select pg_reload_conf();

begin;
\! sleep 3
commit;

select count(*) > 0 AS has_idle_data from pg_active_session_history where state  = 'idle in transaction';

-- Test privilege check
CREATE ROLE test_unprivileged LOGIN;

-- Check that unprivileged user sees redacted data for superuser's queries
SET ROLE test_unprivileged;
SELECT bool_or(query = '<insufficient privilege>') AS has_redacted_queries
FROM pg_active_session_history;
RESET ROLE;

DROP ROLE test_unprivileged;

DROP EXTENSION pgsentinel;
DROP EXTENSION pg_stat_statements;
