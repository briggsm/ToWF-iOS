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
    TPCircularBuffer buffer1;  // Left
    TPCircularBuffer buffer2;  // Right
}

@end

// 44,100Hz, 16-bit mono = 88,200 bytes(of storage)/second.
#define kBuffer1Length 352800   // 4 seconds Left (44,100, 16-bit)
#define kBuffer2Length 352800   // 4 seconds Right (44,100, 16-bit)

@implementation DatagramChannel

- (id)init
{
    self = [super init];
    if (self)
    {
        // Initialise buffer
        TPCircularBufferInit(&buffer1, kBuffer1Length);
        TPCircularBufferInit(&buffer2, kBuffer2Length);
    }
    return self;
}

- (void)dealloc {
    // Release buffer resources
    TPCircularBufferCleanup(&buffer1);
    TPCircularBufferCleanup(&buffer2);
}

-(void)flushBuffer {
    int32_t availableBytesToRead;
    TPCircularBufferTail(&buffer1, &availableBytesToRead);
    TPCircularBufferConsume(&buffer1, availableBytesToRead);
    TPCircularBufferTail(&buffer2, &availableBytesToRead);
    TPCircularBufferConsume(&buffer2, availableBytesToRead);
}

-(int32_t)getBufferDataSize {
    // Just how many bytes the buffer is filled with at the moment
    
    int32_t availableBytesToRead1;
    int32_t availableBytesToRead2;
    TPCircularBufferTail(&buffer1, &availableBytesToRead1);
    TPCircularBufferTail(&buffer2, &availableBytesToRead2);
    
    return availableBytesToRead1 + availableBytesToRead2;
}

- (void)putInCircularBufferAudioData:(NSData*)audioData {
    //uint32_t audioDataLength = (uint32_t)audioData.length;
    
    // Make our mono data into stereo, and put into circular buffers
    int8_t tempBuf[audioData.length];
    [audioData getBytes:tempBuf range:NSMakeRange(0, audioData.length)];
    TPCircularBufferProduceBytes(&buffer1, tempBuf, (uint32_t)audioData.length);
    TPCircularBufferProduceBytes(&buffer2, tempBuf, (uint32_t)audioData.length);
}

static OSStatus renderCallback(__unsafe_unretained DatagramChannel *THIS,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp *time,
                               UInt32 frames,
                               AudioBufferList *audio) {
    
    int bytesToCopy = audio->mBuffers[0].mDataByteSize;
    SInt16 *targetBuffer1 = (SInt16*)audio->mBuffers[0].mData;
    SInt16 *targetBuffer2 = (SInt16*)audio->mBuffers[1].mData;
    
    // Pull audio from playthrough buffer
    int32_t availableBytesToRead1;
    int32_t availableBytesToRead2;
    
    SInt16 *buffer1 = TPCircularBufferTail(&THIS->buffer1, &availableBytesToRead1);
    SInt16 *buffer2 = TPCircularBufferTail(&THIS->buffer2, &availableBytesToRead2);
    
    int32_t sampleCount = MIN(bytesToCopy, availableBytesToRead1);
    
    memcpy(targetBuffer1, buffer1, sampleCount);
    memcpy(targetBuffer2, buffer2, sampleCount);

    TPCircularBufferConsume(&THIS->buffer1, sampleCount);
    TPCircularBufferConsume(&THIS->buffer2, sampleCount);
    
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return &renderCallback;
}

@end
