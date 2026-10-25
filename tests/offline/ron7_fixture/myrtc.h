#include "myevic.h"
typedef struct { uint32_t u32Year, u32Hour, u32Minute, u32Second; } S_RTC_TIME_DATA_T;
uint32_t RTCReadRegister(unsigned reg);
void RTCWriteRegister(unsigned reg, uint32_t value);
void GetRTC(S_RTC_TIME_DATA_T *rtd);
void RTCTimeToEpoch(time_t *now, S_RTC_TIME_DATA_T *rtd);
