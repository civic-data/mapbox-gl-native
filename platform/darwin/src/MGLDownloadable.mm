#import "MGLDownloadable_Private.h"

#import "MGLDownloadController_Private.h"
#import "MGLDownloadRegion_Private.h"
#import "MGLTilePyramidDownloadRegion.h"

#include <mbgl/storage/default_file_source.hpp>

class MBGLOfflineRegionObserver;

@interface MGLDownloadable ()

@property (nonatomic, readwrite) mbgl::OfflineRegion *mbglOfflineRegion;
@property (nonatomic, readwrite) MBGLOfflineRegionObserver *mbglOfflineRegionObserver;
@property (nonatomic, readwrite) MGLDownloadableState state;
@property (nonatomic, readwrite) MGLDownloadableProgress progress;

@end

@implementation MGLDownloadable

- (instancetype)init {
    [NSException raise:@"Method unavailable"
                format:
     @"-[MGLDownloadable init] is unavailable. "
     @"Use +[MGLDownloadController addDownloadRegion:context:completionHandler:] instead."];
    return nil;
}

- (instancetype)initWithMBGLRegion:(mbgl::OfflineRegion *)region {
    if (self = [super init]) {
        _mbglOfflineRegion = region;
        _state = MGLDownloadableStateInactive;
        _mbglOfflineRegionObserver = new MBGLOfflineRegionObserver(self);
    }
    return self;
}

- (void)dealloc {
    delete _mbglOfflineRegionObserver;
    _mbglOfflineRegionObserver = nullptr;
}

- (id <MGLDownloadRegion>)region {
    const mbgl::OfflineRegionDefinition &regionDefinition = _mbglOfflineRegion->getDefinition();
    NSAssert([MGLTilePyramidDownloadRegion conformsToProtocol:@protocol(MGLDownloadRegion_Private)], @"MGLTilePyramidDownloadRegion should conform to MGLDownloadRegion_Private.");
    return [(id <MGLDownloadRegion_Private>)[MGLTilePyramidDownloadRegion alloc] initWithOfflineRegionDefinition:regionDefinition];
}

- (NSData *)context {
    auto &metadata = _mbglOfflineRegion->getMetadata();
    return [NSData dataWithBytes:&metadata length:metadata.size()];
}

- (void)resume {
    [[MGLDownloadController sharedController] resumeDownloadable:self];
    self.state = MGLDownloadableStateActive;
}

- (void)suspend {
    [[MGLDownloadController sharedController] suspendDownloadable:self];
    self.state = MGLDownloadableStateInactive;
}

- (void)cancelWithCompletionHandler:(MGLDownloadableCancellationCompletionHandler)completion {
    [[MGLDownloadController sharedController] cancelDownloadable:self withCompletionHandler:completion];
    self.state = MGLDownloadableStateInactive;
}

MGLDownloadableState MGLDownloadableStateFromOfflineRegionDownloadState(mbgl::OfflineRegionDownloadState offlineRegionDownloadState) {
    switch (offlineRegionDownloadState) {
        case mbgl::OfflineRegionDownloadState::Inactive:
            return MGLDownloadableStateInactive;
            
        case mbgl::OfflineRegionDownloadState::Active:
            return MGLDownloadableStateActive;
    }
}

NSError *MGLErrorFromResponseError(mbgl::Response::Error error) {
    NSInteger errorCode = MGLErrorCodeUnknown;
    switch (error.reason) {
        case mbgl::Response::Error::Reason::NotFound:
            errorCode = MGLErrorCodeNotFound;
            break;
            
        case mbgl::Response::Error::Reason::Server:
            errorCode = MGLErrorCodeBadServerResponse;
            break;
            
        case mbgl::Response::Error::Reason::Connection:
            errorCode = MGLErrorCodeConnectionFailed;
            break;
            
        default:
            break;
    }
    return [NSError errorWithDomain:MGLErrorDomain code:errorCode userInfo:@{
        NSLocalizedFailureReasonErrorKey: @(error.message.c_str())
    }];
}

void MBGLOfflineRegionObserver::statusChanged(mbgl::OfflineRegionStatus status) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSCAssert(downloadable, @"MBGLOfflineRegionObserver is dangling without an associated MGLDownloadable.");
        
        switch (status.downloadState) {
            case mbgl::OfflineRegionDownloadState::Inactive:
                downloadable.state = status.complete() ? MGLDownloadableStateComplete : MGLDownloadableStateInactive;
                
            case mbgl::OfflineRegionDownloadState::Active:
                downloadable.state = MGLDownloadableStateActive;
        }
        
        if ([downloadable.delegate respondsToSelector:@selector(downloadable:progressDidChange:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc99-extensions"
            downloadable.progress = {
                .countOfResourcesCompleted = status.completedResourceCount,
                .countOfBytesCompleted = status.completedResourceSize,
                .countOfResourcesExpected = status.requiredResourceCount,
                .maximumResourcesExpected = status.requiredResourceCountIsPrecise ? status.requiredResourceCount : UINT64_MAX,
            };
#pragma clang diagnostic pop
            [downloadable.delegate downloadable:downloadable progressDidChange:downloadable.progress];
        }
    });
}

void MBGLOfflineRegionObserver::responseError(mbgl::Response::Error error) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSCAssert(downloadable, @"MBGLOfflineRegionObserver is dangling without an associated MGLDownloadable.");
        
        if ([downloadable.delegate respondsToSelector:@selector(downloadable:didReceiveError:)]) {
            [downloadable.delegate downloadable:downloadable didReceiveError:MGLErrorFromResponseError(error)];
        }
    });
}

void MBGLOfflineRegionObserver::mapboxTileCountLimitExceeded(uint64_t limit) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSCAssert(downloadable, @"MBGLOfflineRegionObserver is dangling without an associated MGLDownloadable.");
        
        if ([downloadable.delegate respondsToSelector:@selector(downloadable:didReceiveMaximumAllowedMapboxTiles:)]) {
            [downloadable.delegate downloadable:downloadable didReceiveMaximumAllowedMapboxTiles:limit];
        }
    });
}

@end
