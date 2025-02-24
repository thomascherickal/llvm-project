; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -S --passes='simplifycfg<hoist-common-insts>' %s | FileCheck %s

;; Check that the two loads are hoisted to the common predecessor, skipping
;; over the add/sub instructions.

define void @f0(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m,  ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f0(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[TMP1:%.*]] = load i16, ptr [[M:%.*]], align 2
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    [[ADD:%.*]] = add nsw i16 [[TMP0]], 1
; CHECK-NEXT:    [[U:%.*]] = add i16 [[ADD]], [[TMP1]]
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    [[SUB:%.*]] = sub nsw i16 [[TMP0]], 1
; CHECK-NEXT:    [[TMP2:%.*]] = add i16 [[SUB]], 3
; CHECK-NEXT:    [[V:%.*]] = add i16 [[SUB]], [[TMP2]]
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[UV:%.*]] = phi i16 [ [[V]], [[IF_ELSE]] ], [ [[U]], [[IF_THEN]] ]
; CHECK-NEXT:    store i16 [[UV]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  %add = add nsw i16 %0, 1
  %1 = load i16, ptr %m, align 2
  %u = add i16 %add, %1
  br label %if.end

if.else:
  %2 = load i16, ptr %b, align 2
  %sub = sub nsw i16 %2, 1
  %3 = load i16, ptr %m, align 2
  %4 = add i16 %sub, 3
  %v = add i16 %sub, %4
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}


;; Check some instructions (e.g. add) can be reordered across instructions with side
;; effects, while others (e.g. load) can't.
define void @f2(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m, ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[ADD_0:%.*]] = add nsw i16 [[TMP0]], 1
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    call void @side_effects0()
; CHECK-NEXT:    [[TMP1:%.*]] = load i16, ptr [[M:%.*]], align 2
; CHECK-NEXT:    [[U:%.*]] = add i16 [[ADD_0]], [[TMP1]]
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    call void @no_side_effects0()
; CHECK-NEXT:    [[TMP2:%.*]] = load i16, ptr [[M]], align 2
; CHECK-NEXT:    [[V:%.*]] = add i16 [[ADD_0]], [[TMP2]]
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[UV:%.*]] = phi i16 [ [[V]], [[IF_ELSE]] ], [ [[U]], [[IF_THEN]] ]
; CHECK-NEXT:    store i16 [[UV]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  call void @side_effects0()
  %add.0 = add nsw i16 %0, 1
  %1 = load i16, ptr %m, align 2
  %u = add i16 %add.0, %1
  br label %if.end

if.else:
  %2 = load i16, ptr %b, align 2
  call void @no_side_effects0()
  %add.1 = add nsw i16 %2, 1
  %3 = load i16, ptr %m, align 2
  %v = add i16 %add.1, %3
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}


;; Check indeed it was the side effects that prevented hoisting the load
;; in the previous test.
define void @f3(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m, ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[ADD_0:%.*]] = add nsw i16 [[TMP0]], 1
; CHECK-NEXT:    [[TMP1:%.*]] = load i16, ptr [[M:%.*]], align 2
; CHECK-NEXT:    [[U:%.*]] = add i16 [[ADD_0]], [[TMP1]]
; CHECK-NEXT:    store i16 [[U]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  call void @no_side_effects0()
  %add.0 = add nsw i16 %0, 1
  %1 = load i16, ptr %m, align 2
  %u = add i16 %add.0, %1
  br label %if.end

if.else:
  %2 = load i16, ptr %b, align 2
  call void @no_side_effects1()
  %add.1 = add nsw i16 %2, 1
  %3 = load i16, ptr %m, align 2
  %v = add i16 %add.1, %3
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}

;; Check some instructions (e.g. sdiv) are not speculatively executed.

