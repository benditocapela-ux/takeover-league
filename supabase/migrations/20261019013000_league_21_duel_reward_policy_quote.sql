-- Side-effect-free 2.1 duel reward RULE QUOTE, NOT a payout endpoint.
-- Rank order: F=1 through S=7. Determination of ranks and favourite MUST
-- be done by a trusted server from captured duel-start state before payouts.
create or replace function public.league_v21_duel_reward_quote(
 p_winner_rank text,p_loser_rank text)
returns jsonb language plpgsql immutable security invoker set search_path=''
as $f$
declare ranks text[]:=array['F','E','D','C','B','A','S'];
 winner_level integer;loser_level integer;winner_bonus integer;loser_delta integer;
begin
 winner_level=array_position(ranks,upper(coalesce(p_winner_rank,'')));
 loser_level=array_position(ranks,upper(coalesce(p_loser_rank,'')));
 if winner_level is null or loser_level is null then raise exception 'Unknown rank' using errcode='22023';end if;
 winner_bonus:=case when winner_level=loser_level then 100
                    when winner_level<loser_level then 150
                    else 50 end;
 -- When a higher-ranked favourite loses against a lower-ranked boxer,
 -- apply the previously discussed negative EXP to the favourite.
 loser_delta:=case when loser_level>winner_level then -50 else 0 end;
 return pg_catalog.jsonb_build_object('winner_exp',winner_bonus,'loser_exp',loser_delta,
   'winner_rank',upper(p_winner_rank),'loser_rank',upper(p_loser_rank),
   'policy','preview_only_no_payout');
end$f$;
revoke all on function public.league_v21_duel_reward_quote(text,text) from public,anon,authenticated;
grant execute on function public.league_v21_duel_reward_quote(text,text) to authenticated;
