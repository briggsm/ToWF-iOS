//
//  DatagramChannel.m
//  ToWF Receiver
//
//  Created by Mark Briggs on 12/2/14.
//  Copyright (c) 2014 Mark Briggs. All rights reserved.
//
//  Get data from datagram data, stores it in circular buffer, which then TAAE can use via renderCallback.

#import "DatagramChannel.h"
#import "TPCircularBuffer.h"

@interface DatagramChannel ()
{
    TPCircularBuffer buffer;
    //BOOL isReloadingCircularBuffer;
}

@end

#define kBufferLength 705600  // 8 seconds at 44,100, 16-bit, mono. Should be plenty.

@implementation DatagramChannel

- (id)init
{
    self = [super init];
    if (self)
    {
        // Initialise buffer
        TPCircularBufferInit(&buffer, kBufferLength);
        
        //isReloadingCircularBuffer = NO;
    }
    return self;
}

- (void)dealloc {
    // Release buffer resources
    TPCircularBufferCleanup(&buffer);
}

-(void)flushBuffer {
    int32_t availableBytesToRead;
    TPCircularBufferTail(&buffer, &availableBytesToRead);
    TPCircularBufferConsume(&buffer, availableBytesToRead);
}

-(int32_t)getBufferDataSize {
    // Just how many bytes the buffer is filled with at the moment
    
    int32_t availableBytesToRead;
    TPCircularBufferTail(&buffer, &availableBytesToRead);
    
    return availableBytesToRead;
}

- (void)putInCircularBufferAudioData:(NSData*)audioData {
    uint32_t audioDataLength = (uint32_t)audioData.length;
    
    // Make our mono data into stereo, and put into circular buffer
    int8_t tempBuf[2];
    for (int i = 0; i < audioDataLength; i+=2) {
        [audioData getBytes:tempBuf range:NSMakeRange(i, 2)];
        TPCircularBufferProduceBytes(&buffer, tempBuf, 2);
        TPCircularBufferProduceBytes(&buffer, tempBuf, 2);  // This 2nd one goes into the 'other' (stereo) channel
    }
}

static OSStatus renderCallback(__unsafe_unretained DatagramChannel *THIS,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp *time,
                               UInt32 frames,
                               AudioBufferList *audio) {
    
    
    //NSLog(@"Start of renderCallback()");

    int bytesToCopy = audio->mBuffers[0].mDataByteSize;
    SInt16 *targetBuffer = (SInt16*)audio->mBuffers[0].mData;
    
    // Pull audio from playthrough buffer
    int32_t availableBytesToRead;
    SInt16 *buffer = TPCircularBufferTail(&THIS->buffer, &availableBytesToRead);
    
    //NSLog(@" bytesToCopy: %d", bytesToCopy);
    //NSLog(@" availableBytesToRead: %d", availableBytesToRead);
    
    //if (bytesToCopy > availableBytesToRead) {
    //    NSLog(@"Speaker HW wants more bytes than our Circular Buffer contains! HW Wants: %d", bytesToCopy);
    //}
    
    /*
    if (availableBytesToRead == 0) {
        NSLog(@"availableBytesToRead is 0!");
        &THIS->isReloadingCircularBuffer = YES;
    }
    */
    //THIS.flushBuffer;
    //((DatagramChannel*)THIS)->
    
    int32_t sampleCount = MIN(bytesToCopy, availableBytesToRead);
    
    
    
    memcpy(targetBuffer, buffer, sampleCount);
    TPCircularBufferConsume(&THIS->buffer, sampleCount);
    
    return noErr;
}
-(AEAudioControllerRenderCallback)renderCallback {
    return &renderCallback;
}

@end
