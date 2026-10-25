#include "myevic.h"
/* Matches limiter field offsets only; ARM build checks the actual dfParams_t. */
typedef struct {
    uint8_t padding[0xe7], PLFlags;
    uint16_t PLMaxPuffs, PLWindowSecs, PLWindowCount, reserved;
    uint32_t PLWindowStart, PLSchedule;
} dfParams_t;
extern dfParams_t params;
#define dfPLFlags params.PLFlags
#define dfPLMaxPuffs params.PLMaxPuffs
#define dfPLWindowSecs params.PLWindowSecs
#define dfPLWindowCount params.PLWindowCount
#define dfPLWindowStart params.PLWindowStart
#define dfPLSchedule params.PLSchedule
