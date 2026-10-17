// Pure preview only: never authorizes an EXP payout.
export function goalProgress(goal, submissions, startDate, endDate) {
  const fields = {jogging_km:'jogging_km',technique_minutes:'technique_minutes'};
  if (goal.review_mode !== 'automatic' || !Object.hasOwn(fields,goal.metric)) throw Error('Invalid metric');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !/^\d{4}-\d{2}-\d{2}$/.test(endDate) || startDate > endDate) throw Error('Invalid dates');
  const target = Number(goal.target_value);
  if (!Number.isFinite(target) || target <= 0 || target > 1000000) throw Error('Invalid target');
  if (!Array.isArray(submissions)) throw Error('Invalid submissions');
  let achieved = 0;
  for (const entry of submissions) {
    if (entry.status !== 'approved' || entry.training_date < startDate || entry.training_date > endDate) continue;
    const amount = Number(entry[fields[goal.metric]] ?? 0);
    if (!Number.isFinite(amount) || amount < 0) throw Error('Invalid amount');
    achieved += amount;
    if (!Number.isFinite(achieved)) throw Error('Invalid total');
  }
  return {achieved,target,complete:achieved >= target};
}
