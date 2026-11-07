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

def show(actual: Collected) -> IO(Unit):
  match actual:
    case Collected{True{},text,attrs}:
      do IO<Unit>:
        IO.print("accepted")
        IO.print(String.reverse(text))
        IO.print(String.reverse(attrs))
    case _: IO.print("rejected")

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> input <> Nil{}: show(feed(input,0,(L.init(64,64),Collected{True{},"",""})))
    case _: IO.die(Unit,64,"one XML argument required")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
