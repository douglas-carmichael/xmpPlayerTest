//
//  xmpPlayer.m
//  xmpPlayerTest
//
//  Created by Douglas Carmichael on 1/18/15.
//  Copyright (c) 2015 Douglas Carmichael. All rights reserved.
//

#import "xmpPlayer.h"
#import "xmpPlayerErrors.h"

@implementation xmpPlayer

-(id)init
{
    self = [super init];
    if (self)
    {
        char **xmp_format_list;
        int status;
        xmp_format_list = xmp_get_format_list();
        class_context = xmp_create_context();
        _xmpVersion = [NSString stringWithUTF8String:xmp_version];
        NSMutableArray *tempSupportedFormats = [[NSMutableArray alloc] init];
        for (int i = 0; i <= sizeof(xmp_format_list); i++)
        {
            [tempSupportedFormats addObject:[NSString stringWithUTF8String:xmp_format_list[i]]];
        }
        _supportedFormats = [tempSupportedFormats copy];
        
        // Set up our audio
        status = NewAUGraph(&myGraph);
        if (status != noErr)
        {
            NSAssert(NO, @"Unable to set up audio processing graph.");
            return 0;
        }
        
        // Set up our default output component
        AudioComponentDescription defaultOutputDescription = {};
        defaultOutputDescription.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
        defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
        defaultOutputDescription.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
        defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        defaultOutputDescription.componentFlags = 0;
        defaultOutputDescription.componentFlagsMask = 0;
        
        // Add that component as an output node to the graph
        AUNode outputNode;
        status = AUGraphAddNode(myGraph, &defaultOutputDescription, &outputNode);
        
        // Set up our mixer component (for volume control)
        AudioComponentDescription mixerDescription = {};
        mixerDescription.componentType = kAudioUnitType_Mixer;
        mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
        mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        mixerDescription.componentFlags = 0;
        mixerDescription.componentFlagsMask = 0;
        
        // Add that component as a mixer node to the graph
        AUNode mixerNode;
        status = AUGraphAddNode(myGraph, &mixerDescription, &mixerNode);
        
        // Set up our converter component
        AudioComponentDescription converterDescription = {};
        converterDescription.componentType = kAudioUnitType_FormatConverter;
        converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
        converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        converterDescription.componentFlags = 0;
        converterDescription.componentFlagsMask = 0;
        
        AUNode converterNode;
        status = AUGraphAddNode(myGraph, &converterDescription, &converterNode);
        
        // Connect the converter to the mixer node
        status = AUGraphConnectNodeInput(myGraph, converterNode, 0, mixerNode, 0);
        
        // Connect the mixer to the output node
        status = AUGraphConnectNodeInput(myGraph, mixerNode, 0, outputNode, 0);
        
        
        // Open the graph (NOTE: Must be done before other setup tasks!)
        status = AUGraphOpen(myGraph);
        
        // Grab the converter and mixer as audio units
        AudioUnit converterUnit;
        status = AUGraphNodeInfo(myGraph, converterNode, NULL, &converterUnit);
        status = AUGraphNodeInfo(myGraph, mixerNode, NULL, &mixerUnit);
        
        // Set the mixer input bus count
        UInt32 numBuses = 1;
        status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input,
                                      0, &numBuses, sizeof(numBuses));
        
        // Enable audio I/O on the multichannel mixer
        status = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1, 0);
        status = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1, 0);
        status = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Enable, kAudioUnitScope_Global, 0, 1, 0);
        
        // Set our input format description (for the audio coming in from libxmp)
        streamFormat.mSampleRate = 44100;
        streamFormat.mFormatID = kAudioFormatLinearPCM;
        streamFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        streamFormat.mChannelsPerFrame = 2;
        streamFormat.mFramesPerPacket = 1;
        streamFormat.mBitsPerChannel = 16;
        streamFormat.mBytesPerFrame = 4;
        streamFormat.mBytesPerPacket = 4;
        
        status = AudioUnitSetProperty(converterUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &streamFormat,
                                      sizeof(streamFormat));
        
        // Calculate our buffer size based on sample rate/bytes per frame
        int ourBufferSize = streamFormat.mSampleRate * streamFormat.mBytesPerFrame;
        // Set up our circular buffer
        if(!TPCircularBufferInit(&ourClassPlayer.ourBuffer, ourBufferSize))
        {
            NSAssert(NO, @"Unable to set up audio buffer.");
            return 0;
        }
        
        // Get our output unit information
        AudioUnit outputUnit;
        status = AUGraphNodeInfo(myGraph, outputNode, 0, &outputUnit);
        
        // Add the render-notification callback to the graph
        AURenderCallbackStruct ourRenderCallback;
        ourRenderCallback.inputProc = &renderModuleCallback;
        ourRenderCallback.inputProcRefCon = &ourClassPlayer;
        status = AUGraphSetNodeInputCallback(myGraph, converterNode, 0, &ourRenderCallback);
        
        // Initialize and start the AUGraph
        status = AUGraphInitialize(myGraph);
        status = AUGraphStart(myGraph);
    }
    return self;
    
}

