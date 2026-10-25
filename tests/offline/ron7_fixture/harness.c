/* Runs native policy/counting code only. Assertion success can prove a gap. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "myevic.h"
#include "myrtc.h"
#include "dataflash.h"
#include "pufflimit.h"
struct Flags gFlags = {0, 1};
dfParams_t params;
unsigned UpdateDFTimer;
static uint32_t seal;
static time_t wall = 1000;
uint32_t RTCReadRegister(unsigned reg) { (void)reg; return seal; }
void RTCWriteRegister(unsigned reg, uint32_t v) { (void)reg; seal = v; }
void GetRTC(S_RTC_TIME_DATA_T *rtd) { *rtd = (S_RTC_TIME_DATA_T){2026, 12, 0, 0}; }
void RTCTimeToEpoch(time_t *now, S_RTC_TIME_DATA_T *rtd) { (void)rtd; *now = wall; }
static unsigned FireDuration, dfTimeCount, dfPuffCount, UpdatePTTimer;
static void stop_accounting(unsigned ticks) {
    FireDuration = ticks;
    /* Generated verbatim from the fixed atomizer.c >5 counting block. */
    #include "stop_accounting.inc"
}
static int fmc_reject(unsigned u32ParamLen) {
    #define EP2_MAX_PKT_SIZE 64
    /* Only the validation branch, no FMC_Read or hardware calls. */
    #include "fmc_guard.inc"
    return 0;
}
static struct { uint32_t params[64]; } DataFlash;
static unsigned dfMagic = 7, DFMagicNumber = 7, dfCRC = 1, crc_result = 1;
static unsigned reset_calls, validity_calls;
static unsigned CalcPageCRC(uint32_t *words) { (void)words; return crc_result; }
static void DFCheckValuesValidity(void) { ++validity_calls; }
static void ResetDataFlash(void) { ++reset_calls; PLResetDefaults(); }
static void restore_crc_branch(void) {
    #define myprintf(...) ((void)0)
    /* Actual InitDataFlash final branch; inject CRC result, not a Flash model. */
    #include "crc_fallback.inc"
}
int main(int argc, char **argv) {
    assert(argc == 2);
    PLResetDefaults();
    PLSealClock();
    dfPLWindowStart = 1000;
    dfPLMaxPuffs = 2;
    int scenario = atoi(argv[1]);
    switch (scenario) {
    case 1: /* DOPEY counterexample: FAIL_CLOSED + untrusted + spare budget allows. */
        seal = 0;
        assert(PLCheckFire() == 1);
        break;
    case 2:
        seal = 0; dfPLWindowCount = 2;
        assert(PLCheckFire() == 0);
        break;
    case 3: /* Counterexample: runtime disable overrides the quota. */
        dfPLWindowCount = 2; dfPLFlags &= ~PL_FLAG_ENABLED;
        assert(PLCheckFire() == 1);
        break;
    case 4: /* Ron7 preserves count but reanchors, does not latch distrust. */
        wall = 900; dfPLWindowCount = 1;
        assert(PLCheckFire() == 1 && dfPLWindowCount == 1);
        assert(dfPLWindowStart == 900);
        break;
    case 5: /* Five 0.5s accounting calls count no puff or FIRE duration. */
        for (int i=0; i<5; ++i) stop_accounting(5);
        assert(dfPLWindowCount == 0 && dfTimeCount == 0);
        break;
    case 6:
        stop_accounting(6);
        assert(dfPLWindowCount == 1 && dfTimeCount == 6);
        assert(UpdateDFTimer == 50);
        break;
    case 7: { /* Power-cut abstraction: actual deferred RAM update, no Flash emulation. */
        dfParams_t durable = params;
        PLCountPuff(); PLCountPuff();
        assert(PLCheckFire() == 0 && UpdateDFTimer == 50);
        params = durable;
        assert(PLCheckFire() == 1);
        break;
    }
    case 8: /* Caller of ResetDefaults after invalid config restores allowance. */
        dfPLWindowCount = 2;
        PLResetDefaults();
        assert(dfPLWindowCount == 0 && PLCheckFire() == 1);
        break;
    case 9:
        dfPLWindowCount = 65535;
        PLValidate();
        assert(dfPLWindowCount == dfPLMaxPuffs && PLCheckFire() == 0);
        break;
    case 10: /* Time-window quota is reset at its fixed anchor, not trailing history. */
        dfPLWindowCount = 2;
        wall += dfPLWindowSecs;
        assert(PLCheckFire() == 1 && dfPLWindowCount == 0);
        break;
    case 11: /* ! binds before %, so a nonzero unaligned length is accepted. */
        assert(fmc_reject(1) == 0 && fmc_reject(63) == 0);
        break;
    case 12:
        assert(fmc_reject(0) == -1 && fmc_reject(64) == 0);
        break;
    case 13: /* A CRC mismatch takes ResetDataFlash, not a permanent inhibit. */
        dfPLWindowCount = 2; crc_result = 2;
        restore_crc_branch();
        assert(reset_calls == 1 && validity_calls == 0);
        assert(dfPLWindowCount == 0 && PLCheckFire() == 1);
        break;
    case 14:
        dfPLWindowCount = 2;
        restore_crc_branch();
        assert(reset_calls == 0 && validity_calls == 1);
        assert(dfPLWindowCount == 2 && PLCheckFire() == 0);
        break;
    default: return 2;
    }
    puts("OFFLINE_INSPECTED: native source counterexample/characterization; hardware NOT_RUN");
    return 0;
}
