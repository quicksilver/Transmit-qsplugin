//
//  QSTransmitModule_Source.m
//  QSTransmitModule
//
//  Created by Nicholas Jitkoff on 7/12/04.p
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSTransmitModule_Source.h"

#import "Transmit.h"

#define TRANSMIT_ID @"com.panic.Transmit"
#define QSTransmitSiteType @"QSTransmitSiteType"
#define kQSTransmitConnectAction @"QSTransmitConnectAction"

#define kValidURLSchemes [NSArray arrayWithObjects:@"ftp",@"sftp",@"ftps",nil]

// Keys for Favorites metadata

#define kTransmitFavoriteDockSendEnabled @"com_panic_transmit_dockSendEnabled"
#define kTransmitFavoriteNickname @"com_panic_transmit_nickname"
#define kTransmitFavoritePassiveModeEnabled @"com_panic_transmit_passiveModeEnabled"
#define kTransmitFavoritePromptPassword @"com_panic_transmit_promptPassword"
#define kTransmitFavoriteProtocol @"com_panic_transmit_protocol"
#define kTransmitFavoriteServer @"com_panic_transmit_server"
#define kTransmitFavoriteUUID @"com_panic_transmit_uniqueIdentifier"
#define kTransmitFavoriteUserName @"com_panic_transmit_username"

@implementation QSTransmitSource

- (void)dealloc {
    [transmitApp release];
    [super dealloc];
}

- (TransmitApplication *)transmitApp {
    @synchronized (self) {
        if (!transmitApp) {
            transmitApp = [[SBApplication applicationWithBundleIdentifier:TRANSMIT_ID] retain];
            [transmitApp setSendMode:kAEWaitReply];
            [transmitApp setTimeout:60];
        }
    }

    return transmitApp;
}


#pragma mark Object Action Methods

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject {
    BOOL connectToIsValid;
    for (QSObject *eachObject in [dObject splitObjects]) {
    connectToIsValid = NO;
    if ([[eachObject primaryType] isEqualToString:QSTransmitSiteType]) {
        connectToIsValid = YES;
        continue;
    } else if ([eachObject objectForType:QSURLType]) {
        if ([kValidURLSchemes containsObject:[[NSURL URLWithString:[eachObject objectForType:QSURLType]] scheme]]) {
            connectToIsValid = YES;
            continue;
        }
    }
    }
    if (connectToIsValid) {
        return [NSArray arrayWithObject:kQSTransmitConnectAction];
    } else {
        return nil;
    }
}

#pragma mark Object Source Methods

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry {
    return NO;
}

- (void)setQuickIconForObject:(QSObject *)object{
	[object setIcon:[QSResourceManager imageNamed:TRANSMIT_ID]];
}

- (NSImage *)iconForEntry:(NSDictionary *)dict {
    return [QSResourceManager imageNamed:TRANSMIT_ID];
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
	if ([object containsType:QSFilePathType]){
        NSArray *favorites = [QSLib arrayForType:QSTransmitSiteType];
        if (!self.transmitApp && [favorites count]) {
            // If transmit isn't running, and we have the favorites already stored in the QS catalog, use those. Otherwise we have to launch Transmit for SB stuff (ugh)
            [object setChildren:favorites];
        } else {
            [object setChildren:[self objectsForEntry:nil]];
        }
		return YES;
	}
	return NO;
}

- (NSURL *)transmitMetadataURL {
    NSString *metadataPath = [[@"~/Library/Application Support/Transmit/Metadata" stringByExpandingTildeInPath] stringByStandardizingPath];

    return [NSURL fileURLWithPath:metadataPath isDirectory:YES];
}

- (NSArray *)objectsForEntry:(NSDictionary *)theEntry {
    NSError *error = nil;
    NSArray *favorites = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self transmitMetadataURL]
                                                       includingPropertiesForKeys:nil
                                                                          options:NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                                                                            error:&error];

    if (!favorites) {
        NSLog(@"Failed to scan Transmit favorites: %@", error);
        return nil;
    }

	NSMutableArray *objects = [NSMutableArray array];

    [favorites enumerateObjectsUsingBlock:^(NSURL *favoriteURL, NSUInteger idx, BOOL *stop) {
        NSDictionary *favorite = [NSDictionary dictionaryWithContentsOfURL:favoriteURL];
        [objects addObject:[self objectForFavoriteDictionary:favorite]];
    }];

	return objects;
}

