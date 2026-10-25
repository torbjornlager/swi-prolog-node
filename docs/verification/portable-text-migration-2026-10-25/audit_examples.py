#!/usr/bin/env python3
"""Read-only inventory; parse source without executing directives or examples."""
import argparse,hashlib,json,subprocess,tempfile,re
import xml.etree.ElementTree as ET
from pathlib import Path
from html.parser import HTMLParser

class Blocks(HTMLParser):
    def __init__(self):super().__init__(convert_charrefs=True);self.blocks=[];self.block=None
    def handle_starttag(self,tag,attrs):
        if tag=='pre':self.block=dict(id=dict(attrs).get('id'),line=self.getpos()[0],text='')
    def handle_data(self,data):
        if self.block is not None:self.block['text']+=data
    def handle_endtag(self,tag):
        if tag=='pre' and self.block is not None:self.blocks.append(self.block);self.block=None

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--demonstrator-root',type=Path,required=True)
    p.add_argument('--native-root',type=Path,required=True)
    p.add_argument('--swipl',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();root=a.demonstrator_root.resolve();out=a.output;out.mkdir(parents=True,exist_ok=True)
    html=sorted((root/'web').glob('*tutorial.html'))
    sources=sorted(set(list((root/'Deployment').glob('shared_db*.pl'))+
        list((root/'examples/actors').glob('*.pl'))+list((root/'examples/jev').glob('*.pl'))+
        [root/'examples/services/model_service.pl',root/'examples/services/jev_service.pl',
         root/'prolog/web_prolog/shared_db.pl',root/'prolog/web_prolog/wasm/shared_db.pl',
         a.native_root/'prolog/web_prolog/shared_db.pl']))
    xml=sorted((root/'examples/statecharts').glob('*.xml'))
    files=html+sources+xml;before={str(f):sha(f) for f in files};records=[]
    for path in html:
        b=Blocks();b.feed(path.read_text())
        for entry in b.blocks:
            text=entry['text'];kind='prolog' if text.lstrip().startswith('?-') or text.lstrip().startswith('jev_decide(') else 'protocol/XML/other'
            flags=[]
            if kind=='prolog':
                if '"' in text:flags.append('double_quotes_review')
                for token in ['string(', 'string_length(', 'string_codes(', 'atom_codes(', 'char_code(']:
                    if token in text:flags.append('native_api:'+token)
            records.append(dict(path=str(path.relative_to(root)),kind=kind,flags=flags,**entry))
    (out/'tutorial-blocks.json').write_text(json.dumps(records,indent=2,ensure_ascii=False)+'\n')
    scanner=Path(__file__).with_name('scan_sources.pl')
    with tempfile.TemporaryDirectory(prefix='text-source-audit-') as temp:
        manifest=Path(temp)/'files.json';manifest.write_text(json.dumps(dict(files=list(map(str,sources)))))
        command=[str(a.swipl),'-q','-s',str(scanner),'-g','main,halt','--',str(manifest)]
        run=subprocess.run(command,capture_output=True,text=True,timeout=30)
        (out/'source-parser.stderr.log').write_text(run.stderr)
        if run.returncode:raise RuntimeError(run.stderr)
        source_records=json.loads(run.stdout)
        (out/'source-inventory.json').write_text(json.dumps(source_records,indent=2,ensure_ascii=False)+'\n')
    xml_records=[]
    for path in xml:
        try:
            document=ET.parse(path).getroot();fragments=[]
            for element in document.iter():
                if element.text and element.text.strip():
                    fragments.append(dict(element=element.tag,field='text',text=element.text.strip()))
                for key in ['on','if','options','goal']:
                    if key in element.attrib:fragments.append(dict(element=element.tag,field=key,text=element.attrib[key]))
            flagged=[f for f in fragments if '"' in f['text'] or re.search(r'\b(?:string|string_length)\s*\(',f['text'])]
            xml_records.append(dict(path=str(path.relative_to(root)),xml_status='parsed',
                prolog_fragment_count=len(fragments),review_fragments=flagged))
        except ET.ParseError as error:
            xml_records.append(dict(path=str(path.relative_to(root)),xml_status='error',detail=str(error)))
    (out/'statechart-fragments.json').write_text(json.dumps(xml_records,indent=2,ensure_ascii=False)+'\n')
    after={str(f):sha(f) for f in files};assert before==after
    summary=dict(tutorial_pages=len(html),tutorial_blocks=len(records),
        prolog_blocks=sum(r['kind']=='prolog' for r in records),
        prolog_quote_candidates=sum(bool(r['flags']) for r in records),
        prolog_source_files=len(sources),source_parse_errors=[r for r in source_records if r['status']!='parsed'],
        statechart_xml_files_hashed=len(xml),
        statechart_xml_parse_errors=sum(r['xml_status']=='error' for r in xml_records),
        statechart_review_fragments=sum(len(r.get('review_fragments',[])) for r in xml_records),
        caveat='XML is parsed and embedded fragments reviewed, not all Prolog fragments parsed/executed; all flags are review hints, not proof of compatibility.',
        examples_unchanged=before==after,sha256=before)
    (out/'audit-summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False)+'\n')
    print({k:v for k,v in summary.items() if k!='sha256'})
if __name__=='__main__':main()
