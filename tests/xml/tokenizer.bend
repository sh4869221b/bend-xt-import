import Base
import ../../xml/types.bend as T
import ../../xml/tokenizer.bend as L

type Collected is Data:
  Collected{valid: Bool, text: String, attrs: String}

def event(+event: T.XmlEvent, +collected: Collected) -> Collected:
  match event collected:
    case T.EvText{+value,+origin,+span} Collected{+valid,+text,+attrs}: Collected{valid,SCon{Chr{value},text},attrs}
    case T.EvAttributeScalar{+value,+origin,+span} Collected{+valid,+text,+attrs}: Collected{valid,text,SCon{Chr{value},attrs}}
    case _ _: collected

def slot(+slot: T.EventSlot, +collected: Collected) -> Collected:
  match slot:
    case T.NoEvent{}: collected
    case T.SomeEvent{+item}: event(item,collected)

def result(+collected: Collected, +result: T.LexResult) -> Collected:
  match collected result:
    case Collected{+valid,+text,+attrs} T.LexFailed{+error}: Collected{False{},text,attrs}
    case _ T.Events{+count,+a,+b,+c}: slot(c,slot(b,slot(a,collected)))

def ended(+collected: Collected, p: L.State & T.LexResult) -> Collected:
  (state,events) = p
  result(collected,events)

def pushed(+tail: String, +position: U32, +collected: Collected, p: L.State & T.LexResult) -> L.State & Collected:
  (state,events) = p
  (state,result(collected,events))

def feed(+text: String, +position: U32, p: L.State & Collected) -> Collected:
  match text:
    case SNil{}:
      (state,collected) = p
      ended(collected,L.finish(state,T.Position{position,1,U32.inc(position)}))
    case SCon{Chr{+value},+tail}:
      (state,collected) = p
      feed(tail,U32.inc(position),pushed(tail,position,collected,L.push(state,T.Scalar{value,T.Span{T.Position{position,1,U32.inc(position)},T.Position{U32.inc(position),1,U32.add(position,2)}}})))

def verified(+id: U32, +valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,70,U32.show(id))

def compare(+id: U32, +expected: Bool, +text: String, +attrs: String, +actual: Collected) -> IO(Unit):
  match expected actual:
    case True{} Collected{True{},+actualText,+actualAttrs}: verified(id,Bool.and(String.eq(text,String.reverse(actualText)),String.eq(attrs,String.reverse(actualAttrs))))
    case False{} Collected{False{},+a,+b}: IO.pure(Unit,Unit{})
    case _ _: IO.die(Unit,70,U32.show(id))

def check(+id: U32, +input: String, +expected: Bool, +text: String, +attrs: String) -> IO(Unit):
  compare(id,expected,text,attrs,feed(input,0,(L.init(64,64),Collected{True{},"",""})))

