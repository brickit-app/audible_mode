#import <Foundation/Foundation.h>

void AMInstallEngineLifecycleSpies(Class pluginClass);
NSArray<NSString *> *AMEventChannelSends(void);
void AMResetEventChannelSends(void);
int AMDetachCount(void);
