        .set RAM, 0xfebfe000
        .set OUT, 0xfef0b800
        .macro STEP btn, spd, ect, grip, rpm
        mov     0xfef024de, r20
        movea   \btn, r0, r21
        st.b    r21, 0[r20]
        mov     0xfef0263a, r20
        mov     \spd, r21
        st.h    r21, 0[r20]
        mov     0xfef026bd, r20
        movea   \ect, r0, r21
        st.b    r21, 0[r20]
        mov     0xfef025ec, r20
        mov     \grip, r21
        st.h    r21, 0[r20]
        mov     0xfef0258c, r20
        mov     \rpm, r21
        st.h    r21, 0[r20]
        mov     0xfef0071e, r20          # LC long-press counter preset 5
        movea   5, r0, r21
        st.h    r21, 0[r20]
        jarl    ALS_TICK_T, lp
        mov     0xfef0258c, r20
        ld.hu   0[r20], r6
        jarl    hook_2c700, lp
        jarl    ALS_ACT_T, lp
        mov     r10, r22
        jarl    record, lp
        .endm

        .section .harness,"ax"
        .globl _start
_start:
        mov     0xfebfd000, sp
        mov     OUT, r29                 # output pointer
        STEP 0, 3840, 117, 3641, 12800        # 1 btn off  (30kph,80C,10deg,5000rpm)
        STEP 1, 3840, 117, 3641, 12800        # 2 armed idle grip
        STEP 1, 3840, 117, 34588, 15360       # 3 WOT @6000 -> capture
        STEP 1, 3840, 117, 34588, 15872       # 4 6200 -> cut on
        STEP 1, 3840, 117, 34588, 15104       # 5 5900 -> hold (hyst)
        STEP 1, 3840, 117, 34588, 14848       # 6 5800 -> cut off
        STEP 1, 3840, 117, 18204, 14848       # 7 grip 50deg -> release
        STEP 1, 3840, 117, 34588, 17920       # 8 WOT @7000 -> recapture
        STEP 1, 1280, 117, 34588, 17920       # 9 10 kph -> disarm
        STEP 1, 3840, 117, 34588, 6400        # 10 WOT @2500 -> below min, no capture
        STEP 1, 3840, 117, 34588, 29440       # 11 WOT @11500 -> cap clamp 10500
        STEP 1, 3840, 60, 34588, 29440        # 12 ECT 26C -> disarm
        STEP 0, 3840, 117, 34588, 30720       # 13 btn off @12000 -> stock limiter cut
        STEP 0, 3840, 117, 34588, 30464       # 14 11900 -> stock hold
        STEP 0, 3840, 117, 34588, 30000       # 15 <11900 -> stock off
        # timeout test: arm+capture then 2005 ticks
        STEP 1, 3840, 117, 34588, 15360       # 16 capture
        movea   2003, r0, r23
9:      jarl    ALS_TICK_T, lp
        add     -1, r23
        bnz     9b
        STEP 1, 3840, 117, 34588, 15872       # 17 after timeout: flags=2, stock limiter
        STEP 0, 3840, 117, 34588, 15872       # 18 release -> flags 0
        # write OUT buffer
        mov     OUT, r8
        mov     r29, r9
        sub     r8, r9
        movea   4, r0, r6
        movea   1, r0, r7
        trap    31
        movea   1, r0, r6
        mov     r0, r7
        trap    31
record: # flags, a1e, cap(2), timer(2), lc(2), active
        mov     RAM, r20
        ld.bu   0[r20], r21
        st.b    r21, 0[r29]
        mov     0xfef00a1e, r20
        ld.bu   0[r20], r21
        st.b    r21, 1[r29]
        mov     RAM, r20
        ld.hu   2[r20], r21
        st.h    r21, 2[r29]
        ld.hu   4[r20], r21
        st.h    r21, 4[r29]
        mov     0xfef0071e, r20
        ld.hu   0[r20], r21
        st.h    r21, 6[r29]
        st.b    r22, 8[r29]
        mov     0xfef00a19, r20
        ld.bu   0[r20], r21
        st.b    r21, 9[r29]
        addi    10, r29, r29
        jmp     [lp]

        .section .blob_code,"ax"
        .incbin "blob_code.bin"
        .section .blob_2c396,"ax"
        .incbin "blob_2c396.bin"
        .section .blob_2c700,"ax"
hook_2c700:
        .incbin "blob_2c700.bin"
        .section .stub_5bdb4,"ax"
        jmp     [lp]
        .section .blob_lim,"a"
        .incbin "blob_lim.bin"
