"""Freeze Ulrich Neumerkel's executable comparison inputs with attribution."""
from pathlib import Path
from urllib.request import urlopen
from html.parser import HTMLParser
import re,json,hashlib,datetime
HERE=Path(__file__).resolve().parent
class Cells(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.row=None;self.cell=None
 def flush(self):
  if self.cell is not None and self.row is not None:self.row.append(self.cell.strip())
  self.cell=None
 def handle_starttag(self,t,a):
  if t=='tr':
   self.flush()
   if self.row:self.rows.append(self.row)
   self.row=[]
  if t in ['td','th']:self.flush();self.cell=''
  if t=='br' and self.cell is not None:self.cell+='\n'
 def handle_data(self,s):
  if self.cell is not None:self.cell+=s
 def handle_endtag(self,t):
  if t in ['td','th']:self.flush()
  if t=='tr':
   self.flush()
   if self.row:self.rows.append(self.row)
   self.row=None
records=[];data={}
for name,url in [('comparison.html','https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase'),('phrase_quad.pl','https://www.complang.tuwien.ac.at/ulrich/iso-prolog/phrase_quad.pl'),('errors-draft.html','https://www.complang.tuwien.ac.at/ulrich/iso-prolog/draft-8.18.1.3')]:
 b=urlopen(url,timeout=20).read();data[name]=b.decode();records.append({'file':name,'url':url,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)})
 # Freeze the functional query/answer listing; retain hashes rather than vendor full web pages.
 if name=='phrase_quad.pl':(HERE/name).write_bytes(b)
parser=Cells();parser.feed(data['comparison.html']);table={r[0]:r for r in parser.rows if len(r)>3}
s=data['phrase_quad.pl']; chunks=list(re.finditer(r'^([cf]?\d+)\s+\?-\s*(.*?)\n(?=\s{2,})',s,re.M));cases=[]
for i,m in enumerate(chunks):
 tail=s[m.end():chunks[i+1].start() if i+1<len(chunks) else len(s)].strip();id=m[1];row=table[id]
 cases.append({'id':id,'query':m[2].strip(),'expected_description':tail,'html_expected_description':row[2],'historical_swi':row[12] if len(row)>12 else None})
assert len(cases)==58 and len({c['id'] for c in cases})==58
(HERE/'cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
(HERE/'upstream-sources.json').write_text(json.dumps({'retrieved_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'author':'Ulrich Neumerkel / ISO Prolog comparison','sources':records,'note':'Expected outcomes are comparison-page evidence, not a certification against the complete published 2025 TS. Comparison SWI header is 9.3.17; individual cells may retain older comments.'},indent=2)+'\n')
print('Frozen',len(cases),'cases')