-(void)dealloc
{
    // Stop our AUGraph
    AUGraphStop(myGraph);
    
    // Terminate libxmp playback
    if (xmp_get_player(class_context, XMP_STATE_PLAYING) != 0)
    {
        xmp_end_player(class_context);
    }
    if (xmp_get_player(class_context, XMP_STATE_LOADED) != 0)
    {
        xmp_release_module(class_context);
    }
    xmp_free_context(class_context);
    
    // Clean up our buffer
    TPCircularBufferCleanup(&ourClassPlayer.ourBuffer);
    
    // Dispose of our AUGraph
    DisposeAUGraph(myGraph);
}

-(void)loadModule:(NSURL *)moduleURL error:(NSError *__autoreleasing *)error
{
    
    // Load the module
    if (xmp_load_module(class_context, (char *)[moduleURL.path UTF8String]) != 0)
    {
        if (error != NULL)
        {
            NSString *errorDescription = NSLocalizedString(@"Cannot load module.", @"");
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: errorDescription};
            NSString *xmpErrorDomain = @"net.dcarmichael.xmpPlayer";
            *error = [NSError errorWithDomain:xmpErrorDomain code:xmpLoadingError userInfo:errorInfo];
            return;
        }
        return;
    }
    
    // Scan for module information and make it available in our NSDictionary
    struct xmp_module_info pModuleInfo;
    xmp_get_module_info(class_context, &pModuleInfo);
    
    _moduleInfo = @{@"moduleName": [NSString stringWithUTF8String:pModuleInfo.mod->name],
                    @"moduleType": [NSString stringWithUTF8String:pModuleInfo.mod->type],
                    @"moduleNumPatterns": [NSNumber numberWithInt:pModuleInfo.mod->pat],
                    @"moduleNumTracks": [NSNumber numberWithInt:pModuleInfo.mod->trk],
                    @"moduleTracksPerPattern": [NSNumber numberWithInt:pModuleInfo.mod->chn],
                    @"moduleInstruments": [NSNumber numberWithInt:pModuleInfo.mod->ins],
                    @"moduleSamples": [NSNumber numberWithInt:pModuleInfo.mod->smp],
                    @"moduleInitSpeed": [NSNumber numberWithInt:pModuleInfo.mod->spd],
                    @"moduleInitBPM": [NSNumber numberWithInt:pModuleInfo.mod->bpm],
                    @"moduleLength": [NSNumber numberWithInt:pModuleInfo.mod->len],
                    @"moduleRestartPosition": [NSNumber numberWithInt:pModuleInfo.mod->rst],
                    @"moduleGlobalVolume": [NSNumber numberWithInt:pModuleInfo.mod->gvl],
                    @"moduleTotalTime": [NSNumber numberWithInt:pModuleInfo.seq_data[0].duration]};
    
    return;
    
}

-(void)nextPosition
{
    int status;
    status = xmp_next_position(class_context);
}

-(void)prevPosition
{
    int status;
    status = xmp_prev_position(class_context);
}

