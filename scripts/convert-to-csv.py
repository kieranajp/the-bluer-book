#!/usr/bin/env python3
import json, csv, re
from collections import defaultdict

# load Trello JSON
with open('recipes.json') as f:
    data = json.load(f)

# 1) Filter active cards
cards = {c['id']: c for c in data['cards'] if not c.get('closed')}

# 2) Extract labels
labels = {}
for c in cards.values():
    labels[c['id']] = [l['name'] for l in c.get('labels', []) if l.get('name')]

# 3) Extract attachments (all URLs, mark cover)
atts = defaultdict(list)
for a in data.get('attachments', []):
    cid, aid, url = a['idCard'], a['id'], a['url']
    if cid in cards and url:
        atts[cid].append({'id': aid, 'url': url})
# fallback: URLs in description
URL_RE = re.compile(r'https?://\S+')
for cid,c in cards.items():
    for m in URL_RE.finditer(c.get('desc','') or ''):
        atts[cid].append({'id': None, 'url': m.group()})

# 4) Extract checklist items
checklists = defaultdict(list)
for cl in data.get('checklists', []):
    cid = cl.get('idCard')
    if cid in cards:
        for it in cl.get('checkItems', []):
            checklists[cid].append(it['name'])

# 5) Extract comments
comments = defaultdict(list)
for act in data.get('actions', []):
    if act.get('type')=='commentCard':
        cid = act['data']['card']['id']
        txt = act['data']['text'].replace('\n',' ').strip()
        if cid in cards and txt:
            comments[cid].append(txt)

# 6) Write recipes.csv
with open('recipes.csv','w',newline='') as f:
    w=csv.writer(f)
    w.writerow(['id','name','description','cook_time','prep_time','servings','main_photo_id'])
    for cid,c in cards.items():
        # no cook/prep/servings data in Trello; leave blank
        w.writerow([cid,
                    c['name'],
                    c.get('desc','').replace('\n',' ').strip(),
                    '', '', '',
                    c.get('idAttachmentCover','') or ''])

# 7) Write labels.csv + recipe_label.csv
with open('labels.csv','w',newline='') as fl, open('recipe_label.csv','w',newline='') as frl:
    wl=csv.writer(fl); wrl=csv.writer(frl)
    wl.writerow(['uuid','name'])
    wrl.writerow(['recipe_id','label_id'])
    seen=set()
    for cid,lbls in labels.items():
        for name in lbls:
            if name not in seen:
                seen.add(name)
                wl.writerow(['',name])
            wrl.writerow([cid,name])

# 8) Write ingredients.csv + recipe_ingredient.csv
with open('ingredients.csv','w',newline='') as fi, open('recipe_ingredient.csv','w',newline='') as fri:
    wi=csv.writer(fi); wri=csv.writer(fri)
    wi.writerow(['uuid','name'])
    wri.writerow(['recipe_id','ingredient_id','unit_id','quantity'])
    seen=set()
    for cid,items in checklists.items():
        for ing in items:
            if ing not in seen:
                seen.add(ing)
                wi.writerow(['',ing])
            wri.writerow([cid,ing,'',''])

# 9) Write steps.csv
with open('steps.csv','w',newline='') as fs:
    ws=csv.writer(fs)
    ws.writerow(['uuid','recipe_id','step_order','description'])
    for cid,c in cards.items():
        # put full description as step 1
        ws.writerow(['',cid,1,c.get('desc','').strip()])

# 10) Write photos.csv
with open('photos.csv', 'w', newline='') as fp:
    wp = csv.writer(fp)
    wp.writerow(['uuid', 'url', 'entity_type', 'entity_id', 'created_at', 'updated_at'])
    for cid, attachments in atts.items():
        cover_id = cards[cid].get('idAttachmentCover')
        for a in attachments:
            is_main = (a.get('id') == cover_id)
            entity_type = 'recipe'
            entity_id = cid
            wp.writerow(['', a['url'], entity_type, entity_id, '', ''])