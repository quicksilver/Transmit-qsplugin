//
//  QSTransmitModule_Source.m
//  QSTransmitModule
//
//  Created by Nicholas Jitkoff on 7/12/04.p
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "QSTransmitModule_Source.h"

#define TRANSMIT_ID @"com.panic.Transmit"
#define QSTransmitSiteType @"QSTransmitSiteType"
#define kQSTransmitConnectAction @"QSTransmitConnectAction"

#define kValidURLSchemes [NSArray arrayWithObjects:@"ftp",@"sftp",@"ftps",nil]


//NSURLPboardType
@implementation QSTransmitSource

-(id)init {
    if (self = [super init]) {
        transmit = [[SBApplication applicationWithBundleIdentifier:@"com.panic.Transmit"] retain];
    }
    return self;
}

-(void)dealloc {
    [transmit release];
    [super dealloc];
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

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry{
    // unconditionally scan if Transmit is running, otherwise don't scan. Scanning requires Transmit to be launched; we don't want to inadvertantly start Transmit every time a catalog scan is performed
    return ![transmit isRunning];
}

- (void)setQuickIconForObject:(QSObject *)object{
	[object setIcon:[QSResourceManager imageNamed:@"com.panic.Transmit"]];	
}

- (NSImage *) iconForEntry:(NSDictionary *)dict {
    return [QSResourceManager imageNamed:TRANSMIT_ID];
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
	if ([object containsType:QSFilePathType]){
        NSArray *favorites = [QSLib arrayForType:QSTransmitSiteType];
        if (![transmit isRunning] && [favorites count]) {
            // If transmit isn't running, and we have the favorites already stored in the QS catalog, use those. Otherwise we have to launch Transmit for SB stuff (ugh)
            [object setChildren:favorites];
        } else {
            [object setChildren:[self objectsForEntry:nil]];
        }
		return YES;
	}
	return NO;
}


- (NSArray *) objectsForEntry:(NSDictionary *)theEntry{
	
	NSMutableArray *objects=[NSMutableArray array];
    
    [[transmit favorites] enumerateObjectsUsingBlock:^(TransmitFavorite *favorite, NSUInteger idx, BOOL *stop) {
        [objects addObject:[self objectForFavorite:favorite]];
    }];
	return objects;
}


- (QSObject *)objectForFavorite:(TransmitFavorite *)favorite {
	NSString *name=[favorite name];
    QSObject *newObject=[QSObject objectWithName:name];

    [newObject setObject:[favorite identifier] forType:QSTransmitSiteType];
    [newObject setObject:[favorite address] forType:QSURLType];
    [newObject setPrimaryType:QSTransmitSiteType];
    [newObject setObject:TRANSMIT_ID forMeta:@"QSPreferredApplication"];
    [newObject setIdentifier:[favorite identifier]];
    
    [newObject setDetails:[favorite address]];
    return newObject;
}


// Object Handler Methods

/*
 - (void)setQuickIconForObject:(QSObject *)object{
	 [object setIcon:nil]; // An icon that is either already in memory or easy to load
 }
 - (BOOL)loadIconForObject:(QSObject *)object{
	 return NO;
	 id data=[object objectForType:QSTransmitModuleType];
	 [object setIcon:nil];
	 return YES;
 }
 */






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
        [transmit activate];
    }
    
    for (QSObject *individualObject in [dObject splitObjects]) {
        NSString *uuid = [individualObject objectForType:QSTransmitSiteType];
        if (uuid) {
            TransmitFavorite *theFavorite = [[transmit favorites] objectWithID:uuid];
            TransmitDocument *newDocument = [[[[transmit classForScriptingClass:@"document"] alloc] init] autorelease];
            [[transmit documents] addObject:newDocument];
            [[newDocument currentTab] connectTo:theFavorite toAddress:[theFavorite address] asUser:[theFavorite userName] usingPort:[theFavorite port] withInitialPath:[theFavorite remotePath] withPassword:[theFavorite password] withProtocol:[theFavorite protocol] mount:shouldMount];
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
        TransmitFavorite *theFavorite = [[transmit favorites] objectWithID:uuid];

        if (!theFavorite) {
            NSBeep();
            NSLog(@"Unable to locate the favorite for %@",iObject);
        }
        
        TransmitDocument *newDocument = [[[[transmit classForScriptingClass:@"document"] alloc] init] autorelease];
        [[transmit documents] addObject:newDocument];
        
        [[newDocument currentTab] connectTo:theFavorite toAddress:[theFavorite address] asUser:[theFavorite userName] usingPort:[theFavorite port] withInitialPath:[theFavorite remotePath] withPassword:[theFavorite password] withProtocol:[theFavorite protocol] mount:NO];
        
        for (NSString *path in [dObject validPaths]) {
            [[[newDocument currentTab] remoteBrowser] uploadItemAtPath:path to:nil withResumeMode:TransmitResumetypeAsk continueAfterError:YES usingSkipRules:nil];
        }
        
        [newDocument closeSaving:TransmitSaveOptionsNo savingIn:nil];
        
    }
	return nil;	
}

@end
