"""Project-authored synthetic vectors; none are claimed as producer exports."""
from __future__ import annotations

import random
from xml.sax.saxutils import escape

PARAMS = '<Params><Addon>Fixture.esp</Addon><Source>english</Source><Dest>japanese</Dest><Version>2</Version></Params>'
ENTRY = '<String List="0"><EDID>FixtureEdid</EDID><REC>WEAP:FULL</REC><Source>Hello</Source><Dest>こんにちは</Dest></String>'


def document(entry: str = ENTRY, params: str = PARAMS) -> str:
    return f'<SSTXMLRessources>{params}<Content>{entry}</Content></SSTXMLRessources>'


def corpus():
    base = document()
    cases = []
    def add(name, raw, accepted, group='fixed'):
        cases.append({'name': name, 'raw': raw.encode('utf-8') if isinstance(raw, str) else raw, 'accepted': accepted, 'group': group})
    add('basic', base, True)
    add('bom', b'\xef\xbb\xbf' + base.encode(), True)
    add('declaration', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + base, True)
    add('declaration-single', "<?xml\tversion = '1.0' encoding='utf-8' standalone='no'?>" + base, True)
    add('empty-content', document(''), True)
    add('content-first', '<SSTXMLRessources><Content>' + ENTRY + '</Content>' + PARAMS + '</SSTXMLRessources>', True)
    for name, suffix in [('lf','\n'),('cr','\r'),('crlf','\r\n')]:
        add('suffix-' + name, base + suffix, True)
    for name, source, dest in [
        ('empty', '', ''), ('whitespace',' \t ',' \n '), ('entities','&lt;&gt;&amp;&apos;&quot;','&amp;lt;'),
        ('refs','&#13;&#xD;&#10;&#9;','&#x1F600;&#128512;'),
        ('eol','a\rb\r\nc\nd','x\r\ny'), ('cdata','<![CDATA[<&\r\n]]>','a<!--omit--><![CDATA[日]]>b'),
        ('escaped-cdata-close',']]&gt;', '&#93;&#93;>'), ('unicode','日😀é','Ω𐀀'),
    ]:
        add('text-' + name, document(ENTRY.replace('Hello', source).replace('こんにちは', dest)), True)
    add('self-close', document(ENTRY.replace('<Source>Hello</Source>', '<Source />').replace('<Dest>こんにちは</Dest>', '<Dest/>')), True)
    add('comments', '<!--before-->' + base.replace('<Content>', '<Content><!--inside-->') + '<!--after-->', True)
    add('container-ref-space', base.replace('<Content>', '<Content>&#32;'), True)
    for value in ['123456','FFFFFF','1000000','FFFFFFFF','abcdef','000000']:
        add('sid-' + value, document(ENTRY.replace('List="0"', f'List="0" sID="{value}"')), True)
    for value in ['', '12345','123456789','0x123456','GGGGGG',' 123456']:
        add('bad-sid-' + str(len(cases)), document(ENTRY.replace('List="0"', f'List="0" sID="{value}"')), False)
    for value in ['1','2']:
        add('partial-' + value, document(ENTRY.replace('List="0"', f'List="0" Partial="{value}"')), True)
    for pair in [('0','0'),('1','1'),('0','65535'),('65535','65535'),('0001','0002')]:
        add('occurrence-' + '-'.join(pair), document(ENTRY.replace('<REC>', f'<REC id="{pair[0]}" idMax="{pair[1]}">')), True)
    for attrs in ['id="1"','idMax="1"','id="2" idMax="1"','id="0" idMax="65536"','id="-1" idMax="1"','id=" 0" idMax="1"']:
        add('bad-occurrence-' + str(len(cases)), document(ENTRY.replace('<REC>', '<REC ' + attrs + '>')), False)
    add('fuz', document(ENTRY.replace('</String>', '<FuzInfo><responseId>7</responseId><Fuz>not/a/file.fuz</Fuz><Fuz/></FuzInfo></String>')), True)
    add('bracket-id', document(ENTRY.replace('FixtureEdid','[FE123456]')), True)
    add('cache-id', document(ENTRY.replace('FixtureEdid','12345678|12345678|0|1')), True)
    add('rec-case', document(ENTRY.replace('WEAP:FULL','weap:Full')), True)
    for name, old, new in [
        ('list-missing',' List="0"',''), ('list-range','List="0"','List="3"'), ('list-leading-zero','List="0"','List="00"'),
        ('partial-zero','List="0"','List="0" Partial="0"'), ('duplicate-attr','List="0"','List="0" List="1"'),
        ('missing-source','<Source>Hello</Source>',''), ('missing-dest','<Dest>こんにちは</Dest>',''),
        ('duplicate-source','<Source>Hello</Source>','<Source>Hello</Source><Source/>'),
        ('empty-edid','FixtureEdid',''), ('bad-rec','WEAP:FULL','WEAP:FULLX'), ('rec-space','WEAP:FULL','WEAP:FUL '),
        ('raw-less','Hello','x<y'), ('raw-amp','Hello','x&y'), ('raw-cdata-close','Hello',']]>'),
        ('unknown-entity','Hello','&unknown;'), ('nul-ref','Hello','&#0;'), ('surrogate-ref','Hello','&#xD800;'),
        ('out-of-range-ref','Hello','&#x110000;'), ('upper-X-ref','Hello','&#X41;'), ('empty-ref','Hello','&#;'),
        ('comment-double','Hello','<!--bad--comment-->'), ('unclosed-cdata','Hello','<![CDATA[bad'),
        ('unknown-child','<Source>Hello</Source>','<Unknown/>'), ('nested-leaf','Hello','<Dest/>'),
        ('unknown-attr','List="0"','List="0" Other="1"'), ('namespace','List="0"','List="0" xmlns=""'),
        ('bad-close','</String>','</string>'), ('unquoted','List="0"','List=0'), ('adjacent-attrs','List="0"','List="0"Partial="1"'),
        ('fuz-unknown','</String>','<FuzInfo><Other/></FuzInfo></String>'),
    ]:
        add('reject-' + name, document(ENTRY.replace(old,new)), False)
    for name, prefix in [('doctype','<!DOCTYPE SSTXMLRessources>'),('internal-entity','<!DOCTYPE SSTXMLRessources [<!ENTITY x "hello">]>'),('external-entity','<!DOCTYPE SSTXMLRessources SYSTEM "file:///must-not-be-read">'),('pi','<?work value?>'),('decl-version','<?xml version="1.1"?>'),('decl-encoding','<?xml version="1.0" encoding="ISO-8859-1"?>'),('decl-ref','<?xml version="&#x31;.0"?>'),('decl-order','<?xml encoding="UTF-8" version="1.0"?>'),('late-decl',' <?xml version="1.0"?>'),('ref-prolog','&#32;'),('cdata-prolog','<![CDATA[ ]]>')]:
        add('reject-' + name, prefix + base, False)
    add('reject-ref-epilog', base + '&#x20;', False)
    add('reject-second-root', base + '<SSTXMLRessources/>', False)
    add('reject-truncated', base[:-1], False)
    add('reject-empty', b'', False)
    for name, invalid in [('overlong',b'\xc0\x80'),('surrogate',b'\xed\xa0\x80'),('too-large',b'\xf4\x90\x80\x80'),('truncated',b'\xe6\x97'),('nul',b'\x00'),('control',b'\x01'),('nonchar',b'\xef\xbf\xbe')]:
        add('reject-utf8-' + name, base.encode().replace(b'Hello',invalid), False)
    rng = random.Random(5005)
    alphabet = ['a','Z',' ', '\t','\n','\r','日','😀','é','&','<','>',"'",'"',']']
    for i in range(64):
        source = ''.join(rng.choice(alphabet) for _ in range(rng.randrange(30)))
        dest = ''.join(rng.choice(alphabet) for _ in range(rng.randrange(30)))
        encoded = ENTRY.replace('Hello', escape(source)).replace('こんにちは', escape(dest))
        if i % 2:
            encoded = encoded.replace('List="0"', "List='2'")
        add(f'seed-5005-{i}',document(encoded),True,'generated')
    assert len({x['name'] for x in cases}) == len(cases)
    return cases
