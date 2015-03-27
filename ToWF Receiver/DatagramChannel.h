//
//  MyChannelClass.h
//  ToWiFi Client2
//
//  Created by Mark Briggs on 12/2/14.
//  Copyright (c) 2014 Mark Briggs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"

@interface DatagramChannel : NSObject <AEAudioPlayable>

- (void)flushBuffer;
- (int32_t)getBufferDataSize;
- (void)putInCircularBufferAudioData:(NSData*)audioData;


@end
