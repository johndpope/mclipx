//
//  AppDelegate.m
//  mclipx
//
//  Created by Jonathan Featherstone on 7/19/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"
#import "FMDatabase.h"

#import "MASShortcutView.h"
#import "MASShortcutView+UserDefaults.h"
#import "MASShortcut+UserDefaults.h"
#import "MASShortcut+Monitoring.h"

#import "MainWindowController.h"
#import "PreferencesWindowController.h"

NSString *const MASPreferenceKeyShortcut = @"MClipXShortcut";

@implementation AppDelegate {
    NSInteger lastChangeCount;
    NSPasteboard *pboard;
    FMDatabase *db;
    MainWindowController *mainWindow;
    PreferencesWindowController *preferencesWindow;
    
}

@synthesize shortcutView;
@synthesize statusMenu;
@synthesize statusItem;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Init globals
    [self initDB];
    pboard = [NSPasteboard generalPasteboard];
    
    // create tray icon
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"clipboard_16.png"]];
    
    // link up menu action(s)
    [[statusMenu itemWithTitle:@"Preferences"] setAction:@selector(preferences:)];
    [[statusMenu itemWithTitle:@"Quit"] setAction:@selector(terminate:)];
    
    // create main window
    mainWindow = [[MainWindowController alloc] initWithWindowNibName:@"MainWindowController"];
    [mainWindow setDb:db];
    
    // create preferences window
    preferencesWindow = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    
    
    // register shortcut listener
    shortcutView.associatedUserDefaultsKey = MASPreferenceKeyShortcut;
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_V modifierFlags:NSCommandKeyMask|NSShiftKeyMask];
    [MASShortcut addGlobalHotkeyMonitorWithShortcut:shortcut handler:^{
        [self hotkeyHit];
    }];

    // run polling timer for pasteboard changes
    [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(pollPasteboard:) userInfo:nil repeats:YES];
}

- (void)preferences:(id)sender {
    [preferencesWindow showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // cleanup
    [db close];
}

- (void)initDB {
    NSString *homeDirectory = NSHomeDirectory();
    NSString *dbPath = [homeDirectory stringByAppendingPathComponent:@".mclipbx.db"];

    db = [FMDatabase databaseWithPath:dbPath];
    [db open];

    FMResultSet *s = [db executeQuery:@"SELECT name \
                      FROM sqlite_master \
                      WHERE type='table' \
                      AND name='pasteboard';"];
    if (![s next]){
        [db executeStatements:@"CREATE TABLE pasteboard( \
         id INTEGER PRIMARY KEY AUTOINCREMENT, \
         inferred_type VARCHAR(255), \
         pasteboard_text text, \
         pasteboard_change_count INTEGER, \
         timestamp DATETIME DEFAULT CURRENT_TIMESTAMP \
         );"];
        lastChangeCount = 0;
    } else {
        s = [db executeQuery:@"SELECT pasteboard_change_count \
             FROM pasteboard \
             ORDER BY ID DESC \
             LIMIT 1"];
        [s next];
        lastChangeCount = [s intForColumn:@"pasteboard_change_count"];
    }
}

- (void)pollPasteboard:(NSTimer *)timer {
    NSInteger currentChangeCount = [pboard changeCount];
    
    if (currentChangeCount != lastChangeCount){
        lastChangeCount = currentChangeCount;

        // check if excluded application
        NSArray *exclusionApps = [[NSUserDefaults standardUserDefaults] arrayForKey:@"ExclusionApps"];
        NSString *currentActiveApp = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationName"];
        if (![exclusionApps containsObject:currentActiveApp]){

            // check if blank string or whitespace only
            NSString* pasteboardText = [pboard stringForType:NSPasteboardTypeString];
            NSString* trimmedPasteboardText = [pasteboardText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([trimmedPasteboardText length] > 0) {
                [self pasteboardChanged: pasteboardText changeCount:currentChangeCount];
            }
        }
    }
}

- (void)pasteboardChanged:(NSString *)pasteboardText changeCount:(NSInteger) changeCount {
    // create record in db
    // TODO: infer type
    NSString *inferredType = @"Text";
    NSString* sChangeCount = [NSString stringWithFormat:@"%ld", (long)changeCount];
    NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:pasteboardText, @"pasteboard_text", inferredType, @"inferred_type", sChangeCount, @"pasteboard_change_count", nil];
    [db executeUpdate:@"INSERT INTO pasteboard(inferred_type,pasteboard_text,pasteboard_change_count) \
                        VALUES(:inferred_type,:pasteboard_text,:pasteboard_change_count);" withParameterDictionary:argsDict];
}

- (void)hotkeyHit {
    NSRunningApplication *focusVictim = [[NSWorkspace sharedWorkspace] frontmostApplication];
    
    [mainWindow setFocusVictim:focusVictim];
    [NSApp activateIgnoringOtherApps:YES];
    [mainWindow.window setLevel:NSStatusWindowLevel];
    [mainWindow showWindow:self];
    [mainWindow focusSearchWithCharacters:@""];
}

@end
