#import "ZendeskBridge.h"
#import <ZendeskSDK/ZendeskSDK-Swift.h>

@implementation ZendeskBridge

+ (ZendeskBridge *)shared {
    static ZendeskBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ZendeskBridge alloc] init]; });
    return instance;
}

- (void)loginUser:(Zendesk *)zendesk jwt:(NSString *)jwt completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    [zendesk loginUserWith:jwt completionHandler:completion];
}

- (void)logoutUser:(Zendesk *)zendesk completion:(void (^)(NSError * _Nullable))completion {
    [zendesk logoutUserWithCompletionHandler:completion];
}

- (void)startObservingEvents:(Zendesk *)zendesk observer:(NSObject *)observer handler:(void (^)(NSInteger, id _Nullable))handler {
    [zendesk addEventObserver:observer :^(enum ZDKZendeskEvent event, id _Nullable payload) {
        handler((NSInteger)event, payload);
    }];
}

- (void)stopObservingEvents:(Zendesk *)zendesk observer:(NSObject *)observer {
    [zendesk removeEventObserver:observer];
}

- (NSInteger)fetchUnreadCount:(Zendesk *)zendesk {
    return [zendesk.messaging getUnreadMessageCount];
}

@end
