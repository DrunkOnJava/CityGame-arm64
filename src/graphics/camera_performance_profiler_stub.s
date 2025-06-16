;------------------------------------------------------------------------------
; camera_performance_profiler_stub.s - Stub implementation
;------------------------------------------------------------------------------

.section __TEXT,__text,regular,pure_instructions
.align 2

.globl _camera_profiler_init
_camera_profiler_init:
    ret

.globl _camera_profiler_start
_camera_profiler_start:
    ret

.globl _camera_profiler_stop
_camera_profiler_stop:
    ret

.globl _camera_profiler_mark_frame
_camera_profiler_mark_frame:
    ret

.globl _camera_profiler_report
_camera_profiler_report:
    ret

.globl _camera_profiler_get_function_time
_camera_profiler_get_function_time:
    mov     x0, #0
    mov     x1, #0
    ret