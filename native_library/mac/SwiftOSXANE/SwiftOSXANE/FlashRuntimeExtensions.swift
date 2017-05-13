/*@copyright The code is licensed under the[MIT
 License](http://opensource.org/licenses/MIT):
 
 Copyright © 2017 -  Tua Rua Ltd.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files(the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions :
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.*/

import Foundation

public class FRESwiftHelper {
    static func getAsString(_ rawValue: FREObject) throws -> String {
        var ret: String = ""
        var len: UInt32 = 0
        var valuePtr: UnsafePointer<UInt8>?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectAsUTF8(object: rawValue, length: &len, value: &valuePtr)
        #else
            let status: FREResult = FREGetObjectAsUTF8(rawValue, &len, &valuePtr)
        #endif
        if FRE_OK == status {
            ret = (NSString(bytes: valuePtr!, length: Int(len), encoding: String.Encoding.utf8.rawValue) as String?)!
        } else {
            throw FREError(stackTrace: "", message: "cannot get FREObject as String", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func getAsBool(_ rawValue: FREObject) throws -> Bool {
        var ret: Bool = false
        var val: UInt32 = 0
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectAsBool(object: rawValue, value: &val)
        #else
            let status: FREResult = FREGetObjectAsBool(rawValue, &val)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot get FREObject as Bool", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        ret = val == 1 ? true : false
        return ret
    }
    
    
    static func getAsDouble(_ rawValue: FREObject) throws -> Double {
        var ret: Double = 0.0
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectAsDouble(object: rawValue, value: &ret)
        #else
            let status: FREResult = FREGetObjectAsDouble(rawValue, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot get FREObject as Double", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func getAsInt(_ rawValue: FREObject) throws -> Int {
        var ret: Int32 = 0
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectAsInt32(object: rawValue, value: &ret)
        #else
            let status: FREResult = FREGetObjectAsInt32(rawValue, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot get FREObject as Int", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return Int(ret)
    }
    
    static func getAsUInt(_ rawValue: FREObject) throws -> UInt {
        var ret: UInt32 = 0
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectAsUint32(object: rawValue, value: &ret)
        #else
            let status: FREResult = FREGetObjectAsUint32(rawValue, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot get FREObject as UInt", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return UInt(ret)
    }
    
    
    static func getAsId(_ rawValue: FREObject) throws -> Any? {
        let objectType: FREObjectTypeSwift = getType(rawValue)
        
        //Swift.debugPrint("getAsId is of type ", objectType)
        switch objectType {
        case .int:
            return try getAsInt(rawValue)
        case .vector, .array:
            return FREArraySwift.init(freObject: rawValue).value
        case .string:
            return try getAsString(rawValue)
        case .boolean:
            return try getAsBool(rawValue)
        case .object, .cls:
            return try getAsDictionary(rawValue)
        case .number:
            return try getAsDouble(rawValue)
        case .bitmapdata: //TODO
            break
        //return try self.getAsImage()
        case .bytearray:
            let asByteArray = FREByteArraySwift.init(freByteArray: rawValue)
            let byteData = asByteArray.value
            asByteArray.releaseBytes() //don't forget to release
            return byteData
        case .null:
            return nil
        }
        return nil
    }
    
    public static func toPointerArray(args: Any...) throws -> NSPointerArray {
        let argsArray: NSPointerArray = NSPointerArray(options: .opaqueMemory)
        for i in 0..<args.count {
            let arg: FREObjectSwift = try FREObjectSwift.init(any: args[i])
            argsArray.addPointer(arg.rawValue)
        }
        return argsArray
    }
    
    public static func arrayToFREArray(_ array: NSPointerArray?) -> UnsafeMutablePointer<FREObject?>? {
        if let array = array {
            let ret = UnsafeMutablePointer<FREObject?>.allocate(capacity: array.count)
            for i in 0..<array.count {
                ret[i] = array.pointer(at: i)
            }
            return ret
        }
        return nil
    }
    
    public static func getType(_ rawValue: FREObject) -> FREObjectTypeSwift {
        var objectType: FREObjectType = FRE_TYPE_NULL
        #if os(iOS)
            _ = FRESwiftBridge.bridge.FREGetObjectType(object: rawValue, objectType: &objectType)
        #else
            FREGetObjectType(rawValue, &objectType)
        #endif
        let type: FREObjectTypeSwift = FREObjectTypeSwift(rawValue: objectType.rawValue)!
        
        
        return FREObjectTypeSwift.number == type || FREObjectTypeSwift.object == type
            ? getActionscriptType(rawValue)
            : type
    }
    
    fileprivate static func getActionscriptType(_ rawValue: FREObject) -> FREObjectTypeSwift {
        //Swift.debugPrint("GET ACTIONSCRIPT TYPE----------------")
        if let aneUtils: FREObjectSwift = try? FREObjectSwift.init(className: "com.tuarua.ANEUtils", args: nil) {
            let param: FREObjectSwift = FREObjectSwift.init(freObject: rawValue)
            if let classType: FREObjectSwift = try! aneUtils.callMethod(methodName: "getClassType", args: param) {
                let type: String? = try! FRESwiftHelper.getAsString(classType.rawValue!).lowercased()
                
                if type == "int" {
                    return FREObjectTypeSwift.int
                } else if type == "string" {
                    return FREObjectTypeSwift.string
                } else if type == "number" {
                    return FREObjectTypeSwift.number
                } else if type == "boolean" {
                    return FREObjectTypeSwift.boolean
                } else {
                    return FREObjectTypeSwift.cls
                }
                
            }
        }
        return FREObjectTypeSwift.null
    }
    
    static func getAsDictionary(_ rawValue: FREObject) throws -> Dictionary<String, AnyObject> {
        //Swift.debugPrint("GET AS DICTIONARY **************************")
        
        var ret: Dictionary = Dictionary<String, AnyObject>()
        guard let aneUtils: FREObjectSwift = try? FREObjectSwift.init(className: "com.tuarua.ANEUtils", args: nil) else {
            return ret
        }
        
        let param: FREObjectSwift = FREObjectSwift.init(freObject: rawValue)
        guard let classProps1: FREObjectSwift = try aneUtils.callMethod(methodName: "getClassProps", args: param),
            let rValue = classProps1.rawValue
            else {
                return Dictionary<String, AnyObject>()
        }
        
        let array: FREArraySwift = FREArraySwift.init(freObject: rValue)
        let arrayLength = array.length
        for i in 0..<arrayLength {
            if let elem: FREObjectSwift = try array.getObjectAt(index: i) {
                if let propNameAs = try elem.getProperty(name: "name") {
                    let propName: String = propNameAs.value as! String
                    if let propval = try param.getProperty(name: propNameAs.value as! String) {
                        if let propvalId = propval.value {
                            ret.updateValue(propvalId as AnyObject, forKey: propName)
                        }
                    }
                }
                
                
            }
        }
        
        return ret
    }
    
    static func getProperty(rawValue: FREObject, name: String) throws -> FREObject? {
        var ret: FREObject?
        var thrownException: FREObject?
        
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetObjectProperty(object: rawValue,
                                                                               propertyName: name,
                                                                               propertyValue: &ret,
                                                                               thrownException: &thrownException)
        #else
            let status: FREResult = FREGetObjectProperty(rawValue, name, &ret, &thrownException)
        #endif
        
        guard FRE_OK == status else {
            throw FREError(stackTrace: getActionscriptException(thrownException),
                           message: "cannot get property \"\(name)\"", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    
    static func setProperty(rawValue: FREObject, name: String, prop: FREObject?) throws {
        var thrownException: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRESetObjectProperty(object: rawValue,
                                                                               propertyName: name,
                                                                               propertyValue: prop,
                                                                               thrownException: &thrownException)
        #else
            let status: FREResult = FRESetObjectProperty(rawValue, name, prop, &thrownException)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: getActionscriptException(thrownException),
                           message: "cannot set property \"\(name)\"", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
    }
    
    static func getActionscriptException(_ thrownException: FREObject?) -> String {
        
        guard let thrownException = thrownException else {
            return ""
        }
        
        let thrownExceptionSwift: FREObjectSwift = FREObjectSwift.init(freObject: thrownException)
        
        guard FREObjectTypeSwift.cls == thrownExceptionSwift.getType() else {
            return ""
        }
        
        do {
            guard let rv = try thrownExceptionSwift.callMethod(methodName: "hasOwnProperty", args: "getStackTrace")?.rawValue,
                let hasStackTrace = try? getAsBool(rv),
                hasStackTrace,
                let asStackTrace = try thrownExceptionSwift.callMethod(methodName: "getStackTrace"),
                FREObjectTypeSwift.string == asStackTrace.getType(),
                let ret: String = asStackTrace.value as? String
                else {
                    return ""
            }
            return ret
        } catch {
        }
        
        return ""
    }
    
    static func newObject(_ string: String) throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObjectFromUTF8(length: UInt32(string.utf8.count),
                                                                               value: string, object: &ret)
        #else
            let status: FREResult = FRENewObjectFromUTF8(UInt32(string.utf8.count), string, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot create new  object ", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    
    static func newObject(_ double: Double) throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObjectFromDouble(value: double, object: &ret)
        #else
            let status: FREResult = FRENewObjectFromDouble(double, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot create new  object ", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func newObject(_ int: Int) throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObjectFromInt32(value: Int32(int), object: &ret)
        #else
            let status: FREResult = FRENewObjectFromInt32(Int32(int), &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot create new  object ", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func newObject(_ uint: UInt) throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObjectFromUint32(value: UInt32(uint), object: &ret)
        #else
            let status: FREResult = FRENewObjectFromUint32(UInt32(uint), &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot create new  object ", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func newObject(_ bool: Bool) throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObjectFromBool(value: bool, object: &ret)
        #else
            let b: UInt32 = (bool == true) ? 1 : 0
            let status: FREResult = FRENewObjectFromBool(b, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot create new  object ", type: getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    static func newObject(_ className: String, _ args: NSPointerArray?) throws -> FREObject? {
        var ret: FREObject?
        var thrownException: FREObject?
        var numArgs: UInt32 = 0
        if args != nil {
            numArgs = UInt32((args?.count)!)
        }
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRENewObject(className: className, argc: numArgs, argv: args,
                                                                       object: &ret, thrownException: &thrownException)
        #else
            let status: FREResult = FRENewObject(className, numArgs, arrayToFREArray(args), &ret, &thrownException)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: getActionscriptException(thrownException),
                           message: "cannot create new  object \(className)", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    
    static func getErrorCode(_ result: FREResult) -> FREError.Code {
        switch result {
        case FRE_NO_SUCH_NAME:
            return .noSuchName
        case FRE_INVALID_OBJECT:
            return .invalidObject
        case FRE_TYPE_MISMATCH:
            return .typeMismatch
        case FRE_ACTIONSCRIPT_ERROR:
            return .actionscriptError
        case FRE_INVALID_ARGUMENT:
            return .invalidArgument
        case FRE_READ_ONLY:
            return .readOnly
        case FRE_WRONG_THREAD:
            return .wrongThread
        case FRE_ILLEGAL_STATE:
            return .illegalState
        case FRE_INSUFFICIENT_MEMORY:
            return .insufficientMemory
        default:
            return .ok
        }
    }
    
}


open class FREContextSwift: NSObject {
    public var rawValue: FREContext? = nil
    
    public init(freContext: FREContext) {
        rawValue = freContext
    }
    
    public func dispatchStatusEventAsync(code: String, level: String) throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREDispatchStatusEventAsync(ctx: rawValue!, code: code, level: level)
        #else
            let status: FREResult = FREDispatchStatusEventAsync(rawValue, code, level)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot dispatch event \(code):\(level)",
                type: FRESwiftHelper.getErrorCode(status), line: #line, column: #column, file: #file)
        }
    }
    
    public func getActionScriptData() throws -> FREObject? {
        var ret: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetContextActionScriptData(ctx: rawValue!, actionScriptData: &ret)
        #else
            let status: FREResult = FREGetContextActionScriptData(rawValue, &ret)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot get actionscript data", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        return ret
    }
    
    
    public func setActionScriptData(object: FREObject) throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRESetContextActionScriptData(ctx: rawValue!, actionScriptData: object)
        #else
            let status: FREResult = FRESetContextActionScriptData(rawValue, object)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot set actionscript data", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        
    }
    
}

public struct FREError: Error {
    
    public enum Code {
        case ok
        case noSuchName
        case invalidObject
        case typeMismatch
        case actionscriptError
        case invalidArgument
        case readOnly
        case wrongThread
        case illegalState
        case insufficientMemory
    }
    
    public func getError(_ oFile: String, _ oLine: Int, _ oColumn: Int) -> FREObject? {
        do {
            let freArgs: NSPointerArray = try FRESwiftHelper.toPointerArray(args: message, 0, String(describing: type), "[\(oFile):\(oLine):\(oColumn)]", stackTrace)
            let _aneError = try FREObjectSwift.init(className: "com.tuarua.ANEError",
                                                    args: freArgs)
            return _aneError.rawValue
            
        } catch {
        }
        
        return nil
    }
    
    public let stackTrace: String
    public let message: String
    public let type: Code
    public let line: Int
    public let column: Int
    public let file: String
}

public enum FREObjectTypeSwift: UInt32 {
    case object = 0
    case number = 1
    case string = 2
    case bytearray = 3
    case array = 4
    case vector = 5
    case bitmapdata = 6
    case boolean = 7
    case null = 8
    case int = 9
    case cls = 10 //aka class
}

open class FREObjectSwift: NSObject {
    public var rawValue: FREObject? = nil
    public var value: Any? { //could be nil?
        get {
            do {
                if let raw = rawValue {
                    let idRes = try FRESwiftHelper.getAsId(raw)
                    return idRes
                }
            } catch {
            }
            return nil
        }
    }
    
    public init(freObject: FREObject) {
        rawValue = freObject
    }
    
    public init(string: String) throws {
        rawValue = try FRESwiftHelper.newObject(string)
    }
    
    public init(double: Double) throws {
        rawValue = try FRESwiftHelper.newObject(double)
    }
    
    public init(int: Int) throws {
        rawValue = try FRESwiftHelper.newObject(int)
    }
    
    public init(uint: UInt) throws {
        rawValue = try FRESwiftHelper.newObject(uint)
    }
    
    public init(bool: Bool) throws {
        rawValue = try FRESwiftHelper.newObject(bool)
    }
    
    public init(any: Any) throws {
        super.init()
        rawValue = try _newObject(any: any)
    }
    
    public init(className: String, args: NSPointerArray?) throws {
        rawValue = try FRESwiftHelper.newObject(className, args)
    }
    
    public func callMethod(methodName: String, args: Any...) throws -> FREObjectSwift? {
        let argsArray: NSPointerArray = NSPointerArray(options: .opaqueMemory)
        for i in 0..<args.count {
            let arg: FREObject? = try FREObjectSwift.init(any: args[i]).rawValue
            argsArray.addPointer(arg)
        }
        
        var ret: FREObject?
        var thrownException: FREObject?
        var numArgs: UInt32 = 0
        numArgs = UInt32((argsArray.count))
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRECallObjectMethod(object: rawValue!, methodName: methodName,
                                                                              argc: numArgs, argv: argsArray,
                                                                              result: &ret, thrownException: &thrownException)
            
        #else
            let status: FREResult = FRECallObjectMethod(rawValue, methodName, numArgs, FRESwiftHelper.arrayToFREArray(argsArray), &ret, &thrownException)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: FRESwiftHelper.getActionscriptException(thrownException),
                           message: "cannot call method \"\(methodName)\"", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        
        if let ret = ret {
            return FREObjectSwift(freObject: ret)
        }
        return nil
    }
    
    
    public func getProperty(name: String) throws -> FREObjectSwift? {
        if let raw = rawValue {
            if let ret = try FRESwiftHelper.getProperty(rawValue: raw, name: name) {
                return FREObjectSwift(freObject: ret)
            }
        }
        return nil
    }
    
    public func setProperty(name: String, prop: FREObjectSwift?) throws {
        if let raw = rawValue {
            try FRESwiftHelper.setProperty(rawValue: raw, name: name, prop: prop?.rawValue)
        }
    }
    
    public func getType() -> FREObjectTypeSwift {
        if let raw = rawValue {
            return FRESwiftHelper.getType(raw)
        }
        return FREObjectTypeSwift.null
    }
    
    fileprivate func _newObject(any: Any) throws -> FREObject? {
        if any is FREObject {
            return (any as! FREObject)
        } else if any is FREObjectSwift {
            return (any as! FREObjectSwift).rawValue
        } else if any is String {
            return try FRESwiftHelper.newObject(any as! String)
        } else if any is Int {
            return try FRESwiftHelper.newObject(any as! Int)
        } else if any is Int32 {
            return try FRESwiftHelper.newObject(any as! Int)
        } else if any is UInt {
            return try FRESwiftHelper.newObject(any as! UInt)
        } else if any is UInt32 {
            return try FRESwiftHelper.newObject(any as! UInt)
        } else if any is Double {
            return try FRESwiftHelper.newObject(any as! Double)
        } else if any is Bool {
            return try FRESwiftHelper.newObject(any as! Bool)
        } //TODO add Dict and others
        
        Swift.debugPrint("_newObject NO MATCH")
        
        return nil
        
    }
    
}


public class FREArraySwift: NSObject {
    public var rawValue: FREObject? = nil
    
    public init(freObject: FREObject) {
        rawValue = freObject
    }
    
    public func getObjectAt(index: UInt) throws -> FREObjectSwift? {
        var object: FREObject?
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREGetArrayElementA(arrayOrVector: rawValue!, index: UInt32(index),
                                                                              value: &object)
        #else
            let status: FREResult = FREGetArrayElementAt(rawValue, UInt32(index), &object)
        #endif
        guard FRE_OK == status else {
            
            throw FREError(stackTrace: "", message: "cannot get object at \(index) ", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        if let object = object {
            return FREObjectSwift.init(freObject: object)
        }
        
        return nil
    }
    
    public func setObjectAt(index: UInt, object: FREObjectSwift) throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FRESetArrayElementA(arrayOrVector: rawValue!, index: UInt32(index),
                                                                              value: object.rawValue)
        #else
            let status: FREResult = FRESetArrayElementAt(rawValue, UInt32(index), object.rawValue)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot set object at \(index) ", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
    }
    
    public var length: UInt {
        get {
            do {
                var ret: UInt32 = 0
                #if os(iOS)
                    let status: FREResult = FRESwiftBridge.bridge.FREGetArrayLength(arrayOrVector: rawValue!, length: &ret)
                #else
                    let status: FREResult = FREGetArrayLength(rawValue, &ret)
                #endif
                guard FRE_OK == status else {
                    throw FREError(stackTrace: "", message: "cannot get length of array", type: FRESwiftHelper.getErrorCode(status),
                                   line: #line, column: #column, file: #file)
                }
                return UInt(ret)
                
            } catch {
            }
            return 0
        }
    }
    
    
    public var value: Array<Any?> {
        get {
            var ret: [Any?] = []
            do {
                for i in 0..<length {
                    if let elem: FREObjectSwift = try getObjectAt(index: i) {
                        ret.append(elem.value)
                    }
                }
            } catch {
            }
            return ret
        }
    }
    
}

public class FREByteArraySwift: NSObject {
    public var rawValue: FREObject? = nil
    public var bytes: UnsafeMutablePointer<UInt8>!
    public var length: UInt = 0
    private var _byteArray: FREByteArray = FREByteArray.init()
    
    public init(freByteArray: FREObject) {
        rawValue = freByteArray
    }
    
    public func acquire() throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREAcquireByteArray(object: rawValue!, byteArrayToSet: &_byteArray)
        #else
            let status: FREResult = FREAcquireByteArray(rawValue, &_byteArray)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot acquire ByteArray", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        length = UInt(_byteArray.length)
        bytes = _byteArray.bytes
    }
    
    public func releaseBytes() { //can't override release
        #if os(iOS)
            _ = FRESwiftBridge.bridge.FREReleaseByteArray(object: rawValue!)
        #else
            FREReleaseByteArray(rawValue)
        #endif
    }
    
    func getAsData() throws -> NSData {
        try self.acquire()
        return NSData.init(bytes: bytes, length: Int(length))
    }
    
    public var value: NSData? {
        get {
            do {
                try self.acquire()
                guard let b = bytes else {
                    return nil
                }
                return NSData.init(bytes: b, length: Int(length))
            } catch {
            }
            
            defer {
                releaseBytes()
            }
            return nil
        }
    }
    
}

public class FREBitmapDataSwift: NSObject {
    private typealias FREBitmapData = FREBitmapData2
    
    public var rawValue: FREObject? = nil
    private var _bitmapData: FREBitmapData = FREBitmapData.init()
    public var width: Int = 0
    public var height: Int = 0
    public var hasAlpha: Bool = false
    public var isPremultiplied: Bool = false
    public var isInvertedY: Bool = false
    public var lineStride32: UInt = 0
    public var bits32: UnsafeMutablePointer<UInt32>!
    
    public init(freObject: FREObject) {
        rawValue = freObject
    }
    
    public func acquire() throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREAcquireBitmapData2(object: rawValue!, descriptorToSet: &_bitmapData)
        #else
            let status: FREResult = FREAcquireBitmapData2(rawValue, &_bitmapData)
        #endif
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot acquire BitmapData", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
        width = Int(_bitmapData.width)
        height = Int(_bitmapData.height)
        hasAlpha = _bitmapData.hasAlpha == 1
        isPremultiplied = _bitmapData.isPremultiplied == 1
        isInvertedY = _bitmapData.isInvertedY == 1
        lineStride32 = UInt(_bitmapData.lineStride32)
        bits32 = _bitmapData.bits32
    }
    
    public func releaseData() {
        #if os(iOS)
            _ = FRESwiftBridge.bridge.FREReleaseBitmapData(object: rawValue!)
        #else
            FREReleaseBitmapData(rawValue)
        #endif
    }
    
    public func getAsImage() throws -> CGImage? {
        try self.acquire()
        
        let releaseProvider: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?,
            data: UnsafeRawPointer, size: Int) -> () in
            // https://developer.apple.com/reference/coregraphics/cgdataproviderreleasedatacallback
            // N.B. 'CGDataProviderRelease' is unavailable: Core Foundation objects are automatically memory managed
            return
        }
        let provider: CGDataProvider = CGDataProvider(dataInfo: nil, data: bits32, size: (width * height * 4),
                                                      releaseData: releaseProvider)!
        
        
        let bitsPerComponent = 8;
        let bitsPerPixel = 32;
        let bytesPerRow: Int = 4 * width;
        let colorSpaceRef: CGColorSpace = CGColorSpaceCreateDeviceRGB();
        var bitmapInfo: CGBitmapInfo
        
        if hasAlpha {
            if isPremultiplied {
                bitmapInfo = CGBitmapInfo.init(rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                    CGImageAlphaInfo.premultipliedFirst.rawValue)
                
            } else {
                bitmapInfo = CGBitmapInfo.init(rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                    CGImageAlphaInfo.first.rawValue)
            }
        } else {
            bitmapInfo = CGBitmapInfo.init(rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                CGImageAlphaInfo.noneSkipFirst.rawValue)
        }
        
        let renderingIntent: CGColorRenderingIntent = CGColorRenderingIntent.defaultIntent;
        let imageRef: CGImage = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent,
                                        bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpaceRef,
                                        bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false,
                                        intent: renderingIntent)!;
        
        return imageRef
        
    }
    
    
    public func invalidateRect(x: UInt, y: UInt, width: UInt, height: UInt) throws {
        #if os(iOS)
            let status: FREResult = FRESwiftBridge.bridge.FREInvalidateBitmapDataRect(object: rawValue!, x: UInt32(x),
                                                                                      y: UInt32(y), width: UInt32(width), height: UInt32(height))
        #else
            let status: FREResult = FREInvalidateBitmapDataRect(rawValue, UInt32(x), UInt32(y), UInt32(width), UInt32(height))
        #endif
        
        guard FRE_OK == status else {
            throw FREError(stackTrace: "", message: "cannot invalidateRect", type: FRESwiftHelper.getErrorCode(status),
                           line: #line, column: #column, file: #file)
        }
    }
    
}


public var context: FREContextSwift!

public func trace(_ value: Any...) {
    var traceStr: String = ""
    for i in 0..<value.count {
        traceStr = traceStr + "\(value[i])" + " "
    }
    do {
        try context.dispatchStatusEventAsync(code: traceStr, level: "TRACE")
    } catch {
    }
}

public typealias FREArgv = UnsafeMutablePointer<FREObject?>!
public typealias FREArgc = UInt32
public typealias FREFunctionMap = [String: (_: FREContext, _: FREArgc, _: FREArgv) -> FREObject?]
public var functionsToSet: FREFunctionMap = [:]
public typealias FRESwiftController = NSObject

public extension FRESwiftController {
    func callSwiftFunction(name: String, ctx: FREContext, argc: FREArgc, argv: FREArgv) -> FREObject? {
        if let fm = functionsToSet[name] {
            return fm(ctx, argc, argv)
        }
        return nil
    }
}