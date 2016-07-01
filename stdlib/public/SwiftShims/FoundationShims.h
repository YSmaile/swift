//===--- FoundationShims.h - Foundation declarations for core stdlib ------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
//  In order to prevent a circular module dependency between the core
//  standard library and the Foundation overlay, we import these
//  declarations as part of SwiftShims.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_STDLIB_SHIMS_FOUNDATIONSHIMS_H
#define SWIFT_STDLIB_SHIMS_FOUNDATIONSHIMS_H

//===--- Layout-compatible clones of Foundation structs -------------------===//
// Ideally we would declare the same names as Foundation does, but
// Swift's module importer is not yet tolerant of the same struct
// coming in from two different Clang modules
// (rdar://problem/16294674).  Instead, we copy the definitions here
// and then do horrible unsafeBitCast trix to make them usable where required.
//===----------------------------------------------------------------------===//

#include "SwiftStdint.h"

#ifdef __cplusplus
namespace swift { extern "C" {
#endif

typedef struct {
  __swift_intptr_t location;
  __swift_intptr_t length;
} _SwiftNSRange;

#ifdef __OBJC2__
typedef struct {
    unsigned long state;
    id __unsafe_unretained _Nullable * _Nullable itemsPtr;
    unsigned long * _Nullable mutationsPtr;
    unsigned long extra[5];
} _SwiftNSFastEnumerationState;
#endif

// This struct is layout-compatible with NSOperatingSystemVersion.
typedef struct {
  __swift_intptr_t majorVersion;
  __swift_intptr_t minorVersion;
  __swift_intptr_t patchVersion;
} _SwiftNSOperatingSystemVersion;

SWIFT_RUNTIME_STDLIB_INTERFACE
_SwiftNSOperatingSystemVersion _swift_stdlib_operatingSystemVersion();

#ifndef SWIFT_ENUM
#  define SWIFT_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

typedef SWIFT_ENUM(__swift_int8_t, _SwiftKnownNSErrorKey) {
  _SwiftKnownNSErrorKeyLocalizedDescription = 0,
  _SwiftKnownNSErrorKeyLocalizedFailureReason,
  _SwiftKnownNSErrorKeyLocalizedRecoverySuggestion,
  _SwiftKnownNSErrorKeyHelpAnchor,
  _SwiftKnownNSErrorKeyLocalizedRecoveryOptions,
  _SwiftKnownNSErrorKeyRecoveryAttempter
};

SWIFT_RUNTIME_STDLIB_INTERFACE
id _Nonnull _swift_stdlib_nserror_key(_SwiftKnownNSErrorKey key);


// FIXME: Need a configure-time check to tell us whether to use
// "signed char" or "bool".
typedef signed char _SwiftObjCBool; 

#ifdef __cplusplus
typedef bool _SwiftCBool;
#else
typedef _Bool _SwiftCBool;
#endif

SWIFT_RUNTIME_STDLIB_INTERFACE
void _swift_stdlib_perform_error_recovery_selector(
       _Nullable id delegate,
       void *_Nonnull selector,
       _SwiftCBool success,
       void * _Nullable contextInfo);

#ifdef __cplusplus
}} // extern "C", namespace swift
#endif

#endif // SWIFT_STDLIB_SHIMS_FOUNDATIONSHIMS_H

