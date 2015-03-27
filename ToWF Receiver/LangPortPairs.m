//
//  LangPortPairs.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 2/16/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import "LangPortPairs.h"

@interface LangPortPairs() {
    NSMutableArray *langPortArr;
}

@end

@implementation LangPortPairs

- (id)init
{
    self = [super init];
    if (self)
    {
        langPortArr = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addPairWithLanguage:(NSString *)lang AndPort:(uint16_t)port {
    // Note: if already exists, nothing happens
    
    NSString *lpPairStr = [NSString stringWithFormat:@"%@::%d", lang, port];
    if ([langPortArr indexOfObject:lpPairStr] == NSNotFound) {
        [langPortArr addObject:lpPairStr];
    }
}


- (Boolean)removePairWithLanguage:(NSString*)lang {
    // Returns YES if a pair was removed. NO if not removed (not found).
    
    for (int ctr = 0; ctr < langPortArr.count; ctr++) {
        NSString *s = langPortArr[ctr];
        NSString *currLang = [s componentsSeparatedByString:@"::"][0];
        
        if ([currLang isEqualToString:lang]) {
            [langPortArr removeObjectAtIndex:ctr];
            return YES;
        }
    }
    return NO;
}

- (void)removeAllPairs {
    [langPortArr removeAllObjects];
}

- (int)getNumPairs {
    return (int)langPortArr.count;
}

- (NSString*)getLanguageAtIdx:(int)idx {
    if (idx < self.getNumPairs) {  // Make sure we don't go out of range
        NSArray *lpArr = [langPortArr[idx] componentsSeparatedByString:@"::"];
        return lpArr[0];
    } else {
        return @"";
    }
}

- (NSString*)toString {
    return [langPortArr componentsJoinedByString:@","];
}

- (uint16_t)getPortForLanguage:(NSString*)lang {
    for (int ctr = 0; ctr < langPortArr.count; ctr++) {
        NSString *s = langPortArr[ctr];
        NSArray *lpArr = [s componentsSeparatedByString:@"::"];
        NSString *currLang = lpArr[0];
        
        if ([currLang isEqualToString:lang]) {

             return (uint16_t)[(NSString*)lpArr[1] integerValue];
        }
    }
    
    return 0;
}

@end
