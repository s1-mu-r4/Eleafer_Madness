/* Native audit stubs only: no MMIO, USB, flash, PWM or real clock. */
#ifndef B1_MYEVIC_STUB
#define B1_MYEVIC_STUB
#include <stdint.h>
#include <time.h>
#define __myevic__
struct Flags { int noclock, rtcinit; };
extern struct Flags gFlags;
extern unsigned UpdateDFTimer;
#endif
