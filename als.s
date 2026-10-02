# Rolling anti-lag for Hayabusa Gen3 5JCZSJ40 SD-v3  (RH850 / v850e3v5)
        .set ALS_RAM,   0xfebfe000      # flags(u8) +0, cap(u16) +2, timer(u16) +4
        .set CAL,       0x000bf000
        .set C_EN,      0               # u8  0x80 = enabled
        .set C_ECT,     1               # u8  min coolant raw
        .set C_SPD,     2               # u16 min front wheel speed (X/128 km/h)
        .set C_WOTON,   4               # u16 grip angle to capture (X/364.08 deg)
        .set C_WOTOFF,  6               # u16 grip angle below which ALS releases
        .set C_RPMMIN,  8               # u16 min capture rpm (X/2.56)
        .set C_RPMMAX,  10              # u16 max capture rpm
        .set C_HYST,    12              # u16 hysteresis (rpm counts)
        .set C_TMAX,    14              # u16 max active time (5 ms ticks)

        .section .als_code,"ax"
        .globl ALS_TICK, ALS_LIMIT, ALS_IS_ACTIVE
# ---------------------------------------------------------------- 5 ms task
ALS_TICK:
        mov     ALS_RAM, r10
        mov     CAL, r11
        ld.bu   C_EN[r11], r12
        movea   0x80, r0, r13
        cmp     r13, r12
        bne     .Ldisarm
        # ---- TRIGGER: starter switch (fef024de bit0). Swap this block for MODE later.
        mov     0xfef024de, r13
        tst1    0, 0[r13]
        bz      .Ldisarm
        # ---- rolling: front wheel speed >= min
        mov     0xfef0263a, r13
        ld.hu   0[r13], r13
        ld.hu   C_SPD[r11], r14
        cmp     r14, r13
        bl      .Ldisarm
        # ---- coolant >= min
        mov     0xfef026bd, r13
        ld.bu   0[r13], r13
        ld.bu   C_ECT[r11], r14
        cmp     r14, r13
        bl      .Ldisarm
        # ---- armed: block stock launch-control long-press (START held while rolling)
        mov     0xfef0071e, r13
        st.h    r0, 0[r13]
        # ---- timed out? stay inactive until button released
        tst1    1, 0[r10]
        bz      2f
        clr1    0, 0[r10]
        br      .Ldone
2:      mov     0xfef025ec, r13
        ld.hu   0[r13], r13             # grip angle
        tst1    0, 0[r10]
        bnz     .Lactive
        # ---- not active: capture on WOT
        ld.hu   C_WOTON[r11], r14
        cmp     r14, r13
        bl      .Ldone
        mov     0xfef0258c, r15
        ld.hu   0[r15], r15             # rpm
        ld.hu   C_RPMMIN[r11], r14
        cmp     r14, r15
        bl      .Ldone                  # below min rpm: do not activate
        ld.hu   C_RPMMAX[r11], r14
        cmp     r14, r15
        bl      3f
        mov     r14, r15
3:      st.h    r15, 2[r10]
        st.h    r0, 4[r10]
        set1    0, 0[r10]
        br      .Ldone
.Lactive:
        ld.hu   C_WOTOFF[r11], r14
        cmp     r14, r13
        bl      .Lrelease
        ld.hu   4[r10], r15
        add     1, r15
        st.h    r15, 4[r10]
        ld.hu   C_TMAX[r11], r14
        cmp     r14, r15
        bl      .Ldone
        movea   2, r0, r15              # timeout: latch, inactive
        st.b    r15, 0[r10]
        br      .Ldone
.Lrelease:
        clr1    0, 0[r10]
        br      .Ldone
.Ldisarm:
        st.b    r0, 0[r10]
        st.h    r0, 4[r10]
.Ldone:
        jr      FUN_5BDB4                 # tail-call the original FUN_5BDB4

# ---------------------------------------------------------------- ignition-cut limiter (replaces FUN_2C700)
ALS_LIMIT:
        prepare {lp}, 0
        zxh     r6
        mov     ALS_RAM, r10
        tst1    0, 0[r10]
        bz      4f
        ld.hu   2[r10], r19             # ON  = captured rpm
        mov     CAL, r11
        ld.hu   C_HYST[r11], r12
        mov     r19, r18
        sub     r12, r18                # OFF = cap - hyst
        bnl     5f
        mov     r0, r18
        br      5f
4:      movhi   0x15, r0, r18
        ld.hu   0x42d0[r18], r18        # stock OFF 0x1542D0
        movhi   0x15, r0, r19
        ld.hu   0x42d2[r19], r19        # stock ON  0x1542D2
5:      mov     0xfef00a1e, r1
        cmp     r18, r6
        bl      6f
        cmp     r19, r6
        bl      7f
        set1    1, 0[r1]
        br      7f
6:      clr1    1, 0[r1]
7:      tst1    1, 0[r1]
        setf    nz, r6
        jarl    FUN_2C396, lp
        dispose 0, {lp}, [lp]

# ---------------------------------------------------------------- used by FUN_525EE table select
ALS_IS_ACTIVE:
        mov     ALS_RAM, r10
        ld.bu   0[r10], r10
        andi    1, r10, r10
        jmp     [lp]
