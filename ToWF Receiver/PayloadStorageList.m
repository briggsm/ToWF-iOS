//
//  MissingPayloadStorageList.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/3/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import "PayloadStorageList.h"
#import "SeqId.h"
#import "PcmAudioDataPayload.h"

@interface PayloadStorageList ()
{
    //// This variable contains both: full payloads (PcmAudioDataPayload) &
    ////                              missing payloads SeqId's (SeqId)
    
    // Stores PcmAudioDataPayload's, but some are "full payloads" and some are "missing payloads" (missing => have no audiodata, ie. audioData == nil)
    NSMutableArray *payloadStorageList;  // Must always be sorted.
}
@end


@implementation PayloadStorageList

- (id)init {
    if (self = [super init])
    {
        payloadStorageList = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)addIncrementingMissingPayloads:(NSArray*)incrMissingPayloadsList {
    // missingPayloadsList must have Incrementing seqId's
    
    if (incrMissingPayloadsList.count == 0) {
        return;
    }
    
    Boolean listChanged = false;
    if (payloadStorageList.count == 0) {
        // Add them all right now.
        [payloadStorageList addObjectsFromArray:incrMissingPayloadsList];
        listChanged = false;  // Technically, the list DID change, but setting to false, because we don't need to sort the array since incrMissingPayloadsList is already in Incrementing order.
    } else if ( [((PcmAudioDataPayload*)incrMissingPayloadsList[0]).seqId isGreaterThanSeqId:((PcmAudioDataPayload*)payloadStorageList[payloadStorageList.count - 1]).seqId] ) {
        // Add them all right now.
        [payloadStorageList addObjectsFromArray:incrMissingPayloadsList];
        listChanged = false;  // Technically, the list DID change, but setting to false, because we don't need to sort the array since incrMissingPayloadsList is already in Incrementing order.
    } else {
        // Add each 1 at a time (if not already there)
        for (int i = 0; i < incrMissingPayloadsList.count; i++) {
            if (![self hasPayloadAnywhereWithThisSeqId:((PcmAudioDataPayload*)incrMissingPayloadsList[i]).seqId]) {
                [payloadStorageList addObject:incrMissingPayloadsList[i]];
                listChanged = true;
            }
        }
    }
    
    // Sort (if list has more than 1 element && listChanged)
    if (payloadStorageList.count > 1 && listChanged) {
        [payloadStorageList sortUsingSelector:@selector(compare:)];
    }
}

-(void)addFullPayload:(PcmAudioDataPayload*)payload {
    if (![self hasFullPayloadAnywhereWithThisSeqId:payload.seqId]) {
        if (![self hasMissingPayloadAnywhereWithThisSeqId:payload.seqId]) {
            [payloadStorageList addObject:payload];
            [payloadStorageList sortUsingSelector:@selector(compare:)];
        } else {
            // Replace the missing one.
            [self replaceMissingPayloadWithFullPayload:payload];
        }
    }
}

-(Boolean)hasPayloadAnywhereWithThisSeqId:(SeqId*)seqId {
    // Missing OR Full
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( [((PcmAudioDataPayload*)payloadStorageList[i]).seqId isEqualToSeqId:seqId] ) {
            return YES;
        }
    }
    return NO;
}

-(Boolean)hasMissingPayloadAtFirstElement {
    //return ![self hasFullPayloadAtFirstElement];
    if ( payloadStorageList.count > 0 && ((PcmAudioDataPayload*)payloadStorageList[0]).audioData == nil ) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)hasMissingPayloadAtFirstElementWithThisSeqId:(SeqId*)seqId {
    if ( [self hasMissingPayloadAtFirstElement] && [((PcmAudioDataPayload*)payloadStorageList[0]).seqId isEqualToSeqId:seqId] ) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)hasMissingPayloadAnywhereWithThisSeqId:(SeqId*)seqId {
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil && [((PcmAudioDataPayload*)payloadStorageList[i]).seqId isEqualToSeqId:seqId] ) {
            return YES;
        }
    }
    return NO;
}

-(Boolean)hasFullPayloadAnywhereWithThisSeqId:(SeqId*)seqId {
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData != nil && [((PcmAudioDataPayload*)payloadStorageList[i]).seqId isEqualToSeqId:seqId] ) {
            return YES;
        }
    }
    return NO;
}

