# Tests only public buffer operations. A held work ticket makes failure deterministic;
# cancelling it funds readback on the same budget and owners. Copy setup costs
# 4 zero writes + 3 writes + 4 destination zero writes; each copy byte adds 2.
import Base
import ../../core/error.bend as E
import ../../core/budget.bend as B
import ../../core/bytes.bend as Bytes
import ./lib/buffer_assert.bend as A

def bounds_and_reuse_step_19(p24: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bv,xv) = p24
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(bv,xv))
    A.finished("buffer-bounds-invalid-bytes-reuse",B.Six{0,0,0,0,0,10},B.finish(end))

def bounds_and_reuse_step_18(p23: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bu,xu) = p23
  do IO<Unit>:
    p24 : B.Budget & Bytes.OwnedBytes <- A.read(33,Bytes.get(bu,xu,0))
    bounds_and_reuse_step_19(p24)

def bounds_and_reuse_step_17(p22: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bp,xp) = p22
  do IO<Unit>:
    p23 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.append(bp,xp,33))
    bounds_and_reuse_step_18(p23)

def bounds_and_reuse_step_16(p21: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (be,xe) = p21
  do IO<Unit>:
    p22 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{0,1,0},Bytes.put(be,xe,0,9))
    bounds_and_reuse_step_17(p22)

def bounds_and_reuse_step_15(p18: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bg,xg) = p18
  do IO<Unit>:
    xgm : Bytes.OwnedBytes <- A.metadata(4,4,1,1,Bytes.metadata(xg))
    cleared : Bytes.OwnedBytes = Bytes.clear(xgm)
    clearedm : Bytes.OwnedBytes <- A.metadata(0,4,1,1,Bytes.metadata(cleared))
    p21 : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{0,1,0},Bytes.get(bg,clearedm,0))
    bounds_and_reuse_step_16(p21)

def bounds_and_reuse_step_14(p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bf,xf) = p17
  do IO<Unit>:
    p18 : B.Budget & Bytes.OwnedBytes <- A.read(255,Bytes.get(bf,xf,3))
    bounds_and_reuse_step_15(p18)

def bounds_and_reuse_step_13(p16: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (ba,xa) = p16
  do IO<Unit>:
    p17 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{4,1,4},Bytes.append(ba,xa,8))
    bounds_and_reuse_step_14(p17)

def bounds_and_reuse_step_12(p15: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (br,xr) = p15
  do IO<Unit>:
    p16 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.append(br,xr,255))
    bounds_and_reuse_step_13(p16)

def bounds_and_reuse_step_11(p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,x11) = p13
  do IO<Unit>:
    bb : B.Budget <- A.usage(B.Six{0,0,0,0,135168,5},B.zero(),B.inspect(b11))
    p15 : B.Budget & Bytes.OwnedBytes <- A.read(17,Bytes.get(bb,x11,0))
    bounds_and_reuse_step_12(p15)

def bounds_and_reuse_step_10(p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b10,x10) = p12
  do IO<Unit>:
    p13 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.InvalidByte{4294967295},Bytes.append(b10,x10,4294967295))
    bounds_and_reuse_step_11(p13)

def bounds_and_reuse_step_9(p11: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b9,x9) = p11
  do IO<Unit>:
    p12 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.InvalidByte{256},Bytes.append(b9,x9,256))
    bounds_and_reuse_step_10(p12)

def bounds_and_reuse_step_8(p10: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b8,x8) = p10
  do IO<Unit>:
    p11 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.InvalidByte{4294967295},Bytes.put(b8,x8,0,4294967295))
    bounds_and_reuse_step_9(p11)

def bounds_and_reuse_step_7(p9: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b7,x7) = p9
  do IO<Unit>:
    p10 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.InvalidByte{256},Bytes.put(b7,x7,0,256))
    bounds_and_reuse_step_8(p10)

def bounds_and_reuse_step_6(p8: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b6,x6) = p8
  do IO<Unit>:
    p9 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{4294967295,1,3},Bytes.put(b6,x6,4294967295,99))
    bounds_and_reuse_step_7(p9)

