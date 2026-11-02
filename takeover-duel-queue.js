/* Read-only staff points queue contract. Does not create a client or authorize users. */
(function(global){
 'use strict';
 const states=['all','open','due','ready','closed'];
 const validCounts=counts=>counts&&['all','open','due','ready','closed'].every(key=>Number.isSafeInteger(counts[key])&&counts[key]>=0)&&counts.ready<=counts.due&&counts.open+counts.due+counts.closed<=counts.all;
 function validPage(value,args={}){
  if(!value||value.metric!=='points'||!states.includes(value.state)||value.state!==(args.p_state||'due')||!validCounts(value.counts)||!Array.isArray(value.items)||value.items.length>20||!Number.isInteger(value.limit)||value.limit>20||value.limit<1)return false;
  if(typeof value.search!=='string'||value.search!==(args.p_search||'').trim()||!Number.isFinite(Date.parse(value.as_of)))return false;
  if((value.duel_id||null)!==(args.p_duel_id||null))return false;
  if(new Set(value.items.map(row=>row?.id)).size!==value.items.length||value.items.some(row=>!row||typeof row.id!=='string'||!row.id||!['pending','active','awaiting_reviews','settled','declined','expired','cancelled'].includes(row.status)))return false;
  const cursor=value.next_cursor;
  if(cursor!==null&&(!cursor||!Number.isFinite(Date.parse(cursor.before))||typeof cursor.before_id!=='string'||!cursor.before_id))return false;
  return true;
 }
 function countsText(counts){return counts.open.toLocaleString('de-CH')+' offen · '+counts.due.toLocaleString('de-CH')+' fällig · '+counts.ready.toLocaleString('de-CH')+' abschlussbereit · '+counts.closed.toLocaleString('de-CH')+' abgeschlossen'}
 global.TLDuelQueue={validPage,validCounts,countsText};
})(window);
