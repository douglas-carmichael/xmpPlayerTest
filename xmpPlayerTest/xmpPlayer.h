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
    
@public
    // Set up some integers for position/pattern/row/bpm
    int position, pattern, row, bpm, time, total_time;

}

@property (readonly) NSString *xmpVersion;
@property (readonly) NSArray *supportedFormats;
@property (readonly) NSArray *instrumentNames;
@property (readonly) NSDictionary *moduleInfo;

-(void)loadModule:(NSURL *)moduleURL error:(NSError *__autoreleasing *)error;
-(void)playModule:(NSError **)error;
-(void)pauseResume;
-(void)stopPlayback;
-(void)setMasterVolume:(float)volume;
-(void)setChannelVolume:(int)ourChannel volume:(int)ourVolume;
-(NSString*)getTimeString:(int)timeValue;
-(BOOL)isPlaying;
-(BOOL)isLoaded;

OSStatus renderModuleCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inBufferFrames,
                              AudioBufferList *ioData);

@end
