#import "MGLDownloadController.h"

#import "MGLDownloadable.h"

@interface MGLDownloadController (Private)

- (void)resumeDownloadable:(MGLDownloadable *)downloadable;
- (void)suspendDownloadable:(MGLDownloadable *)downloadable;
- (void)cancelDownloadable:(MGLDownloadable *)downloadable withCompletionHandler:(MGLDownloadableCancellationCompletionHandler)completion;

@end