def bounds_and_reuse_step_5(p7: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b5,x5) = p7
  do IO<Unit>:
    p8 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{3,1,3},Bytes.put(b5,x5,3,99))
    bounds_and_reuse_step_6(p8)

def bounds_and_reuse_step_4(p6: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{4294967295,1,3},Bytes.get(b4,x4,4294967295))
    bounds_and_reuse_step_5(p7)

def bounds_and_reuse_step_3(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p5
  do IO<Unit>:
    p6 : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{4,1,3},Bytes.get(b3,x3,4))
    bounds_and_reuse_step_4(p6)

def bounds_and_reuse_step_2(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{3,1,3},Bytes.get(b2,x2,3))
    bounds_and_reuse_step_3(p5)

def bounds_and_reuse_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    x1m : Bytes.OwnedBytes <- A.metadata(3,4,1,1,Bytes.metadata(x1))
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1m,0,17))
    bounds_and_reuse_step_2(p4)

def bounds_and_reuse() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,1048576,100}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    bounds_and_reuse_step_1(p2)

def new_failed(expected: E.Error, p: B.Budget & Result<&2, &1, E.Error, Bytes.OwnedBytes>) -> IO(Unit):
  (budget,result) = p
  match result:
    case Fail{error}:
      do IO<Unit>:
        A.check("new preflight error",A.error_equal(expected,error))
        A.finished("buffer-new-preflight",B.zero(),B.finish(budget))
    case _: IO.die(Unit,70,"new should fail before allocation")

def new_preflight() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,65536,0}))
    new_failed(E.Bounds{0,65537,65536},Bytes.new(b0,65537))

def work_failures_step_9(p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,x11) = p13
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(b11,x11))
    A.finished("buffer-work-failure-preserves-content",B.Six{0,0,0,0,0,8},B.finish(end))

def work_failures_step_8(p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b10,x10) = p12
  do IO<Unit>:
    p13 : B.Budget & Bytes.OwnedBytes <- A.read(0,Bytes.get(b10,x10,2))
    work_failures_step_9(p13)

def work_failures_step_7(p11: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b9,x9) = p11
  do IO<Unit>:
    p12 : B.Budget & Bytes.OwnedBytes <- A.read(0,Bytes.get(b9,x9,1))
    work_failures_step_8(p12)

def work_failures_step_6(ticket: B.Reservation, p7: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b6,x6) = p7
  do IO<Unit>:
    x6m : Bytes.OwnedBytes <- A.metadata(3,4,1,1,Bytes.metadata(x6))
    b7 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,5},B.Six{0,0,0,0,4096,10},B.inspect(b6))
    b8 : B.Budget <- A.cancelled(B.cancel(b7,ticket))
    p11 : B.Budget & Bytes.OwnedBytes <- A.read(71,Bytes.get(b8,x6m,0))
    work_failures_step_7(p11)

def work_failures_step_5(ticket: B.Reservation, p6: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b5,x5) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.ResourceLimit{5,15,15,1},Bytes.append(b5,x5,90))
    work_failures_step_6(ticket,p7)

def work_failures_step_4(ticket: B.Reservation, p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.ResourceLimit{5,15,15,1},Bytes.put(b4,x4,0,90))
    work_failures_step_5(ticket,p6)

def work_failures_step_3(x2: Bytes.OwnedBytes, p4: B.Budget & B.Reservation) -> IO(Unit):
  (b3,ticket) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.ResourceLimit{5,15,15,1},Bytes.get(b3,x2,0))
    work_failures_step_4(ticket,p5)

def work_failures_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b2,B.work(10)))
    work_failures_step_3(x2,p4)

def work_failures_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,71))
    work_failures_step_2(p3)

def work_failures() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,1048576,15}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    work_failures_step_1(p2)

def copy_success_and_bounds_step_12(d3: Bytes.OwnedBytes, p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b14,s1) = p17
  do IO<Unit>:
    b15 : B.Budget <- A.dropped(Bytes.drop(b14,d3))
    b16 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,17},B.zero(),B.inspect(b15))
    end : B.Budget <- A.dropped(Bytes.drop(b16,s1))
    A.finished("buffer-copy-distinct-owner-two-visits",B.Six{0,0,0,0,0,17},B.finish(end))