def main() -> IO(Unit):
  do IO<Unit>:
    check(1,"<SSTXMLRessources/>",True{},"","")
    check(2," \t\n<!--x--><SSTXMLRessources/>\n<!--end--> ",True{},"","")
    check(3,"<?xml version=\"1.0\"?><SSTXMLRessources/>",True{},"","")
    check(4,"<?xml version = '1.0' encoding = 'utf-8' standalone = 'yes' ?><SSTXMLRessources/>",True{},"","")
    check(5,"<?xml version=\"1.0\" standalone=\"no\"?><SSTXMLRessources/>",True{},"","")
    check(6,"<Source>&amp;&lt;&gt;&apos;&quot;</Source>",True{},"&<>'\"","")
    check(7,"<Source>&amp;lt;</Source>",True{},"&lt;","")
    check(8,"<Source>&#13;&#xD;&#10;&#9;</Source>",True{},"\r\r\n\t","")
    check(9,"<Source><![CDATA[a<&]]]]>b</Source>",True{},"a<&]]b","")
    check(10,"<Source>]]&gt;</Source>",True{},"]]>","")
    check(11,"<Source>&#93;&#93;&gt;</Source>",True{},"]]>","")
    check(12,"<Source>a<!--drop-->b<![CDATA[c]]>d</Source>",True{},"abcd","")
    check(13,"<String List=\"&#48;\" Partial='2' sID=\"ABCDEF\"/>",True{},"","02ABCDEF")
    check(14,"<String List=\"\t\n \" sID=\"&#9;&#10;&#13;\"/>",True{},"","   \t\n\r")
    check(15,"<SSTXMLRessources>&#32;</SSTXMLRessources>",True{}," ","")
    check(16,"",False{},"","")
    check(17," ",False{},"","")
    check(18,"<!--x-->",False{},"","")
    check(19,"<Source>",False{},"","")
    check(20,"<Source></Source",False{},"","")
    check(21,"<Source>&amp</Source>",False{},"","")
    check(22,"<Source>&#;</Source>",False{},"","")
    check(23,"<Source>&#x;</Source>",False{},"","")
    check(24,"<Source>&#X20;</Source>",False{},"","")
    check(25,"<Source>&wat;</Source>",False{},"","")
    check(26,"<Source>&#0;</Source>",False{},"","")
    check(27,"<Source>&#xD800;</Source>",False{},"","")
    check(28,"<Source>&#xFFFE;</Source>",False{},"","")
    check(29,"<Source>&#1114112;</Source>",False{},"","")
    check(30,"<Source>]]></Source>",False{},"","")
    check(31,"<Source><![CDATA[x</Source>",False{},"","")
    check(32,"<Source><!--x--x--></Source>",False{},"","")
    check(33,"<Source><!--x---></Source>",False{},"","")
    check(34,"<Source><!--x</Source>",False{},"","")
    check(35,"<Source/>x",False{},"","")
    check(36,"&#32;<SSTXMLRessources/>",False{},"","")
    check(37,"<SSTXMLRessources/>&#x20;",False{},"","")
    check(38,"<![CDATA[ ]]><SSTXMLRessources/>",False{},"","")
    check(39,"<?target x?><SSTXMLRessources/>",False{},"","")
    check(40," <?xml version=\"1.0\"?><SSTXMLRessources/>",False{},"","")
    check(41,"<?XML version=\"1.0\"?><SSTXMLRessources/>",False{},"","")
    check(42,"<?xml?><SSTXMLRessources/>",False{},"","")
    check(43,"<?xml version=\"1.1\"?><SSTXMLRessources/>",False{},"","")
    check(44,"<?xml encoding=\"UTF-8\" version=\"1.0\"?><SSTXMLRessources/>",False{},"","")
    check(45,"<?xml version=\"1.0\" version=\"1.0\"?><SSTXMLRessources/>",False{},"","")
    check(46,"<?xml version=\"&#x31;.0\"?><SSTXMLRessources/>",False{},"","")
    check(47,"<?xml version=\"1.0\" encoding=\"UTF&#45;8\"?><SSTXMLRessources/>",False{},"","")
    check(48,"<?xml version=\"1.0\" standalone=\"&#121;es\"?><SSTXMLRessources/>",False{},"","")
    check(49,"<?xml version=\"1.0\" encoding=\"UTF-16\"?><SSTXMLRessources/>",False{},"","")
    check(50,"<?xml version=\"1.0\" standalone=\"yes\"encoding=\"UTF-8\"?><SSTXMLRessources/>",False{},"","")
    check(51,"<!DOCTYPE Source SYSTEM \"file:///tmp/sentinel\"><Source/>",False{},"","")
    check(52,"<!ENTITY x \"y\"><Source/>",False{},"","")
    check(53,"<Unknown/>",False{},"","")
    check(54,"<Source xmlns=\"\"/>",False{},"","")
    check(55,"<xi:include/>",False{},"","")
    check(56,"<String List=\"0\"Partial=\"1\"/>",False{},"","")
    check(57,"<String List=0/>",False{},"","")
    check(58,"<String List \"0\"/>",False{},"","")
    check(59,"<String List=\"<\"/>",False{},"","")
    check(60,"<String List=\"&\"/>",False{},"","")
    check(61,"<Source/ >",False{},"","")
    check(62,"<Source></Source x>",False{},"","")
    check(63,"<Source/><Source/>",False{},"","")
    check(64,"</Source>",False{},"","")
    IO.print("tokenizer-golden-64")
