import Base
import ../../plugin/types.bend as T
import ./support.bend as H
import ./runner.bend as Run

def invoke(fixture: H.Fixture, chunk: U32, output: U32, limits: T.Limits, work: U32, live: U32, valid: Bool) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,2,"chunk/output must be in 1..65536")
    case True{}: Run.run(fixture,chunk,output,limits,False{},True{},work,live)

def checked(fixture: H.Fixture, +chunk: U32, +output: U32, limits: T.Limits, work: U32, live: U32) -> IO(Unit):
  invoke(fixture,chunk,output,limits,work,live,Bool.and(Bool.and(U32.is_le(1,chunk),U32.is_le(chunk,65536)),Bool.and(U32.is_le(1,output),U32.is_le(output,65536))))

def command(args: List<String>) -> IO(Unit):
  match args:
    case _ <> hex <> chunk <> output <> Nil{}:
      do IO<Unit>:
        fixture : H.Fixture <- H.fixture(hex)
        chunk : U32 <- H.number(chunk)
        output : U32 <- H.number(output)
        checked(fixture,chunk,output,T.defaults(),1073741824,268435456)
    case _ <> hex <> chunk <> output <> source <> payload <> records <> objects <> subs <> depth <> work <> live <> Nil{}:
      do IO<Unit>:
        fixture : H.Fixture <- H.fixture(hex)
        chunk : U32 <- H.number(chunk)
        output : U32 <- H.number(output)
        source : U32 <- H.number(source)
        payload : U32 <- H.number(payload)
        records : U32 <- H.number(records)
        objects : U32 <- H.number(objects)
        subs : U32 <- H.number(subs)
        depth : U32 <- H.number(depth)
        work : U32 <- H.number(work)
        live : U32 <- H.number(live)
        checked(fixture,chunk,output,T.Limits{source,payload,records,objects,subs,depth},work,live)
    case _: IO.die(Unit,2,"HEX CHUNK OUT [SOURCE PAYLOAD RECORDS OBJECTS SUBRECORDS DEPTH WORK LIVE]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    command(args)
