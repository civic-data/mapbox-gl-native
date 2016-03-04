#import "MGLDownloadController.h"

#import "MGLDownloadable.h"

@interface MGLDownloadController (Private)

- (void)resumeDownloadable:(MGLDownloadable *)downloadable;
- (void)suspendDownloadable:(MGLDownloadable *)downloadable;

@end
