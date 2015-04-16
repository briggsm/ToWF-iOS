//
//  Util.h
//  ToWF Receiver
//
//  Created by Mark Briggs on 4/2/15.
//  Copyright (c) 2015 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TICK NSDate *startTime = [NSDate date]
#define TOCK NSLog(@"%s Time: %fus", __func__, [startTime timeIntervalSinceNow] * -1000000.0)

@interface Util : NSObject

+(uint32_t) getUInt32FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian;
+(uint16_t) getUInt16FromData:(NSData*)data AtOffset:(uint32_t)offset BigEndian:(Boolean)bigEndian;
+(uint8_t) getUInt8FromData:(NSData*)data AtOffset:(uint32_t)offset;
+(void) appendInt:(int)i OfLength:(uint8_t)length ToData:(NSMutableData*)data BigEndian:(Boolean)bigEndian;
+(void) appendNullTermString:(NSString*)str ToData:(NSMutableData*)data MaxLength:(int)maxLength PadWith0s:(BOOL)pad;
+(NSString*) getNullTermStringFromData:(NSData*)data AtOffset:(uint32_t)offset WithMaxLength:(uint32_t)maxLength;

@end
