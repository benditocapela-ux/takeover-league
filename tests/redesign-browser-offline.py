#!/usr/bin/env python3
"""Optional offline Chromium smoke test for static Takeover League screens.

Run with `python tests/redesign-browser-offline.py` when Python Playwright and
Chromium are already installed. Uses actual repo markup/CSS, blocks all
remote requests and never connects to Supabase. This is not an auth/E2E test.
"""
import asyncio
import json
import re
from pathlib import Path

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parent.parent
EXCLUDE = {"challenges-v2-preview.html", "duels-v2-preview.html", "league2-preview.html"}
PAGES = sorted(x.name for x in ROOT.glob('*.html') if x.name not in EXCLUDE)
VIEWPORTS = [320, 390, 768, 1440]


def offline_markup(name):
    html = (ROOT/name).read_text(encoding='utf-8')
    # Read exactly the stylesheets referenced by the real app and embed them,
    # because file:// access is disabled by this execution environment.
    def css_replace(match):
        css_path = ROOT / match.group(1)
        if not css_path.is_file():
            raise AssertionError(f'{name}: missing local CSS {css_path.name}')
        return '<style>\n' + css_path.read_text(encoding='utf-8') + '\n</style>'
    html = re.sub(r'<link\s+rel="stylesheet"\s+href="\./([\w-]+\.css)"\s*>', css_replace, html)
    # Suppress local <script src>, then execute shared navigation after DOM
    # ready. Inline app scripts still run, and external requests are aborted.
    html = re.sub(r'<script\s+src="\./([\w-]+\.js)"\s+defer\s*></script>', '', html)
    return html


async def offline_route(route):
    await route.abort()


async def inspect_page(browser, name, width):
    page = await browser.new_page(viewport={'width': width, 'height': 800}, reduced_motion='reduce')
    await page.route('**/*', offline_route)
    errs = []
    page.on('pageerror', lambda e: errs.append(str(e)))
    await page.set_content(offline_markup(name), wait_until='domcontentloaded', timeout=14000)
    if name == 'admin.html' and width in (320, 390):
        # Make sure the data-driven mobile admin table works with synthetic,
        # local-only identities. No Supabase access or mutations take place.
        source = (ROOT/'admin.html').read_text(encoding='utf-8')
        module = re.search(r'<script type="module">([\s\S]*?)</script>', source)
        assert module, 'admin module not found'
        script = re.sub(r"^\s*import \{createClient\} from '[^']+';", '', module.group(1), count=1)
        stub = """const createClient=()=>({
          auth:{getUser:async()=>({data:{user:{id:'fake-admin-auth'}},error:null})},
          from:table=>({select:()=>({
            eq:()=>({maybeSingle:async()=>({data:{id:'fake-admin',role:'admin',is_active:true},error:null})}),
            order:()=>({limit:async()=>({data:[],error:null})})
          })}),
          rpc:async name=>name==='admin_list_profiles'?({data:[
            {id:'admin',display_name:'Offline Admin',role:'admin',is_active:true,is_listed:true,has_account:true,email:'admin@example.invalid',created_at:'2026-01-01'},
            {id:'boxer',display_name:'Offline Boxer',role:'boxer',is_active:true,is_listed:false,has_account:true,email:'boxer@example.invalid',created_at:'2026-01-01'},
            {id:'prepared',display_name:'Unverknüpft',role:'boxer',is_active:false,is_listed:true,has_account:false,email:null,created_at:'2026-01-01'}
          ],error:null}):({data:null,error:null})
        });"""
        await page.evaluate('async () => { '+stub+'\n'+script+'\n}')
        rows = page.locator('#profilesBody tr')
        assert await rows.count() == 3, 'admin profile rows did not render'
        assert await page.locator('#adminContent').is_visible(), 'admin content hidden with authorised mocked admin'
    # Verify that native current page has not been replaced by placeholder UI.
    metrics = await page.evaluate('''() => ({
      w: document.documentElement.scrollWidth,
      client: document.documentElement.clientWidth,
      ribbon: !!document.querySelector('.tl-screen-ribbon'),
      gold: getComputedStyle(document.documentElement).getPropertyValue('--gold').trim(),
      green: getComputedStyle(document.documentElement).getPropertyValue('--ok').trim(),
      focusables: document.querySelectorAll('button, input, select, textarea, a[href]').length
    })''')
    assert metrics['w'] <= metrics['client'], f'{name} {width}px overflows by {metrics["w"]-metrics["client"]}px'
    assert metrics['ribbon'], f'{name} missing screen ribbon'
    assert metrics['gold'].lower() == '#c9a86b', f'{name} wrong gold: {metrics["gold"]}'
    assert metrics['green'].lower() == '#558f6a', f'{name} wrong green: {metrics["green"]}'
    assert metrics['focusables'] > 0, f'{name}: no focusable controls'
    if name == 'guest.html' and width in (320, 390):
        tabs = page.locator('[role="tab"]')
        assert await tabs.count() == 5, 'guest tabs should total five'
        await tabs.nth(0).click()
        assert await tabs.nth(0).get_attribute('aria-selected') == 'true'
        await tabs.nth(0).press('ArrowRight')
        assert await tabs.nth(1).get_attribute('aria-selected') == 'true', 'ArrowRight did not select ranking'
        await tabs.nth(1).press('End')
        assert await tabs.nth(4).get_attribute('aria-selected') == 'true', 'End did not select history'
        await tabs.nth(4).press('Home')
        assert await tabs.nth(0).get_attribute('aria-selected') == 'true', 'Home did not return to overview'
        shown = await page.locator('[role="tabpanel"]:not([aria-hidden="true"])').count()
        assert shown == 1, f'guest exposed {shown} active panels'
    if name == 'login.html' and width == 390:
        # The production script imports Supabase over CDN; run the unchanged
        # inline UI logic with a fake ANONYMOUS auth client, not real accounts.
        source = (ROOT/'login.html').read_text(encoding='utf-8')
        module = re.search(r'<script type="module">([\s\S]*?)</script>', source)
        assert module, 'login module not found'
        script = re.sub(r"^\s*import \{ createClient \} from '[^']+';", '', module.group(1), count=1)
        stub = """const createClient=()=>({auth:{
          getUser:async()=>({data:{user:null},error:null}),
          getSession:async()=>({data:{session:null}}),
          onAuthStateChange:()=>({data:{subscription:{unsubscribe:()=>{}}}}),
          signUp:async()=>({data:{session:null},error:null}),
          signInWithPassword:async()=>({error:{message:'Offline-Test'}}),
          resetPasswordForEmail:async()=>({error:{message:'Offline-Test'}}),
          signOut:async()=>({error:null})
        }});"""
        await page.evaluate('async () => { '+stub+'\n'+script+'\n}')
        await page.locator('#showRegister').click()
        assert await page.locator('#registerView').is_visible(), 'registration panel not opened'
        await page.locator('#registerName').fill('Offline Test')
        await page.locator('#registerEmail').fill('offline@example.invalid')
        await page.locator('#registerPassword').fill('abcdefgh')
        await page.locator('#registerConfirm').fill('abcd1234')
        await page.locator('#registerBtn').click()
        assert 'Passwörter stimmen nicht' in (await page.locator('#message').inner_text())
        await page.locator('#showLogin').click()
        assert await page.locator('#loginView').is_visible(), 'login panel not restored'

    if name != 'guest.html' and width == 390:
        # Shared menu works from all delivered app routes. This intentionally
        # checks keyboard behavior without granting any user role.
        nav = (ROOT/'takeover-navigation.js').read_text(encoding='utf-8')
        # About:blank is used for safe offline rendering: give nav the same
        # page identity that the real URL would provide, without web access.
        nav = nav.replace("const atHome=page==='index.html';",
                          "const atHome=document.body.dataset.tlScreen==='index';")
        await page.evaluate(nav)
        menu = page.locator('#takeover-menu-open')
        assert await menu.count() == 1, f'{name}: shared menu button not initialized'
        await menu.click()
        assert await menu.get_attribute('aria-expanded') == 'true', f'{name}: menu did not open'
        # Unauthenticated visitors must not see these private menu options.
        role_entries = page.locator('.tl-menu-panel a[data-tl-admin], .tl-menu-panel a[data-tl-private]')
        for i in range(await role_entries.count()):
            assert not await role_entries.nth(i).is_visible(), f'{name}: private menu entry visible anonymously'
        await page.keyboard.press('Escape')
        assert await menu.get_attribute('aria-expanded') == 'false', f'{name}: Escape did not close drawer'
        await menu.click()
        assert await menu.get_attribute('aria-expanded') == 'true', f'{name}: drawer cannot reopen'
    if width in (320, 390) and name in ('boxer.html', 'coach.html', 'duels.html', 'challenges.html'):
        # Expand existing protected/dynamic containers in THIS isolated DOM
        # solely to catch horizontal overflow in their underlying layouts.
        # This does not bypass or exercise real authorization.
        ids = {
          'boxer.html':['content','studioPanelHistory','studioPanelDetails','trainingFormCard'],
          'coach.html':['content'],
          'duels.html':['app','invitePanel','liveOverviewSection'],
          'challenges.html':['coach','targetedAssignment']
        }[name]
        await page.evaluate('''(ids) => ids.forEach(id => {
          const el=document.getElementById(id);
          if(!el)return;
          el.classList.remove('hide','hidden');el.removeAttribute('hidden');
          el.style.display='block';
        })''',ids)
        expanded = await page.evaluate('({w:document.documentElement.scrollWidth,c:document.documentElement.clientWidth})')
        assert expanded['w']<=expanded['c'], f'{name} {width}px expanded layout overflows by {expanded["w"]-expanded["c"]}px'
    await page.close()
    return {'page':name,'width':width,'overflow':0,'browser_errors':len(errs)}


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox','--disable-dev-shm-usage'])
        results=[]
        try:
            for name in PAGES:
                for width in VIEWPORTS:
                    results.append(await inspect_page(browser,name,width))
                print('PASS',name,'320/390/768/1440',flush=True)
        finally:
            await browser.close()
    print('PASS:',len(PAGES),'pages x',len(VIEWPORTS),'widths =',len(results),'real offline Chromium views; guest keyboard tabs, navigation and colour tokens',flush=True)
    (ROOT/'docs'/'REDESIGN_CHROMIUM_OFFLINE_2026-10-19.json').write_text(json.dumps(results,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')


if __name__=='__main__':
    asyncio.run(main())
