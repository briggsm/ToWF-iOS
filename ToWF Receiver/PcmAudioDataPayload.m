//
//  PcmAudioDataPayload.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import "PcmAudioDataPayload.h"
#import "Util.h"
#import "SeqId.h"

// Audio Data Payload Constants
/*
#define ADPL_HEADER_SEQ_ID_START 0
#define ADPL_HEADER_SEQ_ID_LENGTH 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH 2
#define ADPL_HEADER_LENGTH ADPL_HEADER_SEQ_ID_LENGTH + ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH
#define ADPL_AUDIO_DATA_START ADPL_HEADER_LENGTH
*/

@interface PcmAudioDataPayload() {

}

@end

@implementation PcmAudioDataPayload

- (id)initWithPayload:(NSData*)payload {
    if (self = [super init]) {
        self.seqId = [[SeqId alloc] initWithInt:[Util getUInt16FromData:payload AtOffset:ADPL_HEADER_SEQ_ID_START BigEndian:NO]];
        self.audioDataAllocatedBytes = [Util getUInt16FromData:payload AtOffset:ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START BigEndian:NO];
        self.audioData = [payload subdataWithRange:NSMakeRange(ADPL_AUDIO_DATA_START, self.audioDataAllocatedBytes)];
    }
    return self;
}
- (id)initWithSeqId:(SeqId*)s {
    // Note: creating this "constructor" so we can "compare" PcmAudioDataPayload's, and to compare them, we just check the SeqId of each.
    if (self = [super init]) {
        self.seqId = s;
        self.audioDataAllocatedBytes = 0;
        self.audioData = nil;
    }
    return self;
}

/*
- (id)initWithDgData:(NSData*)dgData {
    if (self = [super init]) {
        
    }
    return self;
}
*/

// Need this for sortUsingDescriptors:
- (NSComparisonResult)compare:(PcmAudioDataPayload*)otherPayload {
    //if (self.seqId.intValue < otherPayload.seqId.intValue) {
    if ([self.seqId isLessThanSeqId:otherPayload.seqId]) {
        return NSOrderedAscending;
    //} else if (self.seqId.intValue == otherPayload.seqId.intValue) {
    } else if ([self.seqId isEqualToSeqId:otherPayload.seqId]) {
        return NSOrderedSame;
    } else {
        return NSOrderedDescending;
    }
}


// Need this ("isEqual:" and "hash:") for checks for "containsObject:" calls
- (BOOL)isEqual:(id)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:[PcmAudioDataPayload class]]) {
        return NO;
    }
    
    return [self isEqualToPcmAudioDataPayload:(PcmAudioDataPayload*)other];
}
- (NSUInteger)hash {
    return [self.seqId hash];
}


-(Boolean)isEqualToPcmAudioDataPayload:(PcmAudioDataPayload*)otherPcmAudioDataPayload {
    // Just check that the SeqId's are equal. That's enough.
    if ([self.seqId isEqualToSeqId:otherPcmAudioDataPayload.seqId]) {
        return YES;
    } else {
        return NO;
    }
}



@end
