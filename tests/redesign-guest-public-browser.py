#!/usr/bin/env python3
"""Local browser test: mocked public guest RPCs, privacy, XSS and empty states.
No external requests or real users. Python Playwright is test-only, not an app dependency.
"""
import asyncio
import json
from pathlib import Path
from urllib.parse import urlsplit
import re
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent
ALLOWED_RPCS = {'get_public_leaderboard','get_public_levels','get_monthly_awards','get_public_boxer_avatars','league_v21_public_live_duels'}
ALLOWED_TABLES = {'league_global_challenges_v21','league_global_results_v21','league_public_duel_history_v21','league_public_records_v21','league_public_badges_v21','league_hall_of_fame_v21','league_seasons_v21'}
XSS = 'Name<img src=x onerror=window.__xssRan=true>'
DATA = {
 'get_public_leaderboard':[
  {'rank_position':1,'boxer_name':XSS,'monthly_points':595,'lifetime_exp':695,'email':'private@example.invalid'},
  {'rank_position':2,'boxer_name':'Offline B','monthly_points':340,'lifetime_exp':440},
  {'rank_position':3,'boxer_name':'Offline C','monthly_points':310,'lifetime_exp':310},
  {'rank_position':4,'boxer_name':'Offline D','monthly_points':295,'lifetime_exp':295}
 ],
 'get_public_levels':[
  {'boxer_name':XSS,'lifetime_exp':695},
  {'boxer_name':'Offline B','lifetime_exp':440},
  {'boxer_name':'Offline C','lifetime_exp':310},
  {'boxer_name':'Offline D','lifetime_exp':295}
 ],
 'get_monthly_awards':[{'award_code':'consistent','boxer_name':'Offline B','award_value':7,'award_unit':'Tage'}],
 'get_public_boxer_avatars':[],
}

async def check_case(browser, case):
 requests=[]
 unknown=[]
 errors=[]
 page=await browser.new_page(viewport={'width':390,'height':844},reduced_motion='reduce')
 page.on('pageerror', lambda e: errors.append(str(e)))
 await page.add_init_script('window.__xssRan=false')
 async def intercept(route):
  url=route.request.url
  parsed=urlsplit(url)
  path=parsed.path
  if parsed.netloc!='iqarjivcrddcixrvqbfb.supabase.co':
   unknown.append(url)
   await route.abort()
   return
  is_rpc='/rest/v1/rpc/' in path
  name=path.split('/')[-1]
  requests.append((name,is_rpc))
  if name not in (ALLOWED_RPCS if is_rpc else ALLOWED_TABLES):
   unknown.append(url)
   await route.abort()
   return
  if name=='league_v21_public_live_duels':
   await route.fulfill(status=404,body='not available',headers={'access-control-allow-origin':'*'})
  elif case=='error' and name=='get_public_leaderboard':
   await route.fulfill(status=500,body='unavailable',headers={'access-control-allow-origin':'*'})
  else:
   body=[] if case=='empty' else DATA.get(name,[])
   await route.fulfill(status=200,content_type='application/json',body=json.dumps(body),headers={'access-control-allow-origin':'*'})
 await page.route('**/*',intercept)
 try:
  html=(ROOT/'guest.html').read_text(encoding='utf-8')
  html=re.sub(r'<link\s+rel="stylesheet"\s+href="\./([\w-]+\.css)"\s*>',lambda m:'<style>'+ (ROOT/m.group(1)).read_text(encoding='utf-8')+'</style>',html)
  await page.set_content(html,wait_until='domcontentloaded',timeout=16000)
  await page.wait_for_function("document.querySelector('#ranking')?.textContent?.includes('Offline') || document.querySelector('#ranking')?.textContent?.includes('Noch keine') || document.querySelector('#ranking')?.textContent?.includes('HTTP 500')",timeout=11000)
  assert not errors,'Browser JS errors '+str(errors)
  assert not unknown,'Unexpected or private requests: '+str(unknown)
  assert any(x[0]=='get_public_leaderboard' for x in requests)
  assert any(x[0]=='get_public_levels' for x in requests)
  assert any(x[0]=='get_monthly_awards' for x in requests)
  assert 'nur für die beteiligten Boxer sichtbar' in await page.locator('#live-duels').inner_text()
  content=await page.locator('body').inner_text()
  assert 'private@example.invalid' not in content, 'Private data leaked from JSON response'
  assert not await page.evaluate('window.__xssRan'), 'Injected XSS executed'
  assert await page.locator('img[onerror]').count()==0,'Untrusted user name reached HTML as active image'
  if case=='populated':
   assert await page.locator('#podium .card').count()==3
   assert await page.locator('#ranking .row').count()==4
   assert await page.locator('#levels .row').count()==4
   assert await page.locator('#awards .row').count()==4
   assert XSS in (await page.locator('#ranking').inner_text()),'User text was removed instead of escaped'
   assert '595' in (await page.locator('#podium').inner_text())
  elif case=='empty':
   assert 'Noch keine bestätigten Trainings' in await page.locator('#ranking').inner_text()
   assert 'Noch keine Leveldaten' in await page.locator('#levels').inner_text()
  elif case=='error':
   assert 'HTTP 500' in await page.locator('#ranking').inner_text()
  assert await page.evaluate('document.documentElement.scrollWidth<=document.documentElement.clientWidth'),'Guest layout overflows'
  return {'case':case,'result':'PASS','public_requests':sorted(set(x[0] for x in requests)),'js_errors':errors}
 finally:
  await page.close()

async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
  try:
   for case in ['populated','empty','error']:
    res=await check_case(browser,case)
    print(json.dumps(res,ensure_ascii=False),flush=True)
  finally:
   await browser.close()

if __name__=='__main__':
 asyncio.run(main())
