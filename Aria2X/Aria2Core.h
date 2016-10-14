//
//  Aria2Core.h
//  Aria2X
//
//  Created by Lencerf on 16/6/24.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Aria2Core : NSObject

- (instancetype)initWithOptions:(NSDictionary*)optionDict;
- (void)restartWithOptions:(NSDictionary*)optionDict;
- (void)endCore;
- (void)forcePauseAllDownload;

- (int)pauseDownload:(unsigned long long)gid;
- (int)unpauseDownload:(unsigned long long)gid;
- (int)removeDownload:(unsigned long long)gid;
- (BOOL)removeDownloadResult:(unsigned long long)gid;
- (void)purgeDownloadResult;

- (int)status:(unsigned long long)gid;
- (int64_t)completedLength:(unsigned long long)gid;
- (int64_t)uploadLength:(unsigned long long)gid;
- (int64_t)totalLength:(unsigned long long)gid;
- (int)downloadSpeed:(unsigned long long)gid;
- (int)uploadSpeed:(unsigned long long)gid;
- (NSDictionary*)infoDict:(unsigned long long)gid;
- (NSArray*)files:(unsigned long long)gid;
- (NSDictionary*)globalStat;
- (BOOL)isValidGid:(unsigned long long)gid;

- (int)addURL:(NSString*)URL options:(NSDictionary*)options;

- (NSArray*)activeDownload;
- (NSArray*)waitingDownload;
- (NSArray*)errorDownload;
- (NSArray*)completeDownload;
//- (NSArray*)stoppedDownload;

- (int)testMyAPI;

@end
