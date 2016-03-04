#import "MGLDownloadController.h"

#import "MGLAccountManager_Private.h"
#import "MGLGeometry_Private.h"
#import "MGLDownloadable_Private.h"
#import "MGLDownloadRegion_Private.h"
#import "MGLTilePyramidDownloadRegion.h"

#include <mbgl/storage/default_file_source.hpp>
#include <mbgl/util/string.hpp>

@interface MGLDownloadController ()

- (instancetype)initWithFileName:(NSString *)fileName NS_DESIGNATED_INITIALIZER;

@end

@implementation MGLDownloadController {
    mbgl::DefaultFileSource *_mbglFileSource;
}

+ (instancetype)sharedController {
    static dispatch_once_t onceToken;
    static MGLDownloadController *sharedController;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] initWithFileName:@"offline.db"];
    });
    return sharedController;
}

- (instancetype)initWithFileName:(NSString *)fileName {
    if (self = [super init]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *fileCachePath = [paths.firstObject stringByAppendingPathComponent:fileName];
        _mbglFileSource = new mbgl::DefaultFileSource(fileCachePath.UTF8String, [NSBundle mainBundle].resourceURL.path.UTF8String);
        
        // Observe for changes to the global access token (and find out the current one).
        [[MGLAccountManager sharedManager] addObserver:self
                                            forKeyPath:@"accessToken"
                                               options:(NSKeyValueObservingOptionInitial |
                                                        NSKeyValueObservingOptionNew)
                                               context:NULL];
    }
    return self;
}

- (void)dealloc {
    [[MGLAccountManager sharedManager] removeObserver:self forKeyPath:@"accessToken"];
    
    delete _mbglFileSource;
    _mbglFileSource = nullptr;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NS_DICTIONARY_OF(NSString *, id) *)change context:(__unused void *)context {
    // Synchronize mbgl::Map’s access token with the global one in MGLAccountManager.
    if ([keyPath isEqualToString:@"accessToken"] && object == [MGLAccountManager sharedManager]) {
        NSString *accessToken = change[NSKeyValueChangeNewKey];
        if (![accessToken isKindOfClass:[NSNull class]]) {
            _mbglFileSource->setAccessToken(accessToken.UTF8String);
        }
    }
}

- (void)addDownloadableForRegion:(id <MGLDownloadRegion>)downloadRegion withContext:(NSData *)context completionHandler:(MGLDownloadableRegistrationCompletionHandler)completion {
    if (![downloadRegion isKindOfClass:[MGLTilePyramidDownloadRegion class]]) {
        [NSException raise:@"Unsupported region type" format:
         @"Regions of type %@ are unsupported.", NSStringFromClass([downloadRegion class])];
        return;
    }
    
    MGLTilePyramidDownloadRegion *tilePyramidDownloadRegion = (MGLTilePyramidDownloadRegion *)downloadRegion;
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    const float scaleFactor = [UIScreen instancesRespondToSelector:@selector(nativeScale)] ? [[UIScreen mainScreen] nativeScale] : [[UIScreen mainScreen] scale];
#elif TARGET_OS_MAC
    const float scaleFactor = [NSScreen mainScreen].backingScaleFactor;
#endif
    NSString *styleURLString = [tilePyramidDownloadRegion.styleURL.absoluteString copy];
    const mbgl::OfflineTilePyramidRegionDefinition regionDefinition(styleURLString.UTF8String,
                                                                    MGLLatLngBoundsFromCoordinateBounds(tilePyramidDownloadRegion.bounds),
                                                                    tilePyramidDownloadRegion.minimumZoomLevel,
                                                                    tilePyramidDownloadRegion.maximumZoomLevel,
                                                                    scaleFactor);
    mbgl::OfflineRegionMetadata metadata(context.length);
    [context getBytes:&metadata[0] length:metadata.capacity()];
    _mbglFileSource->createOfflineRegion(regionDefinition, metadata, [&, completion](std::exception_ptr exception, mbgl::optional<mbgl::OfflineRegion> region) {
        NSError *error;
        if (exception) {
            NSString *errorDescription = @(mbgl::util::toString(exception).c_str());
            error = [NSError errorWithDomain:MGLErrorDomain code:-1 userInfo:errorDescription ? @{
                NSLocalizedDescriptionKey: errorDescription,
            } : nil];
        }
        if (completion) {
            MGLDownloadable *downloadable = [[MGLDownloadable alloc] initWithMBGLRegion:new mbgl::OfflineRegion(std::move(*region))];
            dispatch_async(dispatch_get_main_queue(), [&, completion, error, downloadable](void) {
                completion(downloadable, error);
            });
        }
    });
}

- (void)resumeDownloadable:(MGLDownloadable *)downloadable {
    _mbglFileSource->setOfflineRegionDownloadState(*downloadable.mbglOfflineRegion, mbgl::OfflineRegionDownloadState::Active);
}

- (void)suspendDownloadable:(MGLDownloadable *)downloadable {
    _mbglFileSource->setOfflineRegionDownloadState(*downloadable.mbglOfflineRegion, mbgl::OfflineRegionDownloadState::Inactive);
}

- (void)cancelDownloadable:(MGLDownloadable *)downloadable withCompletionHandler:(MGLDownloadableCancellationCompletionHandler)completion {
    _mbglFileSource->deleteOfflineRegion(std::move(*downloadable.mbglOfflineRegion), [&, completion](std::exception_ptr exception) {
        dispatch_async(dispatch_get_main_queue(), [&, completion](void) {
            NSError *error;
            if (exception) {
                error = [NSError errorWithDomain:MGLErrorDomain code:-1 userInfo:@{
                    NSLocalizedDescriptionKey: @(mbgl::util::toString(exception).c_str()),
                }];
            }
            if (completion) {
                completion(error);
            }
        });
    });
}

- (void)requestDownloadablesWithCompletionHandler:(MGLDownloadablesRequestCompletionHandler)completion {
    _mbglFileSource->listOfflineRegions([&, completion](std::exception_ptr exception, mbgl::optional<std::vector<mbgl::OfflineRegion>> regions) {
        dispatch_async(dispatch_get_main_queue(), [&, completion](void) {
            NSError *error;
            if (exception) {
                error = [NSError errorWithDomain:MGLErrorDomain code:-1 userInfo:@{
                    NSLocalizedDescriptionKey: @(mbgl::util::toString(exception).c_str()),
                }];
            }
            if (completion) {
                NSMutableArray *downloadables;
                if (regions) {
                    downloadables = [NSMutableArray arrayWithCapacity:regions->size()];
                    for (mbgl::OfflineRegion &region : *regions) {
                        MGLDownloadable *downloadable = [[MGLDownloadable alloc] initWithMBGLRegion:new mbgl::OfflineRegion(std::move(region))];
                        mbgl::OfflineRegionObserver *observer = downloadable.mbglOfflineRegionObserver;
                        _mbglFileSource->setOfflineRegionObserver(*downloadable.mbglOfflineRegion, std::make_unique<mbgl::OfflineRegionObserver>(*observer));
                        [downloadables addObject:downloadable];
                    }
                }
                completion(downloadables, error);
            }
        });
    });
}

- (void)setMaximumAllowedMapboxTiles:(uint64_t)maximumCount {
    _mbglFileSource->setOfflineMapboxTileCountLimit(maximumCount);
}

@end
