import Base
import ./error.bend as E
import ./utf8.bend as U8

def identity_byte(value: U32, offset: U32, valid: Bool) -> Result<&2, &2, E.Error, U32>:
  match valid:
    case True{}: Done{value}
    case False{}: Fail{E.InvalidEncoding{1,offset,1}}

def decode(value: U32, offset: U32) -> Result<&2, &2, E.Error, U32>:
  match value:
    case 128: Done{8364}
    case 130: Done{8218}
    case 131: Done{402}
    case 132: Done{8222}
    case 133: Done{8230}
    case 134: Done{8224}
    case 135: Done{8225}
    case 136: Done{710}
    case 137: Done{8240}
    case 138: Done{352}
    case 139: Done{8249}
    case 140: Done{338}
    case 142: Done{381}
    case 145: Done{8216}
    case 146: Done{8217}
    case 147: Done{8220}
    case 148: Done{8221}
    case 149: Done{8226}
    case 150: Done{8211}
    case 151: Done{8212}
    case 152: Done{732}
    case 153: Done{8482}
    case 154: Done{353}
    case 155: Done{8250}
    case 156: Done{339}
    case 158: Done{382}
    case 159: Done{376}
    case +n: identity_byte(n,offset,Bool.or(U32.is_lt(n,128),Bool.and(U32.is_ge(n,160),U32.is_le(n,255))))

def encode(value: U32, offset: U32) -> Result<&2, &2, E.Error, U32>:
  match value:
    case 8364: Done{128}
    case 8218: Done{130}
    case 402: Done{131}
    case 8222: Done{132}
    case 8230: Done{133}
    case 8224: Done{134}
    case 8225: Done{135}
    case 710: Done{136}
    case 8240: Done{137}
    case 352: Done{138}
    case 8249: Done{139}
    case 338: Done{140}
    case 381: Done{142}
    case 8216: Done{145}
    case 8217: Done{146}
    case 8220: Done{147}
    case 8221: Done{148}
    case 8226: Done{149}
    case 8211: Done{150}
    case 8212: Done{151}
    case 732: Done{152}
    case 8482: Done{153}
    case 353: Done{154}
    case 8250: Done{155}
    case 339: Done{156}
    case 382: Done{158}
    case 376: Done{159}
    case +n: identity_byte(n,offset,Bool.or(U32.is_lt(n,128),Bool.and(U32.is_ge(n,160),U32.is_le(n,255))))

def decoded(offset: U32, result: Result<&2, &2, E.Error, U32>) -> U8.Step:
  match result:
    case Fail{error}: U8.failed(error)
    case Done{scalar}: U8.Step{U8.State{0,0,0,0,U32.inc(offset)},Some{scalar}}

def step_valid(+offset: U32, byte: U32, valid: Bool) -> U8.Step:
  match valid:
    case False{}: U8.failed(E.Overflow{0,offset,1})
    case True{}: decoded(offset,decode(byte,offset))

def step(state: U8.State, byte: U32) -> U8.Step:
  match state:
    case U8.Broken{error}: U8.failed(error)
    case U8.State{0,value,minimum,start,+offset}: step_valid(offset,byte,U32.is_lt(offset,4294967295))
    case U8.State{remaining,value,minimum,start,offset}: U8.failed(E.InternalInvariant{30})

def encoded(r: Result<&2, &2, E.Error, U32>) -> Result<&2, &2, E.Error, U8.Encoded>:
  match r:
    case Fail{error}: Fail{error}
    case Done{byte}: Done{U8.Encoded{1,byte,0,0,0}}

def encode_packet(value: U32, offset: U32) -> Result<&2, &2, E.Error, U8.Encoded>:
  encoded(encode(value,offset))
