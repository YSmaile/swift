//===----------------------------------------------------------------------===//
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
import SwiftShims

// TODO: API review
/// A type representing an error value that can be thrown.
///
/// Any type that declares conformance to `ErrorProtocol` can be used to
/// represent an error in Swift's error handling system. Because
/// `ErrorProtocol` has no requirements of its own, you can declare
/// conformance on any custom type you create.
///
/// Using Enumerations as Errors
/// ============================
///
/// Swift's enumerations are well suited to represent simple errors. Create an
/// enumeration that conforms to `ErrorProtocol` with a case for each possible
/// error. If there are additional details about the error that could be
/// helpful for recovery, use associated values to include that information.
///
/// The following example shows an `IntParsingError` enumeration that captures
/// two different kinds of errors that can occur when parsing an integer from
/// a string: overflow, where the value represented by the string is too large
/// for the integer data type, and invalid input, where nonnumeric characters
/// are found within the input.
///
///     enum IntParsingError: ErrorProtocol {
///         case overflow
///         case invalidInput(String)
///     }
///
/// The `invalidInput` case includes the invalid character as an associated
/// value.
///
/// The next code sample shows a possible extension to the `Int` type that
/// parses the integer value of a `String` instance, throwing an error when
/// there is a problem during parsing.
///
///     extension Int {
///         init(validating input: String) throws {
///             // ...
///             if !_isValid(s) {
///                 throw IntParsingError.invalidInput(s)
///             }
///             // ...
///         }
///     }
///
/// When calling the new `Int` initializer within a `do` statement, you can use
/// pattern matching to match specific cases of your custom error type and
/// access their associated values, as in the example below.
///
///     do {
///         let price = try Int(validating: "$100")
///     } catch IntParsingError.invalidInput(let invalid) {
///         print("Invalid character: '\(invalid)'")
///     } catch IntParsingError.overflow {
///         print("Overflow error")
///     } catch {
///         print("Other error")
///     }
///     // Prints "Invalid character: '$'"
///
/// Including More Data in Errors
/// =============================
///
/// Sometimes you may want different error states to include the same common
/// data, such as the position in a file or some of your application's state.
/// When you do, use a structure to represent errors. The following example
/// uses a structure to represent an error when parsing an XML document,
/// including the line and column numbers where the error occurred:
///
///     struct XMLParsingError: ErrorProtocol {
///         enum ErrorKind {
///             case invalidCharacter
///             case mismatchedTag
///             case internalError
///         }
///
///         let line: Int
///         let column: Int
///         let kind: ErrorKind
///     }
///
///     func parse(_ source: String) throws -> XMLDoc {
///         // ...
///         throw XMLParsingError(line: 19, column: 5, kind: .mismatchedTag)
///         // ...
///     }
///
/// Once again, use pattern matching to conditionally catch errors. Here's how
/// you can catch any `XMLParsingError` errors thrown by the `parse(_:)`
/// function:
///
///     do {
///         let xmlDoc = try parse(myXMLData)
///     } catch let e as XMLParsingError {
///         print("Parsing error: \(e.kind) [\(e.line):\(e.column)]")
///     } catch {
///         print("Other error: \(error)")
///     }
///     // Prints "Parsing error: mismatchedTag [19:5]"
public protocol ErrorProtocol {
  var _domain: String { get }
  var _code: Int { get }
#if _runtime(_ObjC)
  var _userInfo: AnyObject? { get }
#endif
}

#if _runtime(_ObjC)
/// Class that implements the informal protocol
/// NSErrorRecoveryAttempting, which is used by NSError when it
/// attempts recovery from an error.
class _NSErrorRecoveryAttempter {
  let error: RecoverableError

  init(error: RecoverableError) {
    self.error = error
  }