- (QSObject *)objectForFavoriteDictionary:(NSDictionary *)favorite {
    NSString *name = favorite[kTransmitFavoriteNickname];
    NSString *address = favorite[kTransmitFavoriteServer];
    NSString *identifier = favorite[kTransmitFavoriteUUID];

    QSObject *newObject = [QSObject objectWithName:name];

    [newObject setObject:identifier forType:QSTransmitSiteType];
    [newObject setObject:address forType:QSURLType];
    [newObject setPrimaryType:QSTransmitSiteType];
    [newObject setObject:TRANSMIT_ID forMeta:@"QSPreferredApplication"];
    [newObject setIdentifier:identifier];

    [newObject setDetails:address];
    return newObject;
}

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)iObject{
    if ([action isEqualToString:@"QSTransmitUploadAction"]) {
        return [self objectsForEntry:nil];
    }
    return nil;
}

-(QSObject *)connectToSite:(QSObject* )dObject {
    return [self connectToSite:dObject shouldMount:NO];
}

-(QSObject *)mountSite:(QSObject* )dObject {
    return [self connectToSite:dObject shouldMount:YES];
}


-(QSObject *)connectToSite:(QSObject* )dObject shouldMount:(BOOL)shouldMount{
    if (!shouldMount) {
        [[self transmitApp] activate];
    }

    for (QSObject *individualObject in [dObject splitObjects]) {
        NSString *uuid = [individualObject objectForType:QSTransmitSiteType];
        if (uuid) {
            TransmitFavorite *theFavorite = [[[self transmitApp] favorites] objectWithID:uuid];
            if (!theFavorite) {
                NSBeep();
                NSLog(@"Unable to locate the favorite for %@", uuid);
            }

            TransmitDocument *newDocument = nil;

            if ([[[self transmitApp] documents] count] == 1 && ![[[[[[[self transmitApp] documents] lastObject] tabs] lastObject] remoteBrowser] remote]) {
                // don't bother creating a new window if an empty one already exists
                newDocument = [[[self transmitApp] documents] lastObject];
            } else {
                newDocument = [[[[[self transmitApp] classForScriptingClass:@"document"] alloc] init] autorelease];
                [[[self transmitApp] documents] addObject:newDocument];
            }
            BOOL res = [[newDocument currentTab] connectTo:theFavorite toAddress:[theFavorite address] asUser:[theFavorite userName] usingPort:[theFavorite port] withInitialPath:[theFavorite remotePath] withPassword:[theFavorite password] withProtocol:[theFavorite protocol] mount:shouldMount];

            if (!res) {
                NSLog(@"Failed to connect to %@", [theFavorite identifier]);
                return nil;
            }
            if (shouldMount) {
                // close the transmit window if we're just mounting it
                [newDocument closeSaving:TransmitSaveOptionsNo savingIn:nil];
            }
        } else if (uuid = [individualObject objectForType:QSURLType]) {
            NSURL *url = [NSURL URLWithString:uuid];
            if (url) {
                [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:TRANSMIT_ID options:0 additionalEventParamDescriptor:nil launchIdentifiers:nil];
                 }
        }
    }
    return nil;
}

-(QSObject *)uploadFiles:(QSObject *)dObject toSite:(QSObject *)iObject{
	//NSLog(@"objects %@ %@",dObject,iObject);

    // incase the user used the comma trick on the 3rd pane
    for (QSObject *individualObject in [iObject splitObjects]) {

        NSString *uuid=[iObject objectForType:QSTransmitSiteType];

        // get the Tranmit favorite
        TransmitFavorite *theFavorite = [[[self transmitApp] favorites] objectWithID:uuid];

        if (!theFavorite) {
            NSBeep();
            NSLog(@"Unable to locate the favorite for %@",iObject);
        }

        TransmitDocument *newDocument = [[[[[self transmitApp] classForScriptingClass:@"document"] alloc] init] autorelease];
        [[[self transmitApp] documents] addObject:newDocument];

        [[newDocument currentTab] connectTo:theFavorite toAddress:[theFavorite address] asUser:[theFavorite userName] usingPort:[theFavorite port] withInitialPath:[theFavorite remotePath] withPassword:[theFavorite password] withProtocol:[theFavorite protocol] mount:NO];

        for (NSString *path in [dObject validPaths]) {
            [[[newDocument currentTab] remoteBrowser] uploadItemAtPath:path to:nil withResumeMode:TransmitResumetypeAsk continueAfterError:YES usingSkipRules:nil];
        }

        [newDocument closeSaving:TransmitSaveOptionsNo savingIn:nil];

    }
	return nil;
}

@end
