#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Zendesk;

@interface ZendeskBridge : NSObject

@property (class, readonly, strong) ZendeskBridge *shared;

- (void)loginUser:(Zendesk *)zendesk
              jwt:(NSString *)jwt
       completion:(void (^)(id _Nullable user, NSError * _Nullable error))completion;

- (void)logoutUser:(Zendesk *)zendesk
        completion:(void (^)(NSError * _Nullable error))completion;

- (void)startObservingEvents:(Zendesk *)zendesk
                    observer:(NSObject *)observer
                     handler:(void (^)(NSInteger event, id _Nullable payload))handler;

- (void)stopObservingEvents:(Zendesk *)zendesk
                   observer:(NSObject *)observer;

- (NSInteger)fetchUnreadCount:(Zendesk *)zendesk;

@end

NS_ASSUME_NONNULL_END