  @objc(attemptRecoveryFromError:optionIndex:delegate:didRecoverSelector:contextInfo:)
  func attemptRecovery(fromError nsError: AnyObject,
                       optionIndex recoveryOptionIndex: Int,
                       delegate: AnyObject?,
                       didRecoverSelector: UnsafeMutablePointer<Void>,
                       contextInfo: UnsafeMutablePointer<Void>?) {
    error.attemptRecovery(optionIndex: recoveryOptionIndex) { success in
      _swift_stdlib_perform_error_recovery_selector(
        delegate, didRecoverSelector, success, contextInfo)
    }
  }

  @objc(attemptRecoveryFromError:optionIndex:)
  func attemptRecovery(fromError nsError: AnyObject,
                       optionIndex recoveryOptionIndex: Int) -> _SwiftObjCBool {
    let success = error.attemptRecovery(optionIndex: recoveryOptionIndex)

    // Note: Matches the behavior of ObjCBool.
#if os(OSX) || (os(iOS) && (arch(i386) || arch(arm)))
    return success ? 1 : 0
#else
    return success
#endif
  }
}
#endif

extension ErrorProtocol {
  public var _domain: String {
    return String(reflecting: self.dynamicType)
  }

#if _runtime(_ObjC)
  public var _userInfo: AnyObject? {
#if false
    // If the OS supports value user info value providers, use those
    // to lazily populate the user-info dictionary for this domain.
    guard #available(OSX 10.11, iOS 9.0, tvOS 9.0, watchOS 2.0, *) else {
      // FIXME: Can only do this if Foundation is loaded... hmmm...
      return nil
    }
#endif

    // Populate the user-info dictionary 
    var result: [String : AnyObject]

    // Initialize with custom user-info.
    if let customNSError = self as? CustomNSError {
      result = customNSError.errorUserInfo
    } else {
      result = [:]
    }

    // Set a key in the user-info dictionary.
    func setObjectKey(_ key: _SwiftKnownNSErrorKey, to value: AnyObject) {
      let keyObject = _swift_stdlib_nserror_key(key)
      result[String(_cocoaString: keyObject)] = value
    }

    // Set a key in the user-info dictionary.
    func setStringKey(_ key: _SwiftKnownNSErrorKey, to value: String) {
      setObjectKey(key, to: _bridgeToObjectiveCUnconditional(value))
    }

    if let localizedError = self as? LocalizedError {
      if let description = localizedError.errorDescription {
        setStringKey(.localizedDescription, to: description)
      }
      
      if let reason = localizedError.failureReason {
        setStringKey(.localizedFailureReason, to: reason)
      }
      
      if let suggestion = localizedError.recoverySuggestion {   
        setStringKey(.localizedRecoverySuggestion, to: suggestion)
      }
      
      if let helpAnchor = localizedError.helpAnchor {   
        setStringKey(.helpAnchor, to: helpAnchor)
      }
    }
    
    if let recoverableError = self as? RecoverableError {
      setObjectKey(.localizedRecoveryOptions,
        to: _bridgeToObjectiveCUnconditional(recoverableError.recoveryOptions))
      setObjectKey(.recoveryAttempter,
        to: _NSErrorRecoveryAttempter(error: recoverableError))
    }

    return _bridgeToObjectiveCUnconditional(result)
  }
#endif
}

#if _runtime(_ObjC)
// Helper functions for the C++ runtime to have easy access to domain,
// code, and userInfo as Objective-C values.
@_silgen_name("swift_stdlib_getErrorDomainNSString")
public func _stdlib_getErrorDomainNSString<T : ErrorProtocol>(_ x: UnsafePointer<T>)
-> AnyObject {
  return x.pointee._domain._bridgeToObjectiveCImpl()
}

@_silgen_name("swift_stdlib_getErrorCode")
public func _stdlib_getErrorCode<T : ErrorProtocol>(_ x: UnsafePointer<T>) -> Int {
  return x.pointee._code
}

