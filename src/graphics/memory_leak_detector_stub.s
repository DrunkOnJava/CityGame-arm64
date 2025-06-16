;------------------------------------------------------------------------------
; memory_leak_detector_stub.s - Stub implementation
;------------------------------------------------------------------------------

.section __TEXT,__text,regular,pure_instructions
.align 2

.globl _leak_detector_init
_leak_detector_init:
    ret

.globl _leak_detector_track_alloc
_leak_detector_track_alloc:
    ret

.globl _leak_detector_track_free
_leak_detector_track_free:
    ret

.globl _leak_detector_check_leaks
_leak_detector_check_leaks:
    mov     x0, #0
    ret

.globl _leak_detector_report
_leak_detector_report:
    ; Clear report buffer
    mov     x1, #88
1:
    str     xzr, [x0], #8
    subs    x1, x1, #8
    b.ne    1b
    ret

.globl _leak_detector_track_camera_alloc
_leak_detector_track_camera_alloc:
    ret