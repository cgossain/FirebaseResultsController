/*
<<<<<<< HEAD:Example/Pods/GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREndpoints.h
 * Copyright 2018 Google LLC
=======
 * Copyright 2020 Google LLC
>>>>>>> Update example project pods:Example/Pods/GoogleUtilities/GoogleUtilities/Environment/URLSessionPromiseWrapper/NSURLSession+GULPromises.h
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "GDTCORTargets.h"

@class FBLPromise<Value>;
@class GULURLSessionDataResponse;

<<<<<<< HEAD:Example/Pods/GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREndpoints.h
/* Class that manages the endpoints used by Google data transport library. */
@interface GDTCOREndpoints : NSObject

- (instancetype)init NS_UNAVAILABLE;

/** Returns the upload URL for a target specified. If the target is not available, returns nil.
 *
 *  @param target GoogleDataTransport target for which the upload URL is being looked up for.
 *  @return URL that will be used for uploading the events for the provided target.
 */
+ (nullable NSURL *)uploadURLForTarget:(GDTCORTarget)target;
=======
NS_ASSUME_NONNULL_BEGIN

/** Promise based API for `NSURLSession`. */
@interface NSURLSession (GULPromises)

/** Creates a promise wrapping `-[NSURLSession dataTaskWithRequest:completionHandler:]` method.
 * @param URLRequest The request to create a data task with.
 * @return A promise that is fulfilled when an HTTP response is received (with any response code),
 * or is rejected with the error passed to the task completion.
 */
- (FBLPromise<GULURLSessionDataResponse *> *)gul_dataTaskPromiseWithRequest:
    (NSURLRequest *)URLRequest;
>>>>>>> Update example project pods:Example/Pods/GoogleUtilities/GoogleUtilities/Environment/URLSessionPromiseWrapper/NSURLSession+GULPromises.h

@end

NS_ASSUME_NONNULL_END
