//
//  YJTcping.m
//  YJTcping
//
//  Created by symbio on 2021/10/9.
//

#import "YJTcping.h"
#import <YJTimer/YJTimer.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <mach/mach_time.h>

@interface YJTcping () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) YJTimer *timer;
@property (nonatomic, strong) dispatch_queue_t timerQueue;
//保存最近6次的值
@property (nonatomic, strong) NSMutableArray* lagTimeBuf;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;

@property (nonatomic, assign) uint64_t beginTime;

//最近6次的平均值
@property (nonatomic, assign) uint64_t avgLagTime;
/// 最后一次的tcping连接耗时
@property (nonatomic, assign) uint64_t lastTcpingTime;
@end


@implementation YJTcping

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.timeInterval = 15;
    }
    return self;
}

static const int ping_default_time = 2000; //ms


- (NSString *)defaultPingAddress {
    return @"https://www.baidu.com";
}

+ (YJTcping *)sharedObj {
    static dispatch_once_t pred = 0;
    __strong static YJTcping * _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[YJTcping alloc] init];
        _sharedObject.timerQueue = dispatch_queue_create("com.bonree.BRTcppingTimer", DISPATCH_QUEUE_SERIAL);
        _sharedObject.lagTimeBuf            = [[NSMutableArray alloc] init];
        
        /// 指定代理执行的队列，一个队列允许多个线程
        _sharedObject.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:_sharedObject delegateQueue:_sharedObject.timerQueue];
    });
    
    return _sharedObject;
}

+ (BOOL)startTcping {
    return [self startTcpingWithPingAddress:nil];
}

+ (BOOL)startTcpingWithPingAddress:(NSString *)address {
    
    if ([YJTcping sharedObj].timer.isRunning) { return YES; }
    
    [YJTcping sharedObj].timer = [[YJTimer alloc] init];
    
    
    [[YJTcping sharedObj].timer startWithStart:DISPATCH_TIME_NOW
                                   timeInterval:[YJTcping sharedObj].timeInterval * NSEC_PER_SEC
                                          queue:[YJTcping sharedObj].timerQueue
                                   eventHandler:^{
                                       
                                       [[YJTcping sharedObj] tcpingWithPingAddress:address];
                                   }];
    return YES;
}

- (void)tcpingWithPingAddress:(NSString *)address {
        
    NSString *url = address;
    if (url == nil || ([url length] == 0)) {
        url = self.defaultPingAddress;
    }
    
    if (![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"]) {
        url = [NSString stringWithFormat:@"http://%@", url];
    }
    
    
    NSURL * nsurl = [NSURL URLWithString:url];
    
    int timeout = ping_default_time;
    if (nsurl == nil || [nsurl host] == nil) {
        [self saveLagTime:timeout];
        return;
    }
    
    int port = nsurl.port.intValue;
    
    if ([nsurl port] == nil) {
        if ([nsurl.absoluteString hasPrefix:@"http://"]) {
            port = 80;
        }
        
        if ([nsurl.absoluteString hasPrefix:@"https://"]) {
            port = 443;
        }
    } else {
        ///  过滤非tcping协议端口
        NSArray *agreementPorts = @[@21,
                                    @22,
                                    @23,
                                    @25,
                                    @53,
                                    @80,
                                    @110,
                                    @443];
        
        if (![agreementPorts containsObject:nsurl.port]) {
            [self saveLagTime:timeout];
            return;
        }
    }
    
    uint64_t beginTime = [self cpuTimeMs];
    self.beginTime = beginTime;
    NSError *error = nil;
    
    [self.clientSocket connectToHost:nsurl.host onPort:port withTimeout:timeout/1000 error:&error];
    if (error) {
        [self.clientSocket disconnect];
    }
}

+ (BOOL)stopTcping {
    
    if ([YJTcping sharedObj].timer) {
        if ([YJTcping sharedObj].timer.isRunning) {
            [[YJTcping sharedObj].timer stop];
        }
        [YJTcping sharedObj].timer = nil;
    }
    
    dispatch_async([YJTcping sharedObj].timerQueue, ^{
        [[YJTcping sharedObj].lagTimeBuf removeAllObjects];
    });
    
    return YES;
}

- (void)saveLagTime:(uint64_t)lagTime {
    if (lagTime > ping_default_time) {
        lagTime = ping_default_time;
    }
    self.beginTime = 0;

    NSLog(@"tcping connect cost:%llu ms", lagTime);
    
    [self.lagTimeBuf addObject:[NSNumber numberWithUnsignedLongLong:lagTime]];
    
    //只保留6个数据
    if ([self.lagTimeBuf count] > 6) {
        [self.lagTimeBuf removeObjectAtIndex:0];
    }
    
    self.lastTcpingTime = lagTime;
    
    unsigned long long sum = 0;
    for (NSNumber * i in self.lagTimeBuf) {
        sum += [i unsignedLongLongValue];
    }
    self.avgLagTime = sum / [self.lagTimeBuf count];
}

/// 成功连接才会执行的代理
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self.clientSocket disconnect];
}

/// 代理结果回调在timerQueue队列中，不需要特意添加队列
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    uint64_t endTime = [self cpuTimeMs];
    uint64_t cost = endTime - self.beginTime;
    if (err) { cost = ping_default_time; }
    
    [self saveLagTime:cost];
}

- (NSInteger)cpuTimeMs {
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return [self absoluteTime] * timebase.numer / timebase.denom /1e6;
}

- (NSInteger)absoluteTime {
    if (@available(iOS 10.0, *)) {
        return mach_continuous_time();
    }
    return mach_absolute_time();
}

@end
