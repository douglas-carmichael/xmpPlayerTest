//
//  main.m
//  xmpPlayerTest
//
//  Created by Douglas Carmichael on 1/18/15.
//  Copyright (c) 2015 Douglas Carmichael. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "xmpPlayer.h"
 
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        NSError *error;
        
        xmpPlayer *myPlayer;
        Module *ourModule;
        
        myPlayer = [[xmpPlayer alloc] init];
        ourModule = [[Module alloc] init];
        
        // set up our paths and URLs
        NSString *modulePath = @"/Users/dcarmich/jakarta.mod";
        NSURL *moduleURL = [[NSURL alloc] initFileURLWithPath:modulePath];

        // load the module
        [ourModule setFilePath:moduleURL];
        [myPlayer loadModule:ourModule error:&error];
        if(error)
        {
            NSLog(@"Error: %@", error);
            return 0;
        }
        
        error = nil;
        
        NSLog(@"Module name: %@", ourModule.moduleName);
        NSLog(@"Module type: %@", ourModule.moduleType);
        
        // play it
        [myPlayer playModule:&error];
        
    }
    return 0;
}
