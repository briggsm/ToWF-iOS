//
//  LangPortPairs.h
//  ToWF Receiver
//
//  Created by Mark Briggs on 2/16/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LangPortPairs : NSObject

- (void)addPairWithLanguage:(NSString *)lang AndPort:(uint16_t)port;
- (Boolean)removePairWithLanguage:(NSString*)lang;
- (void)removeAllPairs;
- (int)getNumPairs;
- (NSString*)getLanguageAtIdx:(int)idx;
- (uint16_t)getPortForLanguage:(NSString*)lang;
- (NSString*)toString;

@end
