//
//  QSTransmitModule_Source.h
//  QSTransmitModule
//
//  Created by Nicholas Jitkoff on 7/12/04.
//  Copyright __MyCompanyName__ 2004. All rights reserved.
//


#import "QSTransmitModule_Source.h"
#import "Transmit.h"

@interface QSTransmitSource : QSObjectSource
{
    TransmitApplication *transmit;
}

- (QSObject *)objectForFavorite:(TransmitFavorite *)favorite;

@end
