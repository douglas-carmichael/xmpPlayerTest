//
//  xmpPlayerErrors.h
//  xmpPlayerTest
//
//  Created by Douglas Carmichael on 1/18/15.
//  Copyright (c) 2015 Douglas Carmichael. All rights reserved.
//

#ifndef xmpPlayerTest_xmpPlayerErrors_h
#define xmpPlayerTest_xmpPlayerErrors_h

extern NSString *xmpErrorDomain;

enum
{
    xmpInternalError,
    xmpPlaybackError,
    xmpInvalidError,
    xmpFormatError,
    xmpFileError,
    xmpLoadingError,
    xmpDepackError,
    xmpSystemError,
    xmpStateError
};

#endif
