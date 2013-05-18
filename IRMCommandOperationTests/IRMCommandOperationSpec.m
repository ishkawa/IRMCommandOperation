#import "Kiwi.h"
#import "IRMCommandOperation.h"

static NSTimeInterval const RMTRunInterval = .2;

SPEC_BEGIN(IRMCommandOperationSpec)

describe(@"IRMCommandOperation", ^{
    __block IRMCommandOperation *operation;
    
    beforeEach(^{
        operation = [[IRMCommandOperation alloc] init];
    });
    
    it(@"has au command by default", ^{
        [[operation.command should] equal:@"au"];
    });
    
    context(@"reading buffer", ^{
        __block KWMock *mock;
        
        beforeEach(^{
            mock = [KWMock partialMockForObject:operation.inputStream];
            [operation stub:@selector(inputStream) andReturn:mock];
            [mock stub:@selector(read:maxLength:)];
        });
        
        it(@"reads input stream", ^{
            [[mock should] receive:@selector(read:maxLength:)];
            [operation performSelector:@selector(readBuffer)];
        });
        
        it(@"appends data", ^{
            [[operation.data should] receive:@selector(appendBytes:length:)];
            [operation performSelector:@selector(readBuffer)];
        });
        
        context(@"data contains \r\n", ^{
            __block NSMutableData *data;
            
            beforeEach(^{
                data = [[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
                [operation stub:@selector(data) andReturn:data];
            });
            
            it(@"closes input stream", ^{
                [[mock should] receive:@selector(close)];
                [operation performSelector:@selector(readBuffer)];
            });
            
            it(@"removes output stream from runloop", ^{
                [[mock should] receive:@selector(removeFromRunLoop:forMode:)];
                [operation performSelector:@selector(readBuffer)];
            });
        });
        
        context(@"data does not contains \r\n", ^{
            __block NSMutableData *data;
            
            beforeEach(^{
                data = [[@"foo" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
                [operation stub:@selector(data) andReturn:data];
            });
            
            it(@"does not close input stream", ^{
                [[mock shouldNot] receive:@selector(close)];
                [operation performSelector:@selector(readBuffer)];
            });
            
            it(@"does not remove output stream from runloop", ^{
                [[mock shouldNot] receive:@selector(removeFromRunLoop:forMode:)];
                [operation performSelector:@selector(readBuffer)];
            });
        });
    });
    
    context(@"sending command", ^{
        __block KWMock *mock;
        
        beforeEach(^{
            operation.command = @"au";
            mock = [KWMock partialMockForObject:operation.outputStream];
            [operation stub:@selector(outputStream) andReturn:mock];
        });
        
        it(@"writes command into output stream", ^{
            [[mock should] receive:@selector(write:maxLength:)];
            [operation performSelector:@selector(sendCommand)];
        });
        
        it(@"closes output stream", ^{
            [[mock should] receive:@selector(close)];
            [operation performSelector:@selector(sendCommand)];
        });
        
        it(@"removes output stream from runloop", ^{
            [[mock should] receive:@selector(removeFromRunLoop:forMode:)];
            [operation performSelector:@selector(sendCommand)];
        });
    });
    
    context(@"receiving stream events", ^{
        it(@"invokes sendCommand on NSStreamEventHasSpaceAvailable", ^{
            [[operation should] receive:@selector(sendCommand)];
            [operation stream:operation.outputStream handleEvent:NSStreamEventHasSpaceAvailable];
        });
        
        it(@"invokes readBuffer on NSStreamEventHasBytesAvailable", ^{
            [[operation should] receive:@selector(readBuffer)];
            [operation stream:operation.inputStream handleEvent:NSStreamEventHasBytesAvailable];
        });
        
        it(@"invokes failWithStream on NSStreamEventErrorOccurred", ^{
            [[operation should] receive:@selector(failWithStream:)];
            [operation stream:operation.inputStream handleEvent:NSStreamEventErrorOccurred];
        });
    });
    
    context(@"becoming object to release", ^{
        __block dispatch_semaphore_t semaphore;
        __block __weak IRMCommandOperation *weakOperation;
        
        beforeEach(^{
            semaphore = dispatch_semaphore_create(0);
        });
        
        afterEach(^{
            dispatch_release(semaphore);
        });
        
        it(@"will be deallocated when it completes tasks", ^{
            @autoreleasepool {
                IRMCommandOperation *strongOperation = [[IRMCommandOperation alloc] init];
                weakOperation = strongOperation;
                strongOperation.completionBlock = ^{
                    dispatch_semaphore_signal(semaphore);
                };
                [strongOperation start];
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            // run to release completed operation
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:RMTRunInterval]];
            [weakOperation shouldBeNil];
        });
        
        it(@"will be deallocated when it is cancelled before starting", ^{
            @autoreleasepool {
                IRMCommandOperation *strongOperation = [[IRMCommandOperation alloc] init];
                weakOperation = strongOperation;
                [strongOperation cancel];
            }
            
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:RMTRunInterval]];
            [weakOperation shouldBeNil];
        });
        
        it(@"will be deallocated when it is cancelled after starting", ^{
            @autoreleasepool {
                IRMCommandOperation *strongOperation = [[IRMCommandOperation alloc] init];
                weakOperation = strongOperation;
                [strongOperation start];
                [strongOperation cancel];
            }
            
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:RMTRunInterval]];
            [weakOperation shouldBeNil];
        });
    });
});

SPEC_END