-(void)playModule:(NSError **)error
{
    
    int status;
    ourClassPlayer.stopped_flag = false;
    
    // Do we have a module loaded or playing?
    status = xmp_get_player(class_context, XMP_PLAYER_STATE);
    if (status == XMP_STATE_UNLOADED)
    {
        if (error != NULL)
        {
            NSString *errorDescription = NSLocalizedString(@"No module loaded.", @"");
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: errorDescription};
            NSString *xmpErrorDomain = @"net.dcarmichael.xmpPlayer";
            *error = [NSError errorWithDomain:xmpErrorDomain code:xmpFileError userInfo:errorInfo];
            return;
        }
    }
    
    // If we're playing, stop playback just to be sure.
    if (status == XMP_STATE_PLAYING)
    {
        xmp_stop_module(class_context);
    }
    
    // Start playback with the sample rate specified in the ASBD
    status = xmp_start_player(class_context, streamFormat.mSampleRate, 0);
    if (status != 0)
    {
        if (error != NULL)
        {
            NSString *errorDescription = NSLocalizedString(@"Cannot start playback.", @"");
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: errorDescription};
            NSString *xmpErrorDomain = @"net.dcarmichael.xmpPlayer";
            *error = [NSError errorWithDomain:xmpErrorDomain code:xmpSystemError userInfo:errorInfo];
            return;
        }
    }
    
    // If we've succeeded, set our error value to nil
    if (error != NULL)
    {
        *error = nil;
    }
    
    do
    {
        do
        {
            struct xmp_frame_info ourFrameInfo;
            
            xmp_get_frame_info(class_context, &ourFrameInfo);
            
            if (ourFrameInfo.loop_count > 0)
                break;
            // Check for stopping and break if selected.
            if (ourClassPlayer.stopped_flag)
                break;
            
            // Update our position information
            self->position = ourFrameInfo.pos;
            self->pattern = ourFrameInfo.pattern;
            self->row = ourFrameInfo.row;
            self->bpm = ourFrameInfo.bpm;
            self->time = ourFrameInfo.time;
            
            // Declare some variables for us to use within the buffer loop
            void *bufferDest;
            int bufferAvailable;
            
            // Let's start putting the data out into the buffer
            do {
                bufferDest = TPCircularBufferHead(&ourClassPlayer.ourBuffer, &bufferAvailable);
                if(bufferAvailable < ourFrameInfo.buffer_size)
                {
                    usleep(100000);
                }
                // Check for stopping and break if selected.
                if (ourClassPlayer.stopped_flag)
                    break;
            } while(bufferAvailable < ourFrameInfo.buffer_size);
            
            // Check for stopping (pause with an AUGraphStop() call.)
            if (ourClassPlayer.stopped_flag)
                break;
            memcpy(bufferDest, ourFrameInfo.buffer, ourFrameInfo.buffer_size);
            TPCircularBufferProduce(&ourClassPlayer.ourBuffer, ourFrameInfo.buffer_size);
        } while (xmp_play_frame(class_context) == 0);
    } while(!ourClassPlayer.reached_end);
}

-(void)pauseResume
{
    // Check if our AUGraph is running
    int err;
    Boolean isRunning;
    
    err = AUGraphIsRunning(myGraph, &isRunning);
    if (isRunning)
    {
        AUGraphStop(myGraph);
        ourClassPlayer.paused_flag = true;
    }
    else
    {
        AUGraphStart(myGraph);
        ourClassPlayer.paused_flag = false;
    }
}

-(void)stopPlayback
{
    ourClassPlayer.stopped_flag = true;
    xmp_stop_module(class_context);
}

-(void)setChannelVolume:(int)ourChannel volume:(int)ourVolume
{
    int status;
    status = xmp_channel_vol(class_context, ourChannel, ourVolume);
}

-(void)setMasterVolume:(float)volume
{
    AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume,
                          kAudioUnitScope_Output, 0, volume, 0);
}

-(NSString*)getTimeString:(int)timeValue
{
    int minutes, seconds;
    
    if (timeValue == 0)
    {
        minutes = 0;
        seconds = 0;
        NSString *timeReturn = @"00:00";
        return timeReturn;
    }
    else
    {
        minutes = ((timeValue + 500) / 60000);
        seconds = ((timeValue + 500) / 1000) % 60;
        NSString *timeReturn = [[NSString alloc] initWithFormat:@"%02d:%02d", minutes, seconds];
        return timeReturn;
    }
}

-(BOOL)isPlaying
{
    if(xmp_get_player(class_context, XMP_PLAYER_STATE) == XMP_STATE_PLAYING)
    {
        return YES;
    }
    return NO;
}

-(BOOL)isLoaded
{
    int status;
    status = xmp_get_player(class_context, XMP_PLAYER_STATE);
    switch (status)
    {
        case XMP_STATE_LOADED:
            return YES;
            break;
        case XMP_STATE_PLAYING:
            return YES;
            break;
        case XMP_STATE_UNLOADED:
            return NO;
            break;
            
        default:
            return NO;
            break;
    }
}

@end

OSStatus renderModuleCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inBufferFrames,
                              AudioBufferList *ioData)
{
    
    struct class_playback *our_playback = inRefCon;
    int bytesAvailable = 0;
    
    /* Grab the data from the circular buffer into the temporary buffer */
    SInt16 *tempBuffer = TPCircularBufferTail(&our_playback->ourBuffer, &bytesAvailable);
    
    if (bytesAvailable == 0)
    {
        // Fill the buffer with zeroes to prevent pops/noise
        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
        our_playback->reached_end = true;
    }
    
    int toCopy = MIN(bytesAvailable, ioData->mBuffers[0].mDataByteSize);
    
    /* memcpy() the data to the audio output */
    memcpy(ioData->mBuffers[0].mData, tempBuffer, toCopy);
    
    /* Clear that section of the buffer */
    TPCircularBufferConsume(&our_playback->ourBuffer, toCopy);
    
    return noErr;
}