-(Boolean)hasFullPayloadAtFirstElement {
    if ( payloadStorageList.count > 0 && ((PcmAudioDataPayload*)payloadStorageList[0]).audioData != nil ) {
        return YES;
    } else {
        return NO;
    }
}

-(Boolean)hasFullPayloadAtFirstElementWithThisSeqId:(SeqId*)seqId {
    if ( [self hasFullPayloadAtFirstElement] && [((PcmAudioDataPayload*)payloadStorageList[0]).seqId isEqualToSeqId:seqId] ) {
        return YES;
    } else {
        return NO;
    }
}

-(PcmAudioDataPayload*)getFirstPayload {
    if (payloadStorageList.count > 0) {
        return payloadStorageList[0];
    }
    return nil;
}

-(PcmAudioDataPayload*)popFirstPayload {
    if (payloadStorageList.count > 0) {
        PcmAudioDataPayload *firstPayload = payloadStorageList[0];
        [payloadStorageList removeObjectAtIndex:0];
        return firstPayload;
    }
    return nil;
}

-(void)removeAllPayloads {
    [payloadStorageList removeAllObjects];
}
        
-(Boolean)replaceMissingPayloadWithFullPayload:(PcmAudioDataPayload*)fullPayload {
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil && [((PcmAudioDataPayload*)payloadStorageList[i]).seqId isEqualToSeqId:fullPayload.seqId] ) {
            payloadStorageList[i] = fullPayload;
            return YES;
        }
    }
    return NO;
}

-(NSString*)toString {
    if (payloadStorageList.count <= 0) {
        return @"";
    }
    
    NSMutableString *s = [[NSMutableString alloc] init];
    for (int i = 0; i < payloadStorageList.count; i++) {
        NSString *fmStr = ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil ? @"M" : @"F";  // M=>Missing F=>Full
        [s appendString:[NSString stringWithFormat:@"0x%04x(%@), ", ((PcmAudioDataPayload*)payloadStorageList[i]).seqId.intValue, fmStr]];
    }
    return s;
}

-(NSString*)getMissingPayloadsSeqIdsAsHexString {
    NSMutableString *s = [[NSMutableString alloc] init];
    NSArray *missingPayloads = [self getMissingPayloads];
    for (int i = 0; i < missingPayloads.count; i++) {
        [s appendString:[NSString stringWithFormat:@"0x%04x, ", ((PcmAudioDataPayload*)missingPayloads[i]).seqId.intValue]];
    }
    return s;
}

-(NSString*)getAllPayloadsSeqIdsAsHexString {
    NSMutableString *s = [[NSMutableString alloc] init];
    for (int i = 0; i < payloadStorageList.count; i++) {
        [s appendString:[NSString stringWithFormat:@"0x%04x", ((PcmAudioDataPayload*)payloadStorageList[i]).seqId.intValue]];
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil ) {
            [s appendString:@"{M}, "];
        } else {
            [s appendString:@"{F}, "];
        }
    }
    return s;
}

-(int)getTotalNumPayloads {
    return (int)payloadStorageList.count;
}

-(int)getNumMissingPayloads {
    int num = 0;
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil ) {
            num++;
        }
    }
    return num;
}

-(int)getNumFullPayloads {
    int num = 0;
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData != nil ) {
            num++;
        }
    }
    return num;
}


-(NSArray*)getMissingPayloads {
    NSMutableArray *missingPayloads = [[NSMutableArray alloc] init];
    for (int i = 0; i < payloadStorageList.count; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil ) {
            [missingPayloads addObject:payloadStorageList[i]];
        }
    }
    return missingPayloads;
}

-(void)removeMissingPayloadsInFirstXPayloads:(int)numPayloadsToRemove {
    // First iterate through list to find index's of the ones which need to be removed
    NSMutableArray *payloadsToRemove = [NSMutableArray array];
    for (int i = 0; i < numPayloadsToRemove; i++) {
        if ( ((PcmAudioDataPayload*)payloadStorageList[i]).audioData == nil ) {
            [payloadsToRemove addObject:payloadStorageList[i]];
        }
    }
    
    // Now remove them
    [payloadStorageList removeObjectsInArray:payloadsToRemove];
}

@end
