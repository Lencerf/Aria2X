//
//  Aria2Core.m
//  Aria2X
//
//  Created by Lencerf on 16/6/24.
//  Copyright © 2016年 Lencerf. All rights reserved.
//

#import "Aria2Core.h"
#import "aria2.h"

@implementation Aria2Core {
    dispatch_queue_t aria2Queue;
    aria2::Session* session;
    BOOL mEnableRPC;
    std::string rpc_secret;
}

- (instancetype)init {
    return [self initWithOptions:nil];
}

int downloadEventCallback(aria2::Session* session, aria2::DownloadEvent event,
                          aria2::A2Gid gid, void* userData) {
    printf("event is %d\n", event);
    return 0;
}

- (instancetype)initWithOptions:(NSDictionary*)optionDict {
    self = [super init];
    if (self) {
        aria2Queue = dispatch_queue_create("aria2.queue", DISPATCH_QUEUE_SERIAL);
        aria2::libraryInit();
        aria2::KeyVals globalOptions = dictToKeyVals(optionDict);
        aria2::SessionConfig sessionConfig;
        sessionConfig.keepRunning = true;
        sessionConfig.downloadEventCallback = downloadEventCallback;
        session = aria2::sessionNew(globalOptions, sessionConfig);
        printf("inited\n");
        dispatch_async(aria2Queue, ^{
            aria2::run(session, aria2::RUN_DEFAULT);
        });
    }
    return self;
}

- (void)restartWithOptions:(NSDictionary*)optionDict {
    aria2::KeyVals globalOptions = dictToKeyVals(optionDict);
    aria2::SessionConfig sessionConfig;
    sessionConfig.keepRunning = true;
    aria2::shutdown(session);
    dispatch_async(aria2Queue, ^{
        aria2::sessionFinal(session);
        printf("sessionFinal\n");
    });
    dispatch_async(aria2Queue, ^{
        session = aria2::sessionNew(globalOptions, aria2::SessionConfig());
        aria2::run(session, aria2::RUN_DEFAULT);
    });
}

- (void)dealloc {
    [self endCore];
    printf("dealloc\n");
}

aria2::KeyVals dictToKeyVals(NSDictionary* ns_dict) {
    aria2::KeyVals keyvals;
    for (NSString* key in [ns_dict allKeys]) {
        std::string key_str([key cStringUsingEncoding:NSUTF8StringEncoding]);
        std::string value_str([ns_dict[key] cStringUsingEncoding:NSUTF8StringEncoding]);
        keyvals.push_back(std::make_pair(key_str, value_str));
    }
    return keyvals;
}

NSString* std_str_to_NSString(std::string std_str) {
    return [NSString stringWithCString:std_str.c_str() encoding:NSUTF8StringEncoding];
}

- (void)endCore {
    std::vector<aria2::A2Gid> taskDownloading = aria2::getActiveDownload(session);
    for (auto i = taskDownloading.begin(); i != taskDownloading.end(); ++i) {
        aria2::pauseDownload(session, *i);
    }
    while (aria2::getGlobalStat(session).numActive > 0) {
        system("sleep 0.1"); // +1s
    }
    printf("all task paused\n");
    aria2::shutdown(session);
    dispatch_sync(aria2Queue, ^{
        aria2::sessionFinal(session);
        printf("sessionFinal\n");
    });
    aria2::libraryDeinit();
    printf("ended\n");
}

- (void)forcePauseAllDownload {
    std::vector<aria2::A2Gid> taskDownloading = aria2::getActiveDownload(session);
    for (auto i = taskDownloading.begin(); i != taskDownloading.end(); ++i) {
        aria2::pauseDownload(session, *i, true);
    }
}

- (int)pauseDownload:(unsigned long long)gid {
    return aria2::pauseDownload(session, gid);
}

- (int)unpauseDownload:(unsigned long long)gid {
    return aria2::unpauseDownload(session, gid);
}

- (int)removeDownload:(unsigned long long)gid {
    return aria2::removeDownload(session, gid, true); // force remove 
}

- (BOOL)removeDownloadResult:(unsigned long long)gid {
    return aria2::removeDownloadResult(session, gid);
}

- (void)purgeDownloadResult {
    aria2::purgeDownloadResult(session);
}

- (int)status:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    if (dh == NULL) {
        printf("dh is NULL\n");
        return 0;
    }
    int status = dh->getStatus();
    return status;
}


- (NSArray*)files:(unsigned long long)gid {
    NSLog(@"%@", [self infoDict:gid][@"files"]);
    return [self infoDict:gid][@"files"];
}