def copy_success_and_bounds_step_11(sourcem: Bytes.OwnedBytes, p16: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b13,d3) = p16
  do IO<Unit>:
    p17 : B.Budget & Bytes.OwnedBytes <- A.read(42,Bytes.get(b13,sourcem,1))
    copy_success_and_bounds_step_12(d3,p17)

def copy_success_and_bounds_step_10(sourcem: Bytes.OwnedBytes, p15: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b12,d2) = p15
  do IO<Unit>:
    p16 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b12,d2,0,99))
    copy_success_and_bounds_step_11(sourcem,p16)

def copy_success_and_bounds_step_9(sourcem: Bytes.OwnedBytes, p14: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b11,d1) = p14
  do IO<Unit>:
    p15 : B.Budget & Bytes.OwnedBytes <- A.read(43,Bytes.get(b11,d1,1))
    copy_success_and_bounds_step_10(sourcem,p15)

def copy_success_and_bounds_step_8(p10: B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes) -> IO(Unit):
  (b9,source,dest) = p10
  do IO<Unit>:
    sourcem : Bytes.OwnedBytes <- A.metadata(3,4,1,1,Bytes.metadata(source))
    destm : Bytes.OwnedBytes <- A.metadata(2,2,1,2,Bytes.metadata(dest))
    b10 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,13},B.zero(),B.inspect(b9))
    p14 : B.Budget & Bytes.OwnedBytes <- A.read(42,Bytes.get(b10,destm,0))
    copy_success_and_bounds_step_9(sourcem,p14)

def copy_success_and_bounds_step_7(p8: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b7,x7) = p8
  do IO<Unit>:
    b8 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,7},B.zero(),B.inspect(b7))
    p10 : B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes <- A.copy_done(Bytes.copy_range(b8,x7,1,2))
    copy_success_and_bounds_step_8(p10)

def copy_success_and_bounds_step_6(p7: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b6,x6) = p7
  do IO<Unit>:
    p8 : B.Budget & Bytes.OwnedBytes <- A.copy_failed(E.Bounds{1,4294967295,3},Bytes.copy_range(b6,x6,1,4294967295))
    copy_success_and_bounds_step_7(p8)

def copy_success_and_bounds_step_5(p6: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b5,x5) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes <- A.copy_failed(E.Bounds{2,2,3},Bytes.copy_range(b5,x5,2,2))
    copy_success_and_bounds_step_6(p7)

def copy_success_and_bounds_step_4(p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & Bytes.OwnedBytes <- A.copy_failed(E.Bounds{4,0,3},Bytes.copy_range(b4,x4,4,0))
    copy_success_and_bounds_step_5(p6)

def copy_success_and_bounds_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,43))
    copy_success_and_bounds_step_4(p5)

def copy_success_and_bounds_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,42))
    copy_success_and_bounds_step_3(p4)

def copy_success_and_bounds_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,41))
    copy_success_and_bounds_step_2(p3)

def copy_success_and_bounds() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,204800,100}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    copy_success_and_bounds_step_1(p2)

def copy_partial_step_12(+edge: U32, s2: Bytes.OwnedBytes, p17: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bd2,d2) = p17
  do IO<Unit>:
    b9 : B.Budget <- A.dropped(Bytes.drop(bd2,d2))
    b10 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,U32.add(edge,6)},B.zero(),B.inspect(b9))
    end : B.Budget <- A.dropped(Bytes.drop(b10,s2))
    A.finished("buffer-copy-partial-work-edge",B.Six{0,0,0,0,0,U32.add(edge,6)},B.finish(end))

def copy_partial_step_11(+edge: U32, s2: Bytes.OwnedBytes, p16: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bd1,d1) = p16
  do IO<Unit>:
    p17 : B.Budget & Bytes.OwnedBytes <- A.read(0,Bytes.get(bd1,d1,2))
    copy_partial_step_12(edge,s2,p17)

def copy_partial_step_10(+edge: U32, +second: U32, s2: Bytes.OwnedBytes, p15: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bd0,d0) = p15
  do IO<Unit>:
    p16 : B.Budget & Bytes.OwnedBytes <- A.read(second,Bytes.get(bd0,d0,1))
    copy_partial_step_11(edge,s2,p16)

