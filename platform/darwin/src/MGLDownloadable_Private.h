#import "MGLDownloadable.h"

#include <mbgl/storage/default_file_source.hpp>

class MBGLOfflineRegionObserver;

@interface MGLDownloadable (Private)

@property (nonatomic) mbgl::OfflineRegion *mbglOfflineRegion;
@property (nonatomic, readonly) MBGLOfflineRegionObserver *mbglOfflineRegionObserver;

- (instancetype)initWithMBGLRegion:(mbgl::OfflineRegion *)region;

@end

class MBGLOfflineRegionObserver : public mbgl::OfflineRegionObserver {
public:
    MBGLOfflineRegionObserver(MGLDownloadable *downloadable_) : downloadable(downloadable_) {}
    
    void statusChanged(mbgl::OfflineRegionStatus status) override;
    void responseError(mbgl::Response::Error error) override;
    void mapboxTileCountLimitExceeded(uint64_t limit) override;
    
private:
    __weak MGLDownloadable *downloadable = nullptr;
};
