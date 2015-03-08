//
//  Module.h
//  modClassTest
//
//  Created by Douglas Carmichael on 3/1/15.
//  Copyright (c) 2015 Douglas Carmichael. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Module : NSObject


@property (readwrite) NSURL* filePath;
@property (readwrite) NSString* moduleName;
@property (readwrite) NSString* moduleType;
@property (readwrite) int numPatterns;
@property (readwrite) int numTracks;
@property (readwrite) int numChannels;
@property (readwrite) int numInstruments;
@property (readwrite) int numSamples;
@property (readwrite) int initSpeed;
@property (readwrite) int initBPM;
@property (readwrite) int modLength;
@property (readwrite) int modRestartPos;
@property (readwrite) int modGlobalVolume;
@property (readwrite) int modTotalTime;

@end