def copy_partial_step_9(+edge: U32, +first: U32, +second: U32, destm: Bytes.OwnedBytes, p14: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bs2,s2) = p14
  do IO<Unit>:
    p15 : B.Budget & Bytes.OwnedBytes <- A.read(first,Bytes.get(bs2,destm,0))
    copy_partial_step_10(edge,second,s2,p15)

def copy_partial_step_8(+edge: U32, +first: U32, +second: U32, destm: Bytes.OwnedBytes, p13: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bs1,s1) = p13
  do IO<Unit>:
    p14 : B.Budget & Bytes.OwnedBytes <- A.read(43,Bytes.get(bs1,s1,2))
    copy_partial_step_9(edge,first,second,destm,p14)

def copy_partial_step_7(+edge: U32, +first: U32, +second: U32, destm: Bytes.OwnedBytes, p12: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (bs0,s0) = p12
  do IO<Unit>:
    p13 : B.Budget & Bytes.OwnedBytes <- A.read(42,Bytes.get(bs0,s0,1))
    copy_partial_step_8(edge,first,second,destm,p13)

def copy_partial_step_6(+edge: U32, +first: U32, +second: U32, ticket: B.Reservation, p7: B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes) -> IO(Unit):
  (b6,source,dest) = p7
  do IO<Unit>:
    sourcem : Bytes.OwnedBytes <- A.metadata(3,4,1,1,Bytes.metadata(source))
    destm : Bytes.OwnedBytes <- A.metadata(3,4,1,3,Bytes.metadata(dest))
    b7 : B.Budget <- A.usage(B.Six{0,0,0,0,204800,edge},B.Six{0,0,0,0,4096,10},B.inspect(b6))
    b8 : B.Budget <- A.cancelled(B.cancel(b7,ticket))
    p12 : B.Budget & Bytes.OwnedBytes <- A.read(41,Bytes.get(b8,sourcem,0))
    copy_partial_step_7(edge,first,second,destm,p12)

def copy_partial_step_5(+edge: U32, +first: U32, +second: U32, x4: Bytes.OwnedBytes, p6: B.Budget & B.Reservation) -> IO(Unit):
  (b5,ticket) = p6
  do IO<Unit>:
    p7 : B.Budget & Bytes.OwnedBytes & Bytes.OwnedBytes <- A.copy_partial(E.ResourceLimit{5,U32.add(edge,10),U32.add(edge,10),1},Bytes.copy_range(b5,x4,0,3))
    copy_partial_step_6(edge,first,second,ticket,p7)

def copy_partial_step_4(+edge: U32, +first: U32, +second: U32, p5: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b4,x4) = p5
  do IO<Unit>:
    p6 : B.Budget & B.Reservation <- A.reserved(B.reserve_many(b4,B.work(10)))
    copy_partial_step_5(edge,first,second,x4,p6)

def copy_partial_step_3(+edge: U32, +first: U32, +second: U32, p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    p5 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b3,x3,2,43))
    copy_partial_step_4(edge,first,second,p5)

def copy_partial_step_2(+edge: U32, +first: U32, +second: U32, p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b2,x2,1,42))
    copy_partial_step_3(edge,first,second,p4)

def copy_partial_step_1(+edge: U32, +first: U32, +second: U32, p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,41))
    copy_partial_step_2(edge,first,second,p3)

def copy_partial(+edge: U32, first: U32, second: U32) -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,208896,U32.add(edge,10)}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,3))
    copy_partial_step_1(edge,first,second,p2)

def copy_allocation_rejected_step_4(p6: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b5,x5) = p6
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(b5,x5))
    A.finished("buffer-copy-allocation-rejected",B.Six{0,0,0,0,0,3},B.finish(end))

def copy_allocation_rejected_step_3(p4: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b3,x3) = p4
  do IO<Unit>:
    b4 : B.Budget <- A.usage(B.Six{0,0,0,0,135168,2},B.zero(),B.inspect(b3))
    p6 : B.Budget & Bytes.OwnedBytes <- A.read(73,Bytes.get(b4,x3,0))
    copy_allocation_rejected_step_4(p6)