;; Division by non-zero constant OK to speculate ...
define void @f4(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m, ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f4(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[DIV_0:%.*]] = sdiv i16 [[TMP0]], 2
; CHECK-NEXT:    [[U:%.*]] = add i16 [[DIV_0]], [[TMP0]]
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    call void @side_effects0()
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    call void @side_effects1()
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    store i16 [[U]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  call void @side_effects0()
  %div.0 = sdiv i16 %0, 2
  %u = add i16 %div.0, %0
  br label %if.end

if.else:
  %1 = load i16, ptr %b, align 2
  call void @side_effects1()
  %div.1 = sdiv i16 %1, 2
  %v = add i16 %div.1, %1
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}

;; ... but not a general division ...
define void @f5(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m, ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f5(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    call void @side_effects0()
; CHECK-NEXT:    [[DIV_0:%.*]] = sdiv i16 211, [[TMP0]]
; CHECK-NEXT:    [[U:%.*]] = add i16 [[DIV_0]], [[TMP0]]
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    call void @side_effects1()
; CHECK-NEXT:    [[DIV_1:%.*]] = sdiv i16 211, [[TMP0]]
; CHECK-NEXT:    [[V:%.*]] = add i16 [[DIV_1]], [[TMP0]]
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[UV:%.*]] = phi i16 [ [[V]], [[IF_ELSE]] ], [ [[U]], [[IF_THEN]] ]
; CHECK-NEXT:    store i16 [[UV]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  call void @side_effects0()
  %div.0 = sdiv i16 211, %0
  %u = add i16 %div.0, %0
  br label %if.end

if.else:
  %1 = load i16, ptr %b, align 2
  call void @side_effects1()
  %div.1 = sdiv i16 211, %1
  %v = add i16 %div.1, %1
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}

;; ... and it's also OK to hoist the division when there's no speculation happening.
define void @f6(i1 %c, ptr nocapture noundef %d, ptr nocapture noundef readonly %m, ptr nocapture noundef readonly %b) {
; CHECK-LABEL: @f6(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[DIV_0:%.*]] = sdiv i16 211, [[TMP0]]
; CHECK-NEXT:    [[U:%.*]] = add i16 [[DIV_0]], [[TMP0]]
; CHECK-NEXT:    store i16 [[U]], ptr [[D:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %0 = load i16, ptr %b, align 2
  call void @no_side_effects0()
  %div.0 = sdiv i16 211, %0
  %u = add i16 %div.0, %0
  br label %if.end

if.else:
  %1 = load i16, ptr %b, align 2
  call void @no_side_effects1()
  %div.1 = sdiv i16 211, %1
  %v = add i16 %div.1, %1
  br label %if.end

if.end:
  %uv = phi i16 [ %v, %if.else ], [ %u, %if.then ]
  store i16 %uv, ptr %d, align 2
  ret void
}

;; No reorder of store over a load.
define i16 @f7(i1 %c, ptr %a, ptr %b) {
; CHECK-LABEL: @f7(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    [[VA:%.*]] = load i16, ptr [[A:%.*]], align 2
; CHECK-NEXT:    store i16 0, ptr [[B:%.*]], align 2
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    [[VB:%.*]] = load i16, ptr [[B]], align 2
; CHECK-NEXT:    store i16 0, ptr [[B]], align 2
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[V:%.*]] = phi i16 [ [[VA]], [[IF_THEN]] ], [ [[VB]], [[IF_ELSE]] ]
; CHECK-NEXT:    ret i16 [[V]]
;
entry:
  br i1 %c, label %if.then, label %if.else

if.then:
  %va = load i16, ptr %a, align 2
  store i16 0, ptr %b, align 2
  br label %if.end

if.else:
  %vb = load i16, ptr %b, align 2
  store i16 0, ptr %b, align 2
  br label %if.end

if.end:
  %v = phi i16 [ %va, %if.then ], [ %vb, %if.else ]
  ret i16 %v
}

;; Can reorder load over another load
define i16 @f8(i1 %cond, ptr %a, ptr %b, ptr %c) {
; CHECK-LABEL: @f8(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[C_0:%.*]] = load i16, ptr [[C:%.*]], align 2
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    [[VA:%.*]] = load i16, ptr [[A:%.*]], align 2
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    [[VB:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[V:%.*]] = phi i16 [ [[VA]], [[IF_THEN]] ], [ [[VB]], [[IF_ELSE]] ]
; CHECK-NEXT:    [[U:%.*]] = phi i16 [ [[C_0]], [[IF_THEN]] ], [ [[C_0]], [[IF_ELSE]] ]
; CHECK-NEXT:    [[W:%.*]] = add i16 [[V]], [[U]]
; CHECK-NEXT:    ret i16 [[W]]
;
entry:
  br i1 %cond, label %if.then, label %if.else

if.then:
  %va = load i16, ptr %a, align 2
  %c.0 = load i16, ptr %c
  br label %if.end

if.else:
  %vb = load i16, ptr %b, align 2
  %c.1 = load i16, ptr %c
  br label %if.end

if.end:
  %v = phi i16 [ %va, %if.then ], [ %vb, %if.else ]
  %u = phi i16 [ %c.0, %if.then ], [ %c.1, %if.else ]

  %w = add i16 %v, %u

  ret i16 %w
}

;; Currently won't reorder volatile and non-volatile loads.
define i16 @f9(i1 %cond, ptr %a, ptr %b, ptr %c) {
; CHECK-LABEL: @f9(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF_THEN:%.*]], label [[IF_ELSE:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    [[VA:%.*]] = load volatile i16, ptr [[A:%.*]], align 2
; CHECK-NEXT:    [[C_0:%.*]] = load i16, ptr [[C:%.*]], align 2
; CHECK-NEXT:    br label [[IF_END:%.*]]
; CHECK:       if.else:
; CHECK-NEXT:    [[VB:%.*]] = load i16, ptr [[B:%.*]], align 2
; CHECK-NEXT:    [[C_1:%.*]] = load i16, ptr [[C]], align 2
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    [[V:%.*]] = phi i16 [ [[VA]], [[IF_THEN]] ], [ [[VB]], [[IF_ELSE]] ]
; CHECK-NEXT:    [[U:%.*]] = phi i16 [ [[C_0]], [[IF_THEN]] ], [ [[C_1]], [[IF_ELSE]] ]
; CHECK-NEXT:    [[W:%.*]] = add i16 [[V]], [[U]]
; CHECK-NEXT:    ret i16 [[W]]
;
entry:
  br i1 %cond, label %if.then, label %if.else

if.then:
  %va = load volatile i16, ptr %a, align 2
  %c.0 = load i16, ptr %c
  br label %if.end

if.else:
  %vb = load i16, ptr %b, align 2
  %c.1 = load i16, ptr %c
  br label %if.end

if.end:
  %v = phi i16 [ %va, %if.then ], [ %vb, %if.else ]
  %u = phi i16 [ %c.0, %if.then ], [ %c.1, %if.else ]

  %w = add i16 %v, %u

  ret i16 %w
}

;; Don't hoist stacksaves across inalloca allocas
define void @f10(i1 %cond) {
; CHECK-LABEL: @f10(
; CHECK-NEXT:    [[SS:%.*]] = call ptr @llvm.stacksave()
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    [[I1:%.*]] = alloca inalloca i32, align 4
; CHECK-NEXT:    [[SS2:%.*]] = call ptr @llvm.stacksave()
; CHECK-NEXT:    [[I2:%.*]] = alloca inalloca i64, align 8
; CHECK-NEXT:    call void @inalloca_i64(ptr inalloca(i64) [[I2]])
; CHECK-NEXT:    call void @llvm.stackrestore(ptr [[SS2]])
; CHECK-NEXT:    call void @inalloca_i32(ptr inalloca(i32) [[I1]])
; CHECK-NEXT:    br label [[END:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    [[I3:%.*]] = alloca inalloca i64, align 8
; CHECK-NEXT:    [[SS3:%.*]] = call ptr @llvm.stacksave()
; CHECK-NEXT:    [[I4:%.*]] = alloca inalloca i64, align 8
; CHECK-NEXT:    [[TMP1:%.*]] = call ptr @inalloca_i64(ptr inalloca(i64) [[I4]])
; CHECK-NEXT:    call void @llvm.stackrestore(ptr [[SS3]])
; CHECK-NEXT:    [[TMP2:%.*]] = call ptr @inalloca_i64(ptr inalloca(i64) [[I3]])
; CHECK-NEXT:    br label [[END]]
; CHECK:       end:
; CHECK-NEXT:    call void @llvm.stackrestore(ptr [[SS]])
; CHECK-NEXT:    ret void
;
  %ss = call ptr @llvm.stacksave()
  br i1 %cond, label %bb1, label %bb2

bb1:
  %i1 = alloca inalloca i32
  %ss2 = call ptr @llvm.stacksave()
  %i2 = alloca inalloca i64
  call void @inalloca_i64(ptr inalloca(i64) %i2)
  call void @llvm.stackrestore(ptr %ss2)
  call void @inalloca_i32(ptr inalloca(i32) %i1)
  br label %end

bb2:
  %i3 = alloca inalloca i64
  %ss3 = call ptr @llvm.stacksave()
  %i4 = alloca inalloca i64
  call ptr @inalloca_i64(ptr inalloca(i64) %i4)
  call void @llvm.stackrestore(ptr %ss3)
  call ptr @inalloca_i64(ptr inalloca(i64) %i3)
  br label %end

end:
  call void @llvm.stackrestore(ptr %ss)
  ret void
}

declare void @side_effects0()
declare void @side_effects1()
declare void @no_side_effects0() readonly nounwind willreturn
declare void @no_side_effects1() readonly nounwind willreturn
declare void @inalloca_i64(ptr inalloca(i64))
declare void @inalloca_i32(ptr inalloca(i32))
declare ptr @llvm.stacksave()
declare void @llvm.stackrestore(ptr)
