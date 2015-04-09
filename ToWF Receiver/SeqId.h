//
//  SeqId.h
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SeqId : NSObject

//@property (nonatomic, assign) int intValue;
@property (nonatomic, assign) uint16_t intValue;

- (id)initWithInt:(int)i;
- (NSComparisonResult)compare:(SeqId*)otherSeqId;
- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
-(Boolean)isLessThanSeqId:(SeqId*)otherSeqId;
-(Boolean)isGreaterThanSeqId:(SeqId*)otherSeqId;
-(Boolean)isEqualToSeqId:(SeqId*)otherSeqId;
-(Boolean)isLessThanOrEqualToSeqId:(SeqId*)otherSeqId;
-(Boolean)isGreaterThanOrEqualToSeqId:(SeqId*)otherSeqId;
-(int)numSeqIdsExclusivelyBetweenMeAndSeqId:(SeqId*)otherSeqId;
//add???

@end
