//
//  MissingPayloadStorageList.h
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/3/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PcmAudioDataPayload.h"

@interface PayloadStorageList : NSObject

- (id)init;

-(void)addIncrementingMissingPayloads:(NSArray*)incrMissingPayloadsList;
-(void)addFullPayload:(PcmAudioDataPayload*)payload;
-(Boolean)hasPayloadAnywhereWithThisSeqId:(SeqId*)seqId;
-(Boolean)hasMissingPayloadAtFirstElement;
-(Boolean)hasMissingPayloadAtFirstElementWithThisSeqId:(SeqId*)seqId;
-(Boolean)hasMissingPayloadAnywhereWithThisSeqId:(SeqId*)seqId;
-(Boolean)hasFullPayloadAtFirstElement;
//-(Boolean)hasFullPayloadAtFirstElementWithThisSeqId:(SeqId*)seqId;
-(Boolean)hasFullPayloadAnywhereWithThisSeqId:(SeqId*)seqId;
-(PcmAudioDataPayload*)getFirstPayload;
-(PcmAudioDataPayload*)popFirstPayload;
-(void)removeAllPayloads;
-(Boolean)replaceMissingPayloadWithFullPayload:(PcmAudioDataPayload*)fullPayload;
//-(NSString*)toString;
-(NSString*)getMissingPayloadsSeqIdsAsHexString;
-(NSString*)getAllPayloadsSeqIdsAsHexString;
-(int)getTotalNumPayloads;
//-(int)getNumMissingPayloads;
//-(int)getNumFullPayloads;
-(NSArray*)getMissingPayloads;
-(void)removeMissingPayloadsInFirstXPayloads:(int)numPayloadsToRemove;



@end