- (NSDictionary*)infoDict: (unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    if (dh == NULL) {
        aria2::deleteDownloadHandle(dh);
        return nil;
    } else {
        NSMutableArray* fileArray = [[NSMutableArray alloc] init];
        auto file_vector = dh->getFiles();
        for (auto i = file_vector.begin(); i != file_vector.end() ; ++i) {
            auto uris = i->uris;
            NSMutableArray *urlArray = [[NSMutableArray alloc] init];
            for (auto i_url = uris.begin(); i_url != uris.end(); ++i_url) {
                [urlArray addObject:std_str_to_NSString(i_url->uri)];
            }
            NSDictionary* afile = @{@"path": std_str_to_NSString(i->path),
                                    @"urls": urlArray};
            [fileArray addObject:afile];
            
        }
        NSDictionary* result = @{@"files": fileArray,
                 @"status": [NSNumber numberWithInt:dh->getStatus()],
                 @"totalLength": [NSNumber numberWithLongLong:dh->getTotalLength()],
                 @"completedLength": [NSNumber numberWithLongLong:dh->getCompletedLength()],
                 @"uploadedLength": [NSNumber numberWithLongLong:dh->getUploadLength()],
                 @"dls": [NSNumber numberWithInt:dh->getDownloadSpeed()],
                 @"uls": [NSNumber numberWithInt:dh->getUploadSpeed()]};
        aria2::deleteDownloadHandle(dh);
        return result;
    }
}

- (int64_t)completedLength:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    auto length = dh->getCompletedLength();
    aria2::deleteDownloadHandle(dh);
    return length;
}

- (int64_t)uploadLength:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    auto length = dh->getUploadLength();
    aria2::deleteDownloadHandle(dh);
    return length;
}

- (int64_t)totalLength:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    auto length = dh->getTotalLength();
    aria2::deleteDownloadHandle(dh);
    return length;
}

- (int)downloadSpeed:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    auto speed = dh->getDownloadSpeed();
    aria2::deleteDownloadHandle(dh);
    return speed;
}

- (int)uploadSpeed:(unsigned long long)gid {
    aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
    auto speed = dh->getUploadSpeed();
    aria2::deleteDownloadHandle(dh);
    return speed;
}

- (NSDictionary*)globalStat {
    auto stat = aria2::getGlobalStat(session);
    return @{@"downloadSpeed": [NSNumber numberWithInt:stat.downloadSpeed],
             @"uploadSpeed": [NSNumber numberWithInt:stat.uploadSpeed],
             @"numActive": [NSNumber numberWithInt:stat.numActive],
             @"numWaiting": [NSNumber numberWithInt:stat.numWaiting],
             @"numStopped": [NSNumber numberWithInt:stat.numStopped],};
}

- (BOOL)isValidGid:(unsigned long long)gid {
    return !aria2::isNull(gid);
}

- (int)addURL:(NSString*)URL options:(NSDictionary*)options {
    std::string url([URL cStringUsingEncoding:NSUTF8StringEncoding]);
    std::vector<std::string> urls = {url};
    aria2::KeyVals keyvals;
    keyvals.push_back(std::make_pair("split", "10"));
    
    return aria2::addUri(session, NULL, urls, keyvals);
}

- (NSArray*)activeDownload {
    auto list = aria2::getActiveDownload(session);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (auto i = list.begin(); i != list.end(); ++i) {
        [array addObject:[NSNumber numberWithUnsignedLongLong:*i]];
    }
    return array;
}

- (NSArray*)waitingDownload {
    auto list = aria2::getWaitingDownload(session);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (auto i = list.begin(); i != list.end(); ++i) {
        [array addObject:[NSNumber numberWithUnsignedLongLong:*i]];
    }
    return array;
}

- (NSArray*)stoppedDownload {
    auto list = aria2::getStoppedDownload(session);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (auto i = list.begin(); i != list.end(); ++i) {
        [array addObject:[NSNumber numberWithUnsignedLongLong:*i]];
    }
    return array;
}

- (NSArray*)errorDownload {
    auto list = aria2::getErrorDownload(session);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (auto i = list.begin(); i != list.end(); ++i) {
        [array addObject:[NSNumber numberWithUnsignedLongLong:*i]];
    }
    return array;
}

- (NSArray*)completeDownload {
    auto list = aria2::getCompleteDownload(session);
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (auto i = list.begin(); i != list.end(); ++i) {
        [array addObject:[NSNumber numberWithUnsignedLongLong:*i]];
    }
    return array;
}

- (int)testMyAPI {
    auto waitList = aria2::getWaitingDownload(session);
    for (auto i = waitList.begin(); i != waitList.end(); ++i) {
        printf("%llu\t", *i);
    }
    printf("\n");
    auto stopList = aria2::getStoppedDownload(session);
    for (auto i = stopList.begin(); i != stopList.end(); ++i) {
        printf("%llu\t", *i);
    }
    printf("\n");
    printf("errorlist:");
    auto errorlist = aria2::getErrorDownload(session);
    for (auto i = errorlist.begin(); i != errorlist.end(); ++i) {
        printf("%llu\t", *i);
    }
    printf("completelist:");
    auto completelist = aria2::getCompleteDownload(session);
    for (auto i = completelist.begin(); i != completelist.end(); ++i) {
        printf("%llu\t", *i);
    }
    printf("\n");
    return 0;
}

@end
