//
//  YJTcping.h
//  YJTcping
//
//  Created by symbio on 2021/10/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//通过ping网络来测试阶段性网络状况
@interface YJTcping : NSObject
/// 间隔时间秒（默认 15）
@property (nonatomic, assign) uint64_t timeInterval;

@property (nonatomic, strong, readonly) NSString *defaultPingAddress;


//最近6次的平均值
@property (nonatomic, assign, readonly) uint64_t avgLagTime;
/// 最后一次的tcping连接耗时
@property (nonatomic, assign, readonly) uint64_t lastTcpingTime;
+ (YJTcping *)sharedObj;

+ (BOOL)startTcping;
+ (BOOL)startTcpingWithPingAddress:(NSString * _Nullable)address;
+ (BOOL)stopTcping;
@end

NS_ASSUME_NONNULL_END
