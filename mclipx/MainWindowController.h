//
//  MainWindowController.h
//  mclipx
//
//  Created by Jonathan Featherstone on 8/8/14.
//  Copyright (c) 2014 Jonathan Featherstone. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindowController : NSWindowController
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *searchField;

@end