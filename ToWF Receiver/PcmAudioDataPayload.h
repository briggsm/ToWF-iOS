//
//  PcmAudioDataPayload.h
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SeqId.h"

#define ADPL_HEADER_SEQ_ID_START 0
#define ADPL_HEADER_SEQ_ID_LENGTH 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_START 2
#define ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH 2
#define ADPL_HEADER_LENGTH (ADPL_HEADER_SEQ_ID_LENGTH + ADPL_HEADER_AUDIO_DATA_ALLOCATED_BYTES_LENGTH)
#define ADPL_AUDIO_DATA_START ADPL_HEADER_LENGTH

@interface PcmAudioDataPayload : NSObject

@property (nonatomic, strong) SeqId *seqId;
@property (nonatomic, assign) int audioDataAllocatedBytes;
@property (nonatomic, strong) NSData *audioData;

- (id)initWithPayload:(NSData*)payload;
- (id)initWithSeqId:(SeqId*)s;
- (NSComparisonResult)compare:(PcmAudioDataPayload*)otherPayload;
    
@end
