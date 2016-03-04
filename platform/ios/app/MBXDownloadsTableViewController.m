#import "MBXDownloadsTableViewController.h"

#import <Mapbox/Mapbox.h>

static NSString * const MBXDownloadContextNameKey = @"Name";

@implementation MGLDownloadable (MBXAdditions)

- (NSString *)name {
    NSDictionary *userInfo = [NSKeyedUnarchiver unarchiveObjectWithData:self.context];
    NSAssert([userInfo isKindOfClass:[NSDictionary class]], @"Context of downloadable isn’t a dictionary.");
    NSString *name = userInfo[MBXDownloadContextNameKey];
    NSAssert([name isKindOfClass:[NSString class]], @"Name of downloadable isn’t a string.");
    return name;
}

@end

@interface MBXDownloadsTableViewController () <MGLDownloadableDelegate>

@property (nonatomic, strong) NS_MUTABLE_ARRAY_OF(MGLDownloadable *) *downloadables;

@end

@implementation MBXDownloadsTableViewController {
    NSUInteger _untitledRegionCount;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak MBXDownloadsTableViewController *weakSelf = self;
    [[MGLDownloadController sharedController] requestDownloadablesWithCompletionHandler:^(NS_ARRAY_OF(MGLDownloadable *) *downloadables, NSError *error) {
        MBXDownloadsTableViewController *strongSelf = weakSelf;
        strongSelf.downloadables = downloadables.mutableCopy;
        [strongSelf.tableView reloadData];
        
        if (error) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Can’t Find Downloads" message:@"Mapbox GL was unable to find the existing downloads." preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:^{
                [strongSelf dismissViewControllerAnimated:YES completion:nil];
            }];
        }
    }];
}

- (IBAction)addCurrentRegion:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Add Download" message:@"Choose a name for the download:" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertAction *downloadAction = [UIAlertAction actionWithTitle:@"Download" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        MGLMapView *mapView = self.mapView;
        NSAssert(mapView, @"No map view to get the current region from.");
        
        NSString *name = alertController.textFields.firstObject.text;
        if (!name.length) {
            name = [NSString stringWithFormat:@"Untitled %lu", (unsigned long)++_untitledRegionCount];
        }
        
        MGLTilePyramidDownloadRegion *region = [[MGLTilePyramidDownloadRegion alloc] initWithStyleURL:mapView.styleURL bounds:mapView.visibleCoordinateBounds fromZoomLevel:mapView.minimumZoomLevel toZoomLevel:mapView.maximumZoomLevel];
        NSData *context = [NSKeyedArchiver archivedDataWithRootObject:@{
            MBXDownloadContextNameKey: name,
        }];
        
        __weak MBXDownloadsTableViewController *weakSelf = self;
        [[MGLDownloadController sharedController] addDownloadableForRegion:region withContext:context completionHandler:^(MGLDownloadable *downloadable, NSError *error) {
            MBXDownloadsTableViewController *strongSelf = weakSelf;
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Mapbox GL was unable to add the download “%@”.", name];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Can’t Add Download" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alertController animated:YES completion:nil];
            } else {
                downloadable.delegate = strongSelf;
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:strongSelf.downloadables.count inSection:0];
                [strongSelf.downloadables addObject:downloadable];
                [strongSelf.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }];
    }];
    [alertController addAction:downloadAction];
    alertController.preferredAction = downloadAction;
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.downloadables.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Download" forIndexPath:indexPath];
    
    MGLDownloadable *downloadable = self.downloadables[indexPath.row];
    cell.textLabel.text = downloadable.name;
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Downloadable delegate

- (void)downloadable:(MGLDownloadable *)downloadable progressDidChange:(MGLDownloadableProgress)progress {
    NSLog(@"Downloadable “%@” reached %f%%.", downloadable.name, round(progress.countOfResourcesCompleted / progress.countOfResourcesExpected * 100));
}

- (void)downloadable:(MGLDownloadable *)downloadable didReceiveError:(NSError *)error {
    NSLog(@"Downloadable “%@” received error: %@", downloadable.name, error.localizedFailureReason);
}

- (void)downloadable:(MGLDownloadable *)downloadable didReceiveMaximumAllowedMapboxTiles:(uint64_t)maximumCount {
    NSLog(@"Downloadable “%@” reached limit of %llu tiles.", downloadable.name, maximumCount);
}

@end
