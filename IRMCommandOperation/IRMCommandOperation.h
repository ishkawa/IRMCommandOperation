#import <Foundation/Foundation.h>

static NSString *const IRMHostName = @"10.0.1.3";
static NSInteger const IRMPort = 51013;

@interface IRMCommandOperation : NSOperation  <NSStreamDelegate> {
    BOOL _executing;
    BOOL _finished;
}

@property (nonatomic, strong) NSString *command;
@property (nonatomic, strong) NSString *argument;
@property (nonatomic, copy) void (^handler)(NSData *, NSError *);

@property (nonatomic, readonly) NSMutableData *data;
@property (nonatomic, readonly) NSInputStream *inputStream;
@property (nonatomic, readonly) NSOutputStream *outputStream;

- (id)initWithCommand:(NSString *)command
             argument:(NSString *)argument
              handler:(void (^)(NSData *data, NSError *error))handler;

+ (void)sendCommand:(NSString *)command
           argument:(NSString *)argument
              queue:(NSOperationQueue *)queue
            handler:(void (^)(NSData *data, NSError *error))handler;


@end
