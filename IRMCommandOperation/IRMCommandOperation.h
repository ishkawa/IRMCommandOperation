#import <Foundation/Foundation.h>

static NSInteger const IRMPort = 51013;

@interface IRMCommandOperation : NSOperation  <NSStreamDelegate> {
    BOOL _executing;
    BOOL _finished;
}

@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSString *command;
@property (nonatomic, strong) NSString *argument;
@property (nonatomic, copy) void (^handler)(NSData *, NSError *);

@property (nonatomic, readonly) NSMutableData *data;
@property (nonatomic, readonly) NSInputStream *inputStream;
@property (nonatomic, readonly) NSOutputStream *outputStream;

- (id)initWithHost:(NSString *)host
           command:(NSString *)command
          argument:(NSString *)argument
           handler:(void (^)(NSData *, NSError *))handler;

+ (void)sendCommand:(NSString *)command
           argument:(NSString *)argument
               host:(NSString *)host
              queue:(NSOperationQueue *)queue
            handler:(void (^)(NSData *data, NSError *error))handler;


@end
