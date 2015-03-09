//
//  xmpPlayer.h
//  xmpPlayerTest
//
//  Created by Douglas Carmichael on 1/18/15.
//  Copyright (c) 2015 Douglas Carmichael. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"
#import "xmp.h"
#import "Module.h"

@interface xmpPlayer : NSObject
{
    struct class_playback
    {
        TPCircularBuffer ourBuffer;
        int reached_end;
        int stopped_flag;
        int paused_flag;
    };
    
    // Set up our libxmp player context
    xmp_context class_context;
    
    // Set up our AUGraph to process the audio
    AUGraph myGraph;
    
    // Set up our mixer audio unit
    AudioUnit mixerUnit;
    
    // Set up our playback structure
    struct class_playback ourClassPlayer;
    
    // Set up our ASBD for the audio input from libxmp (referenced in playModule)
    AudioStreamBasicDescription streamFormat;
    
    BOOL ourPlayback;
}

@property (readonly) NSString *xmpVersion;
@property (readonly) NSArray *supportedFormats;
@property (readonly) NSArray *instrumentNames;
@property (readonly) int playerPosition;
@property (readonly) int playerPattern;
@property (readonly) int playerRow;
@property (readonly) int playerBPM;
@property (readonly) int playerTime;
@property (readonly) BOOL isPaused;

-(void)loadModule:(Module *)ourModule error:(NSError *__autoreleasing *)error;
-(void)playModule:(NSError **)error;
-(void)pauseResume;
-(void)stopPlayer;
-(void)nextPlayPosition;
-(void)prevPlayPosition;

-(void)jumpPosition:(NSInteger)positionValue;
-(void)seekPlayerToTime:(NSInteger)seekValue;
-(void)setMasterVolume:(float)volume;
-(void)setChannelVolume:(NSInteger)ourChannel volume:(NSInteger)ourVolume;
-(NSString*)getTimeString:(int)timeValue;
-(BOOL)isLoaded;
-(BOOL)isPlaying;

OSStatus renderModuleCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inBufferFrames,
                              AudioBufferList *ioData);

@end
