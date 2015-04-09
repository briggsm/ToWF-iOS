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
    //TPCircularBuffer buffer;
    TPCircularBuffer buffer1;
    TPCircularBuffer buffer2;
}

@end

//#define kBufferLength 705600  // 8 seconds at 44,100, 16-bit, mono. Should be plenty.
#define kBuffer1Length 352800
#define kBuffer2Length 352800

@implementation DatagramChannel

- (id)init
{
    self = [super init];
    if (self)
    {
        // Initialise buffer
        //TPCircularBufferInit(&buffer, kBufferLength);
        TPCircularBufferInit(&buffer1, kBuffer1Length);
        TPCircularBufferInit(&buffer2, kBuffer2Length);
        
        //isReloadingCircularBuffer = NO;
    }
    return self;
}

- (void)dealloc {
    // Release buffer resources
    //TPCircularBufferCleanup(&buffer);
    TPCircularBufferCleanup(&buffer1);
    TPCircularBufferCleanup(&buffer2);
}

-(void)flushBuffer {
    int32_t availableBytesToRead;
    //TPCircularBufferTail(&buffer, &availableBytesToRead);
    //TPCircularBufferConsume(&buffer, availableBytesToRead);
    TPCircularBufferTail(&buffer1, &availableBytesToRead);
    TPCircularBufferConsume(&buffer1, availableBytesToRead);
    TPCircularBufferTail(&buffer2, &availableBytesToRead);
    TPCircularBufferConsume(&buffer2, availableBytesToRead);
}

-(int32_t)getBufferDataSize {
    // Just how many bytes the buffer is filled with at the moment
    
    //int32_t availableBytesToRead;
    int32_t availableBytesToRead1;
    int32_t availableBytesToRead2;
    //TPCircularBufferTail(&buffer, &availableBytesToRead);
    TPCircularBufferTail(&buffer1, &availableBytesToRead1);
    TPCircularBufferTail(&buffer2, &availableBytesToRead2);
    
    //return availableBytesToRead;
    return availableBytesToRead1 + availableBytesToRead2;
}

- (void)putInCircularBufferAudioData:(NSData*)audioData {
    //uint32_t audioDataLength = (uint32_t)audioData.length;
    
    // Make our mono data into stereo, and put into circular buffer
    /*
    int8_t tempBuf[2];
    for (int i = 0; i < audioDataLength; i+=2) {
        [audioData getBytes:tempBuf range:NSMakeRange(i, 2)];
        TPCircularBufferProduceBytes(&buffer, tempBuf, 2);
        TPCircularBufferProduceBytes(&buffer, tempBuf, 2);  // This 2nd one goes into the 'other' (stereo) channel
    }
    */
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
    //SInt16 *targetBuffer = (SInt16*)audio->mBuffers[0].mData;
    SInt16 *targetBuffer1 = (SInt16*)audio->mBuffers[0].mData;
    SInt16 *targetBuffer2 = (SInt16*)audio->mBuffers[1].mData;
    
    // Pull audio from playthrough buffer
    int32_t availableBytesToRead1;
    int32_t availableBytesToRead2;
    
    //SInt16 *buffer = TPCircularBufferTail(&THIS->buffer, &availableBytesToRead);
    SInt16 *buffer1 = TPCircularBufferTail(&THIS->buffer1, &availableBytesToRead1);
    SInt16 *buffer2 = TPCircularBufferTail(&THIS->buffer2, &availableBytesToRead2);
    
    int32_t sampleCount = MIN(bytesToCopy, availableBytesToRead1);
    
    //memcpy(targetBuffer, buffer, sampleCount);
    memcpy(targetBuffer1, buffer1, sampleCount);
    memcpy(targetBuffer2, buffer2, sampleCount);
    //TPCircularBufferConsume(&THIS->buffer, sampleCount);
    TPCircularBufferConsume(&THIS->buffer1, sampleCount);
    TPCircularBufferConsume(&THIS->buffer2, sampleCount);
    
    return noErr;
}

/*
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
    
    
//    if (availableBytesToRead == 0) {
//        NSLog(@"availableBytesToRead is 0!");
//        &THIS->isReloadingCircularBuffer = YES;
//    }
    
    //THIS.flushBuffer;
    //((DatagramChannel*)THIS)->
    
    int32_t sampleCount = MIN(bytesToCopy, availableBytesToRead);
    
    
    
    memcpy(targetBuffer, buffer, sampleCount);
    TPCircularBufferConsume(&THIS->buffer, sampleCount);
    
    return noErr;
}
*/

-(AEAudioControllerRenderCallback)renderCallback {
    return &renderCallback;
}

@end
