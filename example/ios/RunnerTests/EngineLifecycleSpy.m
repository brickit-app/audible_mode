#import "EngineLifecycleSpy.h"

#import <Flutter/Flutter.h>
#import <objc/runtime.h>

static NSMutableArray<NSString *> *AMEventSends;
static int AMDetachCalls = 0;
static IMP AMOriginalSend = NULL;
static IMP AMOriginalDetach = NULL;

static void AMRecordedSend(id self, SEL _cmd, NSString *channel, NSData *message, FlutterBinaryReply reply) {
  if ([channel isEqualToString:@"CURRENT_VOLUME_EVENT"] ||
      [channel isEqualToString:@"CURRENT_PROFILE_EVENT"]) {
    [AMEventSends addObject:channel];
  }
  ((void (*)(id, SEL, NSString *, NSData *, FlutterBinaryReply))AMOriginalSend)(
      self, _cmd, channel, message, reply);
}

static void AMRecordedDetach(id self, SEL _cmd, id registrar) {
  AMDetachCalls += 1;
  ((void (*)(id, SEL, id))AMOriginalDetach)(self, _cmd, registrar);
}

void AMInstallEngineLifecycleSpies(Class pluginClass) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    AMEventSends = [NSMutableArray array];
    Method send = class_getInstanceMethod([FlutterEngine class],
                                           @selector(sendOnChannel:message:binaryReply:));
    NSCAssert(send != NULL, @"FlutterEngine sendOnChannel:message:binaryReply: is missing");
    AMOriginalSend = method_setImplementation(send, (IMP)AMRecordedSend);

    NSCAssert(pluginClass != Nil, @"AudibleModePlugin is not loaded");
    Method detach = class_getInstanceMethod(pluginClass, @selector(detachFromEngineForRegistrar:));
    NSCAssert(detach != NULL, @"detachFromEngineForRegistrar: is not on the published plugin class");
    AMOriginalDetach = method_setImplementation(detach, (IMP)AMRecordedDetach);
  });
}

NSArray<NSString *> *AMEventChannelSends(void) {
  return [AMEventSends copy];
}

void AMResetEventChannelSends(void) {
  [AMEventSends removeAllObjects];
}

int AMDetachCount(void) {
  return AMDetachCalls;
}
