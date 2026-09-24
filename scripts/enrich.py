#!/usr/bin/env python3

import os
import sys
import logging
import asyncio
import requests
import psycopg2
import extruct
from w3lib.html import get_base_url
from recipe_scrapers import scrape_me
from pint import UnitRegistry
from langdetect import detect
from googletrans import Translator
from bs4 import BeautifulSoup

# ── Configuration ───────────────────────────────────────────────────────────────
DB_HOST = 'SCHWENGEL.local'
DB_PORT = 25432
DB_NAME = 'recipes'
DB_USER = 'recipes'
DB_PASS = 'schwengelnas'

# ── Initialize utilities ────────────────────────────────────────────────────────
ureg       = UnitRegistry()
translator = Translator()
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

HEADERS = {
    'User-Agent': 'Mozilla/5.0',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en-US,en;q=0.5',
}

FALLBACK_CONFIG = {
    'hellofresh.de': {
        'ingredients': '.ingredients-list li',
        'instructions': '.recipe-instructions__step',
    },
    'ketogasm.com': {
        'ingredients': '.ingredients ul li',
        'instructions': '.directions p',
    },
    # add more domains here
}

def translate_sync(text: str) -> str:
    if not text:
        return text
    try:
        if detect(text) != 'en':
            return translator.translate(text, dest='en').text
    except Exception:
        pass
    return text

def convert_units(items: list[str]) -> list[str]:
    out=[]
    for item in items:
        parts=item.split()
        try:
            qty=ureg(parts[0]); g=qty.to('gram').magnitude
            rest=' '.join(parts[1:])
            out.append(f"{g:.1f} g {rest}")
        except:
            out.append(item)
    return out

def extract_recipe_from_html(html: str, url: str):
    try:
        data = extruct.extract(html, base_url=url,
                               syntaxes=['json-ld','microdata'])
        for entry in data.get('json-ld', []):
            if isinstance(entry, dict) and entry.get('@type')=='Recipe':
                ingr = entry.get('recipeIngredient',[]) or []
                instr = entry.get('recipeInstructions','')
                if isinstance(instr,list):
                    instr='\n'.join(
                        step.get('text',str(step)) if isinstance(step,dict) else str(step)
                        for step in instr
                    )
                return ingr, instr
        for entry in data.get('microdata', []):
            if isinstance(entry, dict) and entry.get('type')=='https://schema.org/Recipe':
                ingr = entry.get('recipeIngredient',[]) or []
                instr = entry.get('recipeInstructions','')
                if isinstance(instr,list):
                    instr='\n'.join(str(step) for step in instr)
                return ingr, instr
        soup = BeautifulSoup(html,'html.parser')
        ingr=[]; instr=[]
        for lst in soup.find_all(['ul','ol'], class_=lambda c: c and 'ingredient' in c.lower()):
            ingr.extend(li.get_text(strip=True) for li in lst.find_all('li'))
        for lst in soup.find_all(['ul','ol'], class_=lambda c: c and any(w in c.lower() for w in ('instruction','direction','method','step'))):
            instr.extend(li.get_text(strip=True) for li in lst.find_all('li'))
        if ingr or instr:
            return ingr, '\n'.join(instr)
    except Exception as e:
        logger.debug(f"extract error for {url}: {e}")
    return [], ''

def fetch_generic_recipe(url: str):
    try:
        if url.lower().endswith(('.pdf','.jpg','.png','.gif')):
            return [], ''
        res = requests.get(url, headers=HEADERS, timeout=15)
        if res.status_code==403:
            res = requests.get(url, headers={**HEADERS,'User-Agent':'Mozilla/5.0 (iPhone)'}, timeout=15)
        if res.status_code!=200:
            logger.warning(f"HTTP {res.status_code} for {url}")
            return [], ''
        return extract_recipe_from_html(res.text, url)
    except Exception as e:
        logger.warning(f"fetch error for {url}: {e}")
    return [], ''

async def process_recipe(cur, cid: str, url_str: str) -> bool:
    if not url_str:
        return False
    urls = [u for u in url_str.split(';') if u and not u.lower().endswith('.pdf')]
    for url in urls:
        domain = url.split('/')[2].lower()
        logger.info(f"[{cid}] trying {url}")
        try:
            s = scrape_me(url)
            ingr = s.ingredients()
            instr = s.instructions()
            logger.info(f"[{cid}] scraped with recipe-scrapers")
        except:
            ingr, instr = fetch_generic_recipe(url)
            if not (ingr or instr) and domain in FALLBACK_CONFIG:
                cfg = FALLBACK_CONFIG[domain]
                soup = BeautifulSoup(requests.get(url, headers=HEADERS).text,'html.parser')
                ingr = [li.get_text(strip=True) for li in soup.select(cfg['ingredients'])]
                instr = '\n'.join(p.get_text(strip=True) for p in soup.select(cfg['instructions']))
                logger.info(f"[{cid}] scraped with CSS fallback for {domain}")
        if not (ingr or instr):
            continue
        # translate & convert units
        ingr = [translate_sync(i) for i in ingr]
        ingr = convert_units(ingr)
        instr = translate_sync(instr.strip())
        cur.execute(
            "UPDATE recipes SET scraped_ingredients=%s, instructions=%s WHERE id=%s",
            ('\n'.join(ingr), instr, cid)
        )
        return True
    return False

async def main():
    logger.info("Connecting to DB...")
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )
    cur = conn.cursor()
    cur.execute("SELECT id, urls FROM recipes WHERE scraped_ingredients IS NULL;")
    rows = cur.fetchall()
    logger.info(f"Found {len(rows)} to process")
    for cid, url_str in rows:
        success = await process_recipe(cur, cid, url_str)
        if success:
            conn.commit()
    cur.close()
    conn.close()
    logger.info("Enrichment complete")

if __name__=='__main__':
    asyncio.run(main())