def copy_allocation_rejected_step_2(p3: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b2,x2) = p3
  do IO<Unit>:
    p4 : B.Budget & Bytes.OwnedBytes <- A.copy_failed(E.ResourceLimit{4,135168,135168,69632},Bytes.copy_range(b2,x2,0,1))
    copy_allocation_rejected_step_3(p4)

def copy_allocation_rejected_step_1(p2: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (b1,x1) = p2
  do IO<Unit>:
    p3 : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(b1,x1,0,73))
    copy_allocation_rejected_step_2(p3)

def copy_allocation_rejected() -> IO(Unit):
  do IO<Unit>:
    b0 : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,135168,20}))
    p2 : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(b0,1))
    copy_allocation_rejected_step_1(p2)

# Allocation initialization costs rounded capacity; rejected accesses visit no bytes.
def capacity_done(+capacity: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(budget,bytes))
    A.finished("buffer-capacity-boundary",B.Six{0,0,0,0,0,U32.add(capacity,2)},B.finish(end))

def capacity_read(+length: U32, capacity: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.read(255,Bytes.get(budget,bytes,U32.sub(length,1)))
    capacity_done(capacity,next)

def capacity_put(+length: U32, capacity: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.put(budget,bytes,U32.sub(length,1),255))
    capacity_read(length,capacity,next)

def capacity_get_bound(+length: U32, capacity: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{length,1,length},Bytes.get(budget,bytes,length))
    capacity_put(length,capacity,next)

def capacity_created(+length: U32, +capacity: U32, p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    checked : Bytes.OwnedBytes <- A.metadata(length,capacity,1,1,Bytes.metadata(bytes))
    next : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{length,1,length},Bytes.put(budget,checked,length,7))
    capacity_get_bound(length,capacity,next)

def capacity_case(+length: U32, +capacity: U32) -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,2097152,U32.add(capacity,2)}))
    pair : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(budget,length))
    capacity_created(length,capacity,pair)

# Empty means length zero but minimum capacity one; append can use that cell.
def empty_done(p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    end : B.Budget <- A.dropped(Bytes.drop(budget,bytes))
    A.finished("buffer-empty-minimum-capacity",B.Six{0,0,0,0,0,3},B.finish(end))

def empty_read(p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.read(255,Bytes.get(budget,bytes,0))
    empty_done(next)

def empty_full(p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.change_failed(E.Bounds{1,1,1},Bytes.append(budget,bytes,9))
    empty_read(next)

def empty_append(p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    next : B.Budget & Bytes.OwnedBytes <- A.changed(Bytes.append(budget,bytes,255))
    empty_full(next)

def empty_created(p: B.Budget & Bytes.OwnedBytes) -> IO(Unit):
  (budget,bytes) = p
  do IO<Unit>:
    checked : Bytes.OwnedBytes <- A.metadata(0,1,1,1,Bytes.metadata(bytes))
    next : B.Budget & Bytes.OwnedBytes <- A.read_failed(E.Bounds{0,1,0},Bytes.get(budget,checked,0))
    empty_append(next)

def empty_case() -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,135168,3}))
    pair : B.Budget & Bytes.OwnedBytes <- A.created(Bytes.new(budget,0))
    empty_created(pair)

def allocation_work_preflight() -> IO(Unit):
  do IO<Unit>:
    budget : B.Budget <- A.start(B.start(1,B.Six{0,0,0,0,135168,3}))
    new_failed(E.ResourceLimit{5,3,0,4},Bytes.new(budget,3))

def main() -> IO(Unit):
  do IO<Unit>:
    capacity_case(1,1)
    capacity_case(65535,65536)
    capacity_case(65536,65536)
    empty_case()
    allocation_work_preflight()
    bounds_and_reuse()
    new_preflight()
    work_failures()
    copy_success_and_bounds()
    copy_partial(11,0,0)
    copy_partial(12,0,0)
    copy_partial(13,41,0)
    copy_partial(14,41,0)
    copy_partial(15,41,42)
    copy_partial(16,41,42)
    copy_allocation_rejected()
    IO.print("buffers-ok")
