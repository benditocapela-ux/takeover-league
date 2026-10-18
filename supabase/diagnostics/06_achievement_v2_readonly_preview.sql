-- Takeover League 2.0: READ-ONLY achievement preview for live Supabase.
-- Safe to run: SELECT only. Does NOT activate features, grant EXP or create awards.
-- Uses training type NAMES rather than assumed IDs.
WITH rules(family, title, tier, threshold, reward_exp) AS (
 VALUES
 ('training','Training Warrior',1,10,25),('training','Training Warrior',2,25,60),('training','Training Warrior',3,50,125),('training','Training Warrior',4,100,250),
 ('consistent','Mr Consistent',1,10,25),('consistent','Mr Consistent',2,25,60),('consistent','Mr Consistent',3,60,125),('consistent','Mr Consistent',4,120,250),
 ('road','Road King',1,25,25),('road','Road King',2,75,60),('road','Road King',3,150,125),('road','Road King',4,300,250),
 ('flash','The Flash',1,5,25),('flash','The Flash',2,15,60),('flash','The Flash',3,30,125),('flash','The Flash',4,60,250),
 ('technician','The Technician',1,300,25),('technician','The Technician',2,900,60),('technician','The Technician',3,1800,125),('technician','The Technician',4,3600,250),
 ('fighter','Iron Fighter',1,5,25),('fighter','Iron Fighter',2,15,60),('fighter','Iron Fighter',3,30,125),('fighter','Iron Fighter',4,60,250),
 ('engine','Iron Engine',1,10,25),('engine','Iron Engine',2,25,60),('engine','Iron Engine',3,50,125),('engine','Iron Engine',4,100,250),
 ('complete','Complete Boxer',1,1,25),('complete','Complete Boxer',2,3,60),('complete','Complete Boxer',3,7,125),('complete','Complete Boxer',4,15,250)
), per_boxer AS (
 SELECT p.id AS boxer_id,p.display_name,
  count(s.id)::numeric AS sessions,
  count(DISTINCT s.training_date)::numeric AS days,
  coalesce(sum(s.jogging_km) FILTER (WHERE tt.name='Joggen'),0)::numeric AS km,
  coalesce(sum(s.technique_minutes) FILTER (WHERE tt.name='Techniktraining'),0)::numeric AS minutes,
  count(s.id) FILTER (WHERE tt.name='Sprint-Intervalle')::numeric AS sprints,
  count(s.id) FILTER (WHERE tt.name='Sparring')::numeric AS sparring,
  count(s.id) FILTER (WHERE tt.name='Krafttraining')::numeric AS strength,
  least(
    count(s.id) FILTER (WHERE tt.name='Reguläres Boxtraining'),
    count(s.id) FILTER (WHERE tt.name='Sparring'),
    count(s.id) FILTER (WHERE tt.name='Techniktraining'),
    count(s.id) FILTER (WHERE tt.name='Krafttraining'),
    count(s.id) FILTER (WHERE tt.name='Sprint-Intervalle'),
    count(s.id) FILTER (WHERE tt.name='Joggen')
  )::numeric AS complete
 FROM public.profiles p
 LEFT JOIN public.training_submissions s ON s.boxer_id=p.id AND s.status='approved'
 LEFT JOIN public.training_types tt ON tt.id=s.training_type_id
 WHERE p.role='boxer' AND p.is_active=true
 GROUP BY p.id,p.display_name
), achieved AS (
 SELECT p.boxer_id,p.display_name,r.title,r.tier,r.reward_exp,
 CASE r.family
  WHEN 'training' THEN p.sessions WHEN 'consistent' THEN p.days
  WHEN 'road' THEN p.km WHEN 'flash' THEN p.sprints
  WHEN 'technician' THEN p.minutes WHEN 'fighter' THEN p.sparring
  WHEN 'engine' THEN p.strength WHEN 'complete' THEN p.complete END AS progress,
 r.threshold
 FROM per_boxer p CROSS JOIN rules r
)
SELECT display_name, count(*) FILTER (WHERE progress>=threshold) AS achievements_earned,
 coalesce(sum(reward_exp) FILTER (WHERE progress>=threshold),0)::integer AS potential_new_exp,
 string_agg(title||' '||tier::text,', ' ORDER BY title,tier)
  FILTER (WHERE progress>=threshold) AS earned_list
FROM achieved
GROUP BY boxer_id,display_name
ORDER BY potential_new_exp DESC,display_name;
