//
//  QSTransmitModule_Source.m
//  QSTransmitModule
//
//  Created by Nicholas Jitkoff on 7/12/04.p
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//

#import "src/FavoriteCollection.h"
#import "src/Favorite.h"

#import "QSTransmitModule_Source.h"

#define TRANSMIT_ID @"com.panic.Transmit"
#define QSTransmitSiteType @"QSTransmitSiteType"
#define kQSTransmitConnectAction @"QSTransmitConnectAction"

#define kValidURLSchemes [NSArray arrayWithObjects:@"ftp",@"sftp",@"ftps",nil]


@implementation FavoriteCollection (BLTRConvenience)
+ (FavoriteCollection *)mainCollection{
	NSString *prefsPath = [@"~/Library/Preferences/com.panic.Transmit.plist" stringByExpandingTildeInPath];
	NSDictionary *prefsDict = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
	if ( prefsDict )
	{
		NSData *storedData = [prefsDict objectForKey:@"FavoriteCollections"];
		if ( storedData )
		{		
			return [NSKeyedUnarchiver unarchiveObjectWithData:storedData];
		}
	}
	return nil;
}

@end

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
	NSDate *modDate=[[[NSFileManager defaultManager] attributesOfItemAtPath:[@"~/Library/Preferences/com.panic.Transmit.plist" stringByStandardizingPath] error:nil]fileModificationDate];
	return [modDate compare:indexDate]==NSOrderedAscending;
}

- (void)setQuickIconForObject:(QSObject *)object{
	[object setIcon:[QSResourceManager imageNamed:@"com.panic.Transmit"]];	
}

- (NSImage *) iconForEntry:(NSDictionary *)dict {
    return [QSResourceManager imageNamed:TRANSMIT_ID];
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
	if ([object containsType:QSFilePathType]){
		[object setChildren:[self objectsForEntry:nil]];
		return YES;   	
	} else {
		if([object objectForMeta:@"QSObjectSubpath"])return NO;
		NSString *uuid=[object objectForType:QSTransmitSiteType];
			Favorite *fav=[[FavoriteCollection mainCollection]itemWithUUID:uuid];
		NSArray *paths=[fav remotePathShortcuts];
		//NSLog(@"path %@ %@ %@",uuid,[FavoriteCollection mainCollection],paths);
		NSMutableArray *objects=[NSMutableArray array];
		for(NSString * path in paths){
			QSObject *newObject=[self objectForFavorite:fav subpath:path];
			[objects addObject:newObject];
		}
		[object setChildren:objects];
		return YES;
	}
	return NO;
}

//- (NSString *)identifierForObject:(id <QSObject>)object{
//   return [@"[Sherlock Channel]:"stringByAppendingString:[object objectForType:QSSherlockChannelIDType]];
//}


- (NSArray *) objectsForEntry:(NSDictionary *)theEntry{
	
	NSMutableArray *objects=[NSMutableArray arrayWithCapacity:1];
	QSObject *newObject;
	
	{
		FavoriteCollection *rootCollection=[FavoriteCollection mainCollection];
		NSEnumerator *enumerator = [[rootCollection allObjects] objectEnumerator];
		FavoriteCollection *curCollection;
		
		//NSLog(@"Loaded favorites");
		
		while ( (curCollection = [enumerator nextObject]) != nil )
		{
			//	NSLog([curCollection name]);
			
			NSEnumerator *subEnumerator = [[curCollection allObjects] objectEnumerator];
			Favorite *curFavorite;
			if ([curCollection type]!=kFolderType) continue;
			
			while ( (curFavorite = [subEnumerator nextObject]) != nil )
			{
				
				newObject=[self objectForFavorite:curFavorite subpath:nil];
				[objects addObject:newObject];
				
				
				//NSLog(@"\t%@", [curFavorite nickname]);
			}
		}
	}
	
	return objects;
}


- (QSObject *)objectForFavorite:(Favorite *)curFavorite subpath:(NSString *)subpath{
	NSString *url=[self URLForFavorite:curFavorite subpath:subpath];
	NSString *name=[curFavorite nickname];
	if (subpath)name=[name stringByAppendingFormat:@" - %@",[subpath lastPathComponent]];
	QSObject *newObject=[QSObject objectWithName:name];
				//NSString *url=[self URLForNewTransmitDict:dict];
				
				[newObject setObject:[curFavorite UUID] forType:QSTransmitSiteType];
				[newObject setObject:url forType:QSURLType];
				[newObject setPrimaryType:QSTransmitSiteType];
				[newObject setObject:TRANSMIT_ID forMeta:@"QSPreferredApplication"];
				[newObject setObject:subpath forMeta:@"QSObjectSubpath"];
				[newObject setIdentifier:[curFavorite UUID]];
				
				[newObject setDetails:subpath?subpath:[url stringByReplacing:@":PasswordInKeychain" with:@""]];
				return newObject;
}


