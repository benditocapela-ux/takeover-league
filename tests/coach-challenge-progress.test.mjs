import test from 'node:test';
import assert from 'node:assert/strict';
import {goalProgress} from '../coach-challenge-progress.js';

const goal={review_mode:'automatic',metric:'jogging_km',target_value:10};
const sessions=[
 {status:'approved',training_date:'2026-10-10',jogging_km:6},
 {status:'approved',training_date:'2026-10-11',jogging_km:4},
 {status:'pending',training_date:'2026-10-11',jogging_km:100},
 {status:'rejected',training_date:'2026-10-11',jogging_km:100},
 {status:'approved',training_date:'2026-10-20',jogging_km:100}
];
test('approved submissions within date range only',()=>{
 assert.deepEqual(goalProgress(goal,sessions,'2026-10-10','2026-10-11'),{achieved:10,target:10,complete:true});
});
test('incomplete goals do not pass',()=>{
 assert.equal(goalProgress({...goal,target_value:11},sessions,'2026-10-10','2026-10-11').complete,false);
});
test('technique minutes are independent of jogging kilometres',()=>{
 const g={review_mode:'automatic',metric:'technique_minutes',target_value:45};
 assert.equal(goalProgress(g,[{status:'approved',training_date:'2026-10-10',technique_minutes:45,jogging_km:500}],'2026-10-10','2026-10-10').complete,true);
});
test('unsupported metric and negative approved amount are rejected',()=>{
 assert.throws(()=>goalProgress({...goal,metric:'points'},sessions,'2026-10-10','2026-10-11'));
 assert.throws(()=>goalProgress(goal,[{status:'approved',training_date:'2026-10-10',jogging_km:-1}],'2026-10-10','2026-10-11'));
});
