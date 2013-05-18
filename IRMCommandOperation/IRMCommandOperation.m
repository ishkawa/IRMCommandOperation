#import "IRMCommandOperation.h"

@interface IRMCommandOperation ()

@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, strong) NSString *mode;

@end

@implementation IRMCommandOperation

- (id)init
{
    return [self initWithCommand:@"au"
                        argument:nil
                         handler:nil];
}

- (id)initWithCommand:(NSString *)command
             argument:(NSString *)argument
              handler:(void (^)(NSData *, NSError *))handler
{
    self = [super init];
    if (self) {
        _command  = command;
        _argument = argument;
        _handler  = handler;
        _data     = [NSMutableData data];
        
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        CFStringRef hostNameRef = (__bridge CFStringRef)IRMHostName;
        
        CFStreamCreatePairWithSocketToHost(NULL,
                                           hostNameRef,
                                           IRMPort,
                                           &readStream,
                                           &writeStream);
        
        _inputStream = (__bridge_transfer NSInputStream *)readStream;
        _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    }
    return self;
}

+ (void)sendCommand:(NSString *)command
           argument:(NSString *)argument
              queue:(NSOperationQueue *)queue
            handler:(void (^)(NSData *, NSError *))handler
{
    IRMCommandOperation *operation = [[IRMCommandOperation alloc] initWithCommand:command
                                                                       argument:argument
                                                                        handler:handler];
    [queue addOperation:operation];
}

#pragma mark - KVO compliant

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return _executing;
}

- (BOOL)isFinished
{
    return _finished;
}

#pragma mark -

- (void)start
{
    if (self.isCancelled || ![self.command length]) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main
{
    @autoreleasepool {
        self.runLoop = [NSRunLoop currentRunLoop];
        self.mode = NSDefaultRunLoopMode;
        
        self.inputStream.delegate = self;
        [self.inputStream scheduleInRunLoop:self.runLoop forMode:self.mode];
        [self.inputStream open];
        
        self.outputStream.delegate = self;
        [self.outputStream scheduleInRunLoop:self.runLoop forMode:self.mode];
        [self.outputStream open];
        
        do {
            @autoreleasepool {
                [self.runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
                if (self.isCancelled) {
                    [self unscheduleStreams];
                    [self completeOperation];
                }
            }
        } while (self.isExecuting);
    }
}

- (void)completeOperation
{
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    _executing = NO;
    _finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

#pragma mark - actions

- (void)readBuffer
{
    uint8_t buffer[1024];
    unsigned int length = [self.inputStream read:buffer maxLength:1024];
    [self.data appendBytes:buffer length:length];
    
    NSLog(@"input: %@", [[NSString alloc] initWithBytes:(const void *)buffer length:length encoding:NSUTF8StringEncoding]);
    
    NSString *joinedString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
    if ([joinedString rangeOfString:@"\r\n"].location != NSNotFound) {
        [self.inputStream close];
        [self.inputStream removeFromRunLoop:self.runLoop forMode:self.mode];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.handler) {
                self.handler(self.data, nil);
            }
        });
        [self completeOperation];
    }
}

- (void)sendCommand
{
    NSString *command;
    if ([self.argument length]) {
        command = [NSString stringWithFormat:@"*%@;%@;\r\n", self.command, self.argument];
    } else {
        command = [NSString stringWithFormat:@"*%@\r\n", self.command];
    }
    const uint8_t *ccommand = (const uint8_t *)[command UTF8String];
    
    [self.outputStream write:ccommand maxLength:strlen((const char *)ccommand)];
    [self.outputStream close];
    [self.outputStream removeFromRunLoop:self.runLoop forMode:self.mode];
    
    NSLog(@"output: %@", command);
}

- (void)failWithStream:(NSStream *)stream
{
    NSLog(@"error: %@", stream.streamError);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.handler) {
            self.handler(self.data, stream.streamError);
        }
    });
    
    [self unscheduleStreams];
    [self completeOperation];
}

- (void)unscheduleStreams
{
    [self.inputStream removeFromRunLoop:self.runLoop forMode:self.mode];
    [self.outputStream removeFromRunLoop:self.runLoop forMode:self.mode];
}


#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode) {
        case NSStreamEventHasBytesAvailable:
            if (stream == self.inputStream) {
                [self readBuffer];
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            if (stream == self.outputStream) {
                [self sendCommand];
            }
            break;
        
        case NSStreamEventErrorOccurred: {
            [self failWithStream:stream];
            break;
        }
            
        default:
            break;
    }
}

@end