/*
 tell application "Transmit"
	run
	set theDocument to make new document
	ignoring application responses
 connect (theDocument) to "macsavants.com" as user "nicholas" with password "PasswordInKeychain" with connection type FTP
 activate
	end ignoring
 end tell
 
 */

- (NSString *)URLForTransmitDict:(NSDictionary *)dict{
	NSString *initialPath=[dict objectForKey:@"InitialPath"];
	NSString *protocol=[dict objectForKey:@"Protocol"];
	NSString *remoteHost=[dict objectForKey:@"RemoteHost"];
	NSString *remotePassword=[dict objectForKey:@"RemotePassword"];
	NSString *remotePort=[dict objectForKey:@"RemotePort"];
	NSString *remoteUser=[dict objectForKey:@"RemoteUser"];
	
	//	if ([remotePassword isEqualToString:@"PasswordInKeychain"])remotePassword=@"";
	
	NSString *authent=nil;
	if ([remoteUser length]){
		if ([remotePassword length]) authent=[NSString stringWithFormat:@"%@:%@",[remoteUser stringByReplacing:@"@" with:@"%40"],remotePassword];
		else authent=remoteUser;
	}
	
	NSString *string=[NSString stringWithFormat:@"%@://%@%@%@%@",
		[protocol lowercaseString],
		([authent length]?[authent stringByAppendingString:@"@"]:@""),
		remoteHost,
		(remotePort?[@":" stringByAppendingString:remotePort]:@""),
		([initialPath length]?[@"/" stringByAppendingString:initialPath]:@"")
		];
	
	return string;
}
- (NSString *)URLForFavorite:(Favorite *)fav subpath:(NSString *)subpath{
	NSString *initialPath=subpath?subpath:[fav initialRemotePath];
	if (initialPath && ![initialPath hasPrefix:@"/"]) {
		initialPath=[@"/" stringByAppendingString:initialPath];
	}
	NSString *protocol=[fav protocol];
	NSString *remoteHost=[fav server];
	NSString *remotePassword=nil;
	NSString *remotePort=[fav port]?[NSString stringWithFormat:@"%d",[fav port]]:nil;
	NSString *remoteUser=[fav username];
	BOOL prompt=[fav promptForPassword];
	if (!prompt)
		remotePassword=@"PasswordInKeychain";
	
	//	if ([remotePassword isEqualToString:@"PasswordInKeychain"])remotePassword=@"";
	
	NSString *authent=nil;
	if ([remoteUser length]){
		if ([remotePassword length]) authent=[NSString stringWithFormat:@"%@:%@",[remoteUser stringByReplacing:@"@" with:@"%40"],remotePassword];
		else authent=remoteUser;
	}
	
	NSString *string=[NSString stringWithFormat:@"%@://%@%@%@%@",
		[protocol lowercaseString],
		([authent length]?[authent stringByAppendingString:@"@"]:@""),
		remoteHost,
		(remotePort?[@":" stringByAppendingString:remotePort]:@""),
		([initialPath length]?[initialPath URLEncoding]:@"")
		];
	
	return string;
}



- (NSString *)URLForNewTransmitDict:(NSDictionary *)dict{
	NSString *initialPath=[dict objectForKey:@"com_panic_transmit_remotePath"];
	NSString *protocol=[dict objectForKey:@"com_panic_transmit_protocol"];
	NSString *remoteHost=[dict objectForKey:@"com_panic_transmit_server"];
	NSString *remotePassword=nil; //[dict objectForKey:@"RemotePassword"];
	BOOL prompt=[[dict objectForKey:@"com_panic_transmit_promptPassword"]boolValue];
	if (!prompt)
		remotePassword=@"PasswordInKeychain";
	NSString *remotePort=[dict objectForKey:@"com_panic_transmit_port"];
	NSString *remoteUser=[dict objectForKey:@"com_panic_transmit_username"];
	
	//	if ([remotePassword isEqualToString:@"PasswordInKeychain"])remotePassword=@"";
	
	NSString *authent=nil;
	if ([remoteUser length]){
		if ([remotePassword length]) authent=[NSString stringWithFormat:@"%@:%@",[remoteUser stringByReplacing:@"@" with:@"%40"],remotePassword];
		else authent=remoteUser;
	}
	
	NSString *string=[NSString stringWithFormat:@"%@://%@%@%@%@",
		[protocol lowercaseString],
		([authent length]?[authent stringByAppendingString:@"@"]:@""),
		remoteHost,
		(remotePort?remotePort:@""),
		([initialPath length]?[@"/" stringByAppendingString:initialPath]:@"")
		];
	
	return string;
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
