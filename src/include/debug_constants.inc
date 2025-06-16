;------------------------------------------------------------------------------
; debug_constants.inc - Debug constants and error codes
;------------------------------------------------------------------------------

;── Build Configuration ───────────────────────────────────────────────────────
.ifdef DEBUG
    .equ DEBUG_BUILD, 1
    .equ PERF_MONITORING, 1
    .equ STACK_GUARDS, 1
    .equ BOUNDS_CHECKING, 1
.else
    .equ DEBUG_BUILD, 0
    .equ PERF_MONITORING, 0
    .equ STACK_GUARDS, 0
    .equ BOUNDS_CHECKING, 0
.endif

;── Error Code Categories ─────────────────────────────────────────────────────
.equ ERR_CATEGORY_MASK,         0xFF00
.equ ERR_SUBCATEGORY_MASK,      0x00FF

; Category definitions
.equ ERR_CAT_INPUT,             0x0100
.equ ERR_CAT_PHYSICS,           0x0200
.equ ERR_CAT_GRAPHICS,          0x0300
.equ ERR_CAT_MEMORY,            0x0400
.equ ERR_CAT_STATE,             0x0500
.equ ERR_CAT_MATH,              0x0600
.equ ERR_CAT_PERF,              0x0700

;── Specific Error Codes ──────────────────────────────────────────────────────
; Input errors
.equ ERR_INPUT_NULL_PTR,        (ERR_CAT_INPUT | 0x01)
.equ ERR_INPUT_CORRUPT,         (ERR_CAT_INPUT | 0x02)
.equ ERR_INPUT_OUT_OF_RANGE,    (ERR_CAT_INPUT | 0x03)
.equ ERR_INPUT_INVALID_KEY,     (ERR_CAT_INPUT | 0x04)
.equ ERR_INPUT_MOUSE_BOUNDS,    (ERR_CAT_INPUT | 0x05)

; Physics errors
.equ ERR_POSITION_X_BOUNDS,     (ERR_CAT_PHYSICS | 0x01)
.equ ERR_POSITION_Y_BOUNDS,     (ERR_CAT_PHYSICS | 0x02)
.equ ERR_POSITION_Z_BOUNDS,     (ERR_CAT_PHYSICS | 0x03)
.equ ERR_VELOCITY_LIMIT,        (ERR_CAT_PHYSICS | 0x04)
.equ ERR_ACCELERATION_LIMIT,    (ERR_CAT_PHYSICS | 0x05)
.equ ERR_PHYSICS_DIVERGENCE,    (ERR_CAT_PHYSICS | 0x06)

; Graphics errors
.equ ERR_ZOOM_BOUNDS,           (ERR_CAT_GRAPHICS | 0x01)
.equ ERR_CAMERA_STATE_ALIGN,    (ERR_CAT_GRAPHICS | 0x02)
.equ ERR_MATRIX_INVALID,        (ERR_CAT_GRAPHICS | 0x03)
.equ ERR_QUATERNION_NOT_UNIT,   (ERR_CAT_GRAPHICS | 0x04)

; Memory errors
.equ ERR_NULL_POINTER,          (ERR_CAT_MEMORY | 0x01)
.equ ERR_ALIGNMENT_VIOLATION,   (ERR_CAT_MEMORY | 0x02)
.equ ERR_BUFFER_OVERFLOW,       (ERR_CAT_MEMORY | 0x03)
.equ ERR_STACK_CORRUPTION,      (ERR_CAT_MEMORY | 0x04)

; State errors
.equ ERR_STATE_CORRUPTED,       (ERR_CAT_STATE | 0x01)
.equ ERR_STATE_NOT_INIT,        (ERR_CAT_STATE | 0x02)
.equ ERR_STATE_TRANSITION,      (ERR_CAT_STATE | 0x03)

; Math errors
.equ ERR_NAN_DETECTED,          (ERR_CAT_MATH | 0x01)
.equ ERR_INF_DETECTED,          (ERR_CAT_MATH | 0x02)
.equ ERR_DENORMAL_DETECTED,     (ERR_CAT_MATH | 0x03)
.equ ERR_PRECISION_LOSS,        (ERR_CAT_MATH | 0x04)

; Performance errors
.equ ERR_FRAME_TIME_EXCEEDED,   (ERR_CAT_PERF | 0x01)
.equ ERR_POLL_RATE_LOW,         (ERR_CAT_PERF | 0x02)
.equ ERR_CACHE_MISS_HIGH,       (ERR_CAT_PERF | 0x03)

;── Debug State Offsets ───────────────────────────────────────────────────────
.equ DEBUG_ERROR_CODE,          0x00
.equ DEBUG_ERROR_PC,            0x08
.equ DEBUG_ERROR_DATA1,         0x10
.equ DEBUG_ERROR_DATA2,         0x18
.equ DEBUG_ERROR_MSG,           0x20
.equ DEBUG_LAST_CHECKPOINT,     0x60

;── Performance Timer IDs ─────────────────────────────────────────────────────
.equ TIMER_INPUT_PROCESS,       0
.equ TIMER_PHYSICS_UPDATE,      1
.equ TIMER_COLLISION_CHECK,     2
.equ TIMER_MATRIX_CALC,         3
.equ TIMER_EDGE_PAN,            4
.equ TIMER_ZOOM_CALC,           5
.equ TIMER_BLUR_CALC,           6
.equ TIMER_TOTAL_FRAME,         7

;── Validation Thresholds ─────────────────────────────────────────────────────
.equ MAX_POSITION_COORD,        10000.0
.equ MAX_VELOCITY,              200.0
.equ MAX_ACCELERATION,          100.0
.equ MIN_ZOOM_HEIGHT,           5.0
.equ MAX_ZOOM_HEIGHT,           1000.0
.equ QUATERNION_EPSILON,        0.01
.equ FRAME_TIME_BUDGET_MS,      4.0     ; 240Hz = 4.16ms
.equ MIN_POLL_RATE_HZ,          200

;── Debug Output Levels ───────────────────────────────────────────────────────
.equ DEBUG_LEVEL_NONE,          0
.equ DEBUG_LEVEL_ERROR,         1
.equ DEBUG_LEVEL_WARN,          2
.equ DEBUG_LEVEL_INFO,          3
.equ DEBUG_LEVEL_VERBOSE,       4
.equ DEBUG_LEVEL_TRACE,         5