// Helper functions for the C++ runtime to have easy access to domain and
// code as Objective-C values.
@_silgen_name("swift_stdlib_getErrorUserInfoNSDictionary")
public func _stdlib_getErrorUserInfoNSDictionary<T : ErrorProtocol>(_ x: UnsafePointer<T>)
-> AnyObject? {
  return x.pointee._userInfo
}

// Known function for the compiler to use to coerce `ErrorProtocol` instances
// to `NSError`.
@_silgen_name("swift_bridgeErrorProtocolToNSError")
public func _bridgeErrorProtocolToNSError(_ error: ErrorProtocol) -> AnyObject
#endif

/// Invoked by the compiler when the subexpression of a `try!` expression
/// throws an error.
@_silgen_name("swift_unexpectedError")
public func _unexpectedError(_ error: ErrorProtocol) {
  preconditionFailure("'try!' expression unexpectedly raised an error: \(String(reflecting: error))")
}

/// Invoked by the compiler when code at top level throws an uncaught error.
@_silgen_name("swift_errorInMain")
public func _errorInMain(_ error: ErrorProtocol) {
  fatalError("Error raised at top level: \(String(reflecting: error))")
}

@available(*, unavailable, renamed: "ErrorProtocol")
public typealias ErrorType = ErrorProtocol

/// Describes an error that provides localized messages describing why
/// an error occurred and provides more information about the error.
public protocol LocalizedError : ErrorProtocol {
  /// A localized message describing what error occurred.
  var errorDescription: String? { get }

  /// A localized message describing the reason for the failure.
  var failureReason: String? { get }

  /// A localized message describing how one might recover from the failure.
  var recoverySuggestion: String? { get }

  /// A localized message providing "help" text if the user requests help.
  var helpAnchor: String? { get }
}

public extension LocalizedError {
  var errorDescription: String? { return nil }
  var failureReason: String? { return nil }
  var recoverySuggestion: String? { return nil }
  var helpAnchor: String? { return nil }
}

/// Describes an error that may be recoverably by presenting several
/// potential recovery options to the user.
public protocol RecoverableError : ErrorProtocol {
  /// Provides a set of possible recovery options to present to the user.
  var recoveryOptions: [String] { get }

  /// Attempt to recover from this error when the user selected the
  /// option at the given index. This routine must call resultHandler and
  /// indicate whether recovery was successful (or not).
  ///
  /// This entry point is used for recovery of errors handled at a
  /// "document" granularity, that do not affect the entire
  /// application.
  func attemptRecovery(optionIndex recoveryOptionIndex: Int,
                       andThen resultHandler: (recovered: Bool) -> Void)

  /// Attempt to recover from this error when the user selected the
  /// option at the given index. Returns true to indicate
  /// successful recovery, and false otherwise.
  ///
  /// This entry point is used for recovery of errors handled at
  /// the "application" granularity, where nothing else in the
  /// application can proceed until the attmpted error recovery
  /// completes.
  func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool
}

public extension RecoverableError {
  /// By default, implements document-modal recovery via application-model
  /// recovery.
  func attemptRecovery(optionIndex recoveryOptionIndex: Int,
                       andThen resultHandler: (recovered: Bool) -> Void) {
    resultHandler(recovered: attemptRecovery(optionIndex: recoveryOptionIndex))
  }
}

#if _runtime(_ObjC)
/// Describes an error type that specifically provides a domain, code,
/// and user-info dictionary.
public protocol CustomNSError : ErrorProtocol {
  /// The domain of the error.
  var errorDomain: String { get }

  /// The error code within the given domain.
  var errorCode: Int { get }

  /// The user-info dictionary.
  var errorUserInfo: [String : AnyObject] { get }
}

public extension ErrorProtocol where Self : CustomNSError {
  /// Default implementation for customized NSErrors.
  var _domain: String { return self.errorDomain }

  /// Default implementation for customized NSErrors.
  var _code: Int { return self.errorCode }

  /// Default implementation for customized NSErrors.
  var _userInfo: [String : AnyObject] { return self.errorUserInfo }
}
#endif
