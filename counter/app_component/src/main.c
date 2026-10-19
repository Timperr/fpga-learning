#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "stdint.h"

#define COUNTER_BASEADDR XPAR_COUNTER_IP_0_BASEADDR

#define REG_WINDOW  0x00U
#define REG_CTRL    0x04U
#define REG_COUNT   0x08U
#define REG_STATUS  0x0CU

#define CLK_HZ      100000000ULL
#define WINDOW_TICKS 1000U

#define TIMEOUT     10000000U

int main (void) 
{
    uint32_t count;
    uint32_t status;
    uint32_t timeout;
    uint64_t frequency_hz;

    Xil_Out32(COUNTER_BASEADDR + REG_WINDOW, WINDOW_TICKS);
    Xil_Out32(COUNTER_BASEADDR + REG_CTRL, 1);
    
    timeout = TIMEOUT;

    do
    {
        status = Xil_In32(COUNTER_BASEADDR + REG_STATUS) & 1U;

        if (status != 0U)
            break;

        timeout--;
    } 
    while (timeout != 0U);

    if (timeout == 0U) 
    {
        xil_printf("ERROR: measurement timeout\r\n");
        return 1;
    }

    count = Xil_In32(COUNTER_BASEADDR + REG_COUNT);

    frequency_hz = ((uint64_t)count * CLK_HZ) / WINDOW_TICKS;

    xil_printf("Window: %lu clock ticks\r\n",
               (unsigned long)WINDOW_TICKS);
    xil_printf("Count: %lu edges\r\n",
               (unsigned long)count);
    xil_printf("Frequency: %llu Hz\r\n",
               (unsigned long long)frequency_hz);

    for(;;)
    {
        
    }
}