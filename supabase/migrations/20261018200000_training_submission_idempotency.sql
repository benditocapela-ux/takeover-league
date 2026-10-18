-- Additive, staged-only: optional client request key for network retry idempotency.
-- Do not run against production until approved after backup/role tests.
alter table public.training_submissions
 add column if not exists client_request_id uuid;
create unique index if not exists training_submissions_boxer_request_id_uniq
 on public.training_submissions(boxer_id, client_request_id)
 where client_request_id is not null;
comment on column public.training_submissions.client_request_id is
 'Stable UUID from one boxer draft; duplicates fail atomically without extra points.';
