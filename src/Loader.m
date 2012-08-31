#import "Loader.h"
#import "FavoriteCollection.h"
#import "Favorite.h"

@implementation Loader

- (IBAction)loadFavorites:(id)sender
{
	NSString *prefsPath = [@"~/Library/Preferences/com.panic.Transmit.plist" stringByExpandingTildeInPath];
	NSDictionary *prefsDict = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
	
	if ( prefsDict )
	{
		NSData *storedData = [prefsDict objectForKey:@"Collections2"];
		
		if ( storedData )
		{
			// The logging code below makes the assumption that all top level items are folders.
			
			FavoriteCollection *rootCollection = [NSKeyedUnarchiver unarchiveObjectWithData:storedData];
			NSEnumerator *enumerator = [[rootCollection allObjects] objectEnumerator];
			FavoriteCollection *curCollection;
			
			NSLog(@"Loaded favorites");
			
			while ( (curCollection = [enumerator nextObject]) != nil )
			{				
				NSEnumerator *subEnumerator = [[curCollection allObjects] objectEnumerator];
				Favorite *curFavorite;
				
				while ( (curFavorite = [subEnumerator nextObject]) != nil )
				{
					// call:
						//localPathShortcuts
						//remotePathShortcuts
					
					NSLog(@"\t%@", [curFavorite nickname]);
				}
			}
		}
	}
}

@end
