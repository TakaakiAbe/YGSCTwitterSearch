//
//  UITableView+ScrollableToBottom.m
//  TwitterSearch
//
//  Created by Takaaki Abe on 2015/05/02.
//
//

#import "UITableView+ScrollableToBottom.h"

@implementation UITableView (ScrollableToBottom)

- (void)scrollToBottomAnimated:(BOOL)animated
{
    NSInteger sectionCount;
    if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
        sectionCount = [self.dataSource numberOfSectionsInTableView:self];
        if (sectionCount == 0) {
            return;
        }
    } else {
        sectionCount = 1;
    }
    
    NSInteger rowCount = [self.dataSource tableView:self numberOfRowsInSection:(sectionCount - 1)];
    if (rowCount == 0) {
        return;
    }
    
    NSIndexPath *lastRowPath = [NSIndexPath indexPathForRow:rowCount - 1
                                                  inSection:sectionCount - 1];
    
    [self scrollToRowAtIndexPath:lastRowPath atScrollPosition:UITableViewScrollPositionTop animated:animated];
}

@end
