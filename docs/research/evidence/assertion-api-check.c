#include <IOKit/pwr_mgt/IOPMLib.h>
int main(void) {
 CFDictionaryRef status = NULL;
 IOReturn result = IOPMCopyAssertionsStatus(&status);
 if (status) CFRelease(status);
 return result == kIOReturnSuccess ? 0 : 1;
}
