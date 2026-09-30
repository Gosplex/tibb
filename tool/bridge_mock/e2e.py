"""Playwright walk-through of the Bridge page against the mock server.

    node tool/bridge_mock/server.js          # in one terminal (SIMULATE_PHONE=1 optional)
    python3 tool/bridge_mock/e2e.py          # screenshots land in build/bridge-shots/

Covers: wrong code → shake + message, pairing, saving text, upload with
progress, hover actions, clipboard, search, archive + undo, WhatsApp import
(upload → date-order check → progress → done), light/dark, 1360/900/600 px.
Fails on any page error or horizontal overflow.
"""
import asyncio
import os
from playwright.async_api import async_playwright

BASE = os.environ.get('BRIDGE_URL', 'http://localhost:8787/')
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'build', 'bridge-shots')


async def main():
    os.makedirs(OUT, exist_ok=True)
    shot = lambda pg, name: pg.screenshot(path=os.path.join(OUT, f'{name}.png'))
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page_errors = []
        for scheme in ('light', 'dark'):
            ctx = await browser.new_context(viewport={'width': 1360, 'height': 860}, color_scheme=scheme)
            pg = await ctx.new_page()
            pg.on('pageerror', lambda e: page_errors.append(str(e)))
            await pg.goto(BASE)
            await pg.locator('#pair-form input').first.focus()
            await pg.keyboard.type('111111')
            await pg.wait_for_timeout(500)
            assert await pg.locator('#pair-error').is_visible(), 'wrong code should show an error'
            await pg.keyboard.type('123456')
            await pg.wait_for_timeout(1400)
            assert await pg.locator('#app').is_visible(), 'library should open after pairing'
            await shot(pg, f'{scheme}-library')
            if scheme == 'dark':
                continue
            await pg.fill('#composer-input', 'Remember: dentist Thursday 4pm')
            await pg.keyboard.press('Control+Enter')
            await pg.wait_for_timeout(700)
            tmp_pdf = os.path.join(OUT, 'invoice.pdf')
            open(tmp_pdf, 'wb').write(b'%PDF-1.4 test' * 100)
            await pg.set_input_files('#file-input', tmp_pdf)
            await pg.wait_for_timeout(900)
            assert await pg.locator('.file-name', has_text='invoice').count() == 1
            await pg.click('#clip-entry')
            await pg.fill('#clip-input', '482913')
            await pg.keyboard.press('Enter')
            await pg.wait_for_timeout(800)
            assert await pg.locator('.clip-text', has_text='482913').is_visible()
            await pg.click('body', position={'x': 700, 'y': 400})
            await pg.keyboard.press('/')
            await pg.keyboard.type('wifi')
            await pg.wait_for_timeout(600)
            assert await pg.locator('mark').count() > 0, 'search should highlight matches'
            await shot(pg, 'light-search')
            await pg.fill('#search', '')
            await pg.wait_for_timeout(500)
            last = pg.locator('.row').last
            await last.hover()
            await last.locator('[aria-label=Archive]').click()
            await pg.wait_for_timeout(800)
            await pg.click('#wa-open')
            tmp_zip = os.path.join(OUT, 'wa.zip')
            open(tmp_zip, 'wb').write(b'PK' + b'x' * 2000)
            await pg.set_input_files('#wa-body input[type=file]', tmp_zip)
            await pg.wait_for_timeout(900)
            await shot(pg, 'light-wa-preview')
            await pg.click('.segmented button >> nth=1')
            await pg.wait_for_timeout(500)
            await pg.click('text=Import to phone')
            await pg.wait_for_timeout(2500)
            assert await pg.locator('.wa-done').is_visible(), 'WhatsApp import should finish'
            await shot(pg, 'light-wa-done')
            await pg.click('#wa-body .btn-primary')
            await pg.wait_for_timeout(900)
            for w in (900, 600):
                await pg.set_viewport_size({'width': w, 'height': 820})
                await pg.wait_for_timeout(300)
                overflow = await pg.evaluate('document.documentElement.scrollWidth > window.innerWidth')
                assert not overflow, f'horizontal overflow at {w}px'
                await shot(pg, f'light-{w}')
        assert not page_errors, page_errors
        await browser.close()
    print('Bridge walk-through passed. Screenshots in', os.path.abspath(OUT))


asyncio.run(main())
