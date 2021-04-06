/*
 * Copyright 2019 Google
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

<<<<<<< HEAD:Example/Pods/FirebaseInstallations/FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDTokenStore.h
@class FBLPromise<ValueType>;

NS_ASSUME_NONNULL_BEGIN

/**
 * The class reads a default IID token from IID store if available.
 */
@interface FIRInstallationsIIDTokenStore : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithGCMSenderID:(NSString *)GCMSenderID;

- (FBLPromise<NSString *> *)existingIIDDefaultToken;
=======
@class FIRDiagnosticsData;
@class FIROptions;

NS_ASSUME_NONNULL_BEGIN

/** Connects FIRCore with the CoreDiagnostics library. */
@interface FIRCoreDiagnosticsConnector : NSObject

/** Logs FirebaseCore  related data.
 *
 * @param options The options object containing data to log.
 */
+ (void)logCoreTelemetryWithOptions:(FIROptions *)options;
>>>>>>> Update example project pods:Example/Pods/FirebaseDatabase/FirebaseCore/Sources/Private/FIRCoreDiagnosticsConnector.h

@end

NS_ASSUME_NONNULL_END
