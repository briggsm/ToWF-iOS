//
//  SeqId.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import "SeqId.h"

@implementation SeqId

- (id)initWithInt:(int)i {
    if (self = [super init])
    {
        if (i < 0) {
            self.intValue = 0xFFFF - (abs(i) & 0xFFFF) + 1;
        } else {
            self.intValue = i & 0xFFFF;
        }
    }
    return self;
}

// Need this for sortUsingDescriptors:
- (NSComparisonResult)compare:(SeqId*)otherSeqId {
    if ([self isLessThanSeqId:otherSeqId]) {
        return NSOrderedAscending;
    } else if ([self isEqualToSeqId:otherSeqId]) {
        return NSOrderedSame;
    } else {
        return NSOrderedDescending;
    }
}


// Need this "isEqual:" and "hash:" for checks for "containsObject:" calls
- (BOOL)isEqual:(id)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:[SeqId class]]) {
        return NO;
    }
    
    return [self isEqualToSeqId:(SeqId*)other];
}
- (NSUInteger)hash {
    return self.intValue;
}


// Note: SeqId is from 0x0000 to 0xFFFF
//  When wrapping around the end, for example, 0xFFFE is "less than" 0x0003
//  We'll make the "cutoff" at about 1/2 way around
-(Boolean)isLessThanSeqId:(SeqId*)otherSeqId {
    if ( (self.intValue < otherSeqId.intValue && otherSeqId.intValue - self.intValue < 0x7FFF) || (self.intValue > otherSeqId.intValue && self.intValue - otherSeqId.intValue >= 0x7FFF ) ) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)isGreaterThanSeqId:(SeqId*)otherSeqId {
    if ( (self.intValue > otherSeqId.intValue && self.intValue - otherSeqId.intValue < 0x7FFF) || (self.intValue < otherSeqId.intValue && otherSeqId.intValue - self.intValue >= 0x7FFF) ) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)isEqualToSeqId:(SeqId*)otherSeqId {
    if (self.intValue == otherSeqId.intValue) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)isLessThanOrEqualToSeqId:(SeqId*)otherSeqId {
    if ([self isLessThanSeqId:otherSeqId] || [self isEqualToSeqId:otherSeqId]) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)isGreaterThanOrEqualToSeqId:(SeqId*)otherSeqId {
    if ([self isGreaterThanSeqId:otherSeqId] || [self isEqualToSeqId:otherSeqId]) {
        return YES;
    } else {
        return NO;
    }
}

-(int)numSeqIdsExclusivelyBetweenMeAndSeqId:(SeqId*)otherSeqId {
    if ([self isEqualToSeqId:otherSeqId]) {
        return 0;
    }
    
    if ([self isGreaterThanSeqId:otherSeqId]) {
        if (self.intValue > otherSeqId.intValue) {
            return self.intValue - otherSeqId.intValue - 1;
        } else {
            return self.intValue + (0xFFFF - otherSeqId.intValue);
        }
    } else {  // isLessThan
        if (self.intValue < otherSeqId.intValue) {
            return otherSeqId.intValue - self.intValue - 1;
        } else {
            return (0xFFFF - self.intValue) + otherSeqId.intValue;
        }
    }
}

@end
