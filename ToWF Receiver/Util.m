//
//  Util.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import "Util.h"

@implementation Util

+(uint32_t) getUInt32FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian {
    // Assumes bytes are in Little Endian order
    uint32_t length = sizeof(uint32_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];
    
    if (bigEndian) {
        return CFSwapInt32BigToHost(*(uint32_t*)(tempBA));
    } else {
        return CFSwapInt32LittleToHost(*(uint32_t*)(tempBA));
    }
}

+(uint16_t) getUInt16FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian {
    // Assumes bytes are in Little Endian order
    uint32_t length = sizeof(uint16_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];
    
    if (bigEndian) {
        return CFSwapInt16BigToHost(*(uint16_t*)(tempBA));
    } else {
        return CFSwapInt16LittleToHost(*(uint16_t*)(tempBA));
    }
    
}

+(uint8_t) getUInt8FromData:(NSData*)data AtOffset:(uint32_t)offset {
    uint32_t length = sizeof(uint8_t);
    uint8_t tempBA[length];
    [data getBytes:tempBA range:NSMakeRange(offset, length)];
    
    return tempBA[0];
}

+(void) appendInt:(int)i OfLength:(uint8_t)length ToData:(NSMutableData*)data BigEndian:(Boolean)bigEndian {
    // length is # of Bytes
    uint8_t b[length];
    
    // Check for possible data loss & warn user if so
    if (i > pow(2, length * 8)) {
        NSLog(@"*WARNING! Full int will not fit inside byte array! Data lost! i: %d, length: %d", i, length);
    }
    
    for (int ctr = 0; ctr < length; ctr++) {
        int pos = bigEndian ? length - 1 - ctr : ctr;  // e.g. bigEndian=>3,2,1,0 littleEndian=0,1,2,3
        b[pos] = (uint8_t) ((i & (0xFF << (8 * ctr))) >> (8 * ctr));  // e.g. 1st time thru loop => i & 0xFF, 2nd time => i & 0xFF00, etc., then shift back to right same amt.
    }
    
    [data appendBytes:b length:length];
}

+(void) appendNullTermString:(NSString*)str ToData:(NSMutableData*)data MaxLength:(int)maxLength {
    int length = MIN((int)str.length, maxLength);
    int i, j;
    uint8_t b[maxLength];
    
    for (i = 0; i < length; i++) {
        b[i] = [str characterAtIndex:i];
        [self appendInt:b[i] OfLength:1 ToData:data BigEndian:NO];
    }
    
    // Null-terminte it & fill rest with 0's, if there's room.
    for (j = i; j < maxLength; j++) {
        b[j] = 0x00;
        [self appendInt:b[j] OfLength:1 ToData:data BigEndian:NO];
    }
}

+(NSString*) getNullTermStringFromData:(NSData*)data AtOffset:(uint32_t)offset WithMaxLength:(uint32_t)maxLength {
    NSData *strData = [data subdataWithRange:NSMakeRange(offset, maxLength)];
    int i;
    for (i = 0; i < strData.length; i++) {
        uint8_t ba[1];
        [strData getBytes:&ba range:NSMakeRange(i, 1)];
        if (ba[0] == 0x00) {  // Null Terminator
            break;  // out of for loop
        }
    }
    
    return [[NSString alloc] initWithData:[strData subdataWithRange:NSMakeRange(0, i)] encoding:NSASCIIStringEncoding];
}


@end
