import Base
import ../../plugin/types.bend as T
import ./support.bend as H
import ./runner.bend as Run

def kind_valid(kind: U32, +count: U32) -> Bool:
  match kind:
    case 0: U32.is_le(count,2000001)
    case 1: U32.is_le(count,8000001)
    case 2: U32.is_le(count,65)
    case 3: U32.is_le(count,65535)
    case 4: U32.is_le(count,33554433)
    case 5: U32.is_le(count,33554433)
    case 6: U32.is_le(count,268435457)
    case 7: Bool.and(U32.is_le(48,count),U32.is_le(count,268435457))
    case _: False{}

def invoke(kind: U32, count: U32, chunk: U32, output: U32, copying: U32, limits: T.Limits, work: U32, live: U32, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,2,"synthetic resource argument outside tested bounds")
    case True{}: Run.run(H.synthetic(kind,count),chunk,output,limits,True{},U32.is_eq(copying,1),work,live)

def checked(+kind: U32, +count: U32, +chunk: U32, +output: U32, +copying: U32, limits: T.Limits, work: U32, live: U32) -> IO(Unit):
  invoke(kind,count,chunk,output,copying,limits,work,live,Bool.and(kind_valid(kind,count),Bool.and(U32.is_le(copying,1),Bool.and(Bool.and(U32.is_le(1,chunk),U32.is_le(chunk,65536)),Bool.and(U32.is_le(1,output),U32.is_le(output,65536))))))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> kind <> count <> chunk <> output <> copy <> Nil{}:
      do IO<Unit>:
        kind : U32 <- H.number(kind)
        count : U32 <- H.number(count)
        chunk : U32 <- H.number(chunk)
        output : U32 <- H.number(output)
        copy : U32 <- H.number(copy)
        checked(kind,count,chunk,output,copy,T.defaults(),1073741824,268435456)
    case _ <> kind <> count <> chunk <> output <> copy <> source <> payload <> records <> objects <> subs <> depth <> work <> live <> Nil{}:
      do IO<Unit>:
        kind : U32 <- H.number(kind)
        count : U32 <- H.number(count)
        chunk : U32 <- H.number(chunk)
        output : U32 <- H.number(output)
        copy : U32 <- H.number(copy)
        source : U32 <- H.number(source)
        payload : U32 <- H.number(payload)
        records : U32 <- H.number(records)
        objects : U32 <- H.number(objects)
        subs : U32 <- H.number(subs)
        depth : U32 <- H.number(depth)
        work : U32 <- H.number(work)
        live : U32 <- H.number(live)
        checked(kind,count,chunk,output,copy,T.Limits{source,payload,records,objects,subs,depth},work,live)
    case _: IO.die(Unit,2,"KIND COUNT CHUNK OUT COPY [SOURCE PAYLOAD RECORDS OBJECTS SUBRECORDS DEPTH WORK LIVE]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
