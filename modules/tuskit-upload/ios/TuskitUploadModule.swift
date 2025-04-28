import ExpoModulesCore
import TUSKit

// Custom errors
struct InvalidServerURLError: Error {}
struct ClientNotInitializedError: Error {}
struct InvalidFilePathError: Error {}
struct InvalidDataError: Error {}
struct InvalidUUIDError: Error {} 

public class TuskitUploadModule: Module {
  private var tusClient: TUSClient?
    
  public required init(appContext: AppContext) {
      super.init(appContext: appContext)
  }

  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.
  public func definition() -> ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
    // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
    // The module will be accessible from `requireNativeModule('TuskitUpload')` in JavaScript.
    Name("TuskitUpload")

    Function("initialize") { (serverURL: String, sessionIdentifier: String) in
        guard let url = URL(string: serverURL) else {
            throw InvalidServerURLError()
        }
        
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        tusClient = try TUSClient(
            server: url,
            sessionIdentifier: sessionIdentifier,
            sessionConfiguration: sessionConfig
        )
        
        try tusClient?.start()
    }
    
    AsyncFunction("uploadFile") { (options: [String: Any]) -> [String: Any] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let filePath = options["filePath"] as? String,
              let fileURL = URL(string: filePath) else {
            throw InvalidFilePathError()
        }
        
        let uploadURL = (options["uploadURL"] as? String).flatMap { URL(string: $0) }
        let customHeaders = options["customHeaders"] as? [String: String] ?? [:]
        let context = options["context"] as? [String: String]
        
        let id = try client.uploadFileAt(
            filePath: fileURL,
            uploadURL: uploadURL,
            customHeaders: customHeaders,
            context: context
        )
        
        return ["id": id.uuidString]
    }
    
    AsyncFunction("uploadData") { (data: String, options: [String: Any]) -> [String: Any] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let data = data.data(using: .utf8) else {
            throw InvalidDataError()
        }
        
        let uploadURL = (options["uploadURL"] as? String).flatMap { URL(string: $0) }
        let customHeaders = options["customHeaders"] as? [String: String] ?? [:]
        let context = options["context"] as? [String: String]
        
        let id = try client.upload(
            data: data,
            uploadURL: uploadURL,
            customHeaders: customHeaders,
            context: context
        )
        
        return ["id": id.uuidString]
    }
    
    AsyncFunction("cancelUpload") { (id: String) in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let uuid = UUID(uuidString: id) else {
            throw InvalidUUIDError()
        }
        
        try client.cancel(id: uuid)
    }
    
    AsyncFunction("retryUpload") { (id: String) -> Bool in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let uuid = UUID(uuidString: id) else {
            throw InvalidUUIDError()
        }
        
        return try client.retry(id: uuid)
    }
    
    AsyncFunction("resumeUpload") { (id: String) -> Bool in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let uuid = UUID(uuidString: id) else {
            throw InvalidUUIDError()
        }
        
        return try client.resume(id: uuid)
    }
    
    AsyncFunction("getStoredUploads") { () -> [[String: Any]] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        let uploads = try client.getStoredUploads()
        return uploads.map { upload in
            var dict: [String: Any] = [
                "id": upload.id.uuidString,
                "uploadURL": upload.uploadURL.absoluteString,
                "filePath": upload.filePath.absoluteString,
                "remoteDestination": upload.remoteDestination?.absoluteString ?? "",
                "size": upload.size
            ]
            
            if let context = upload.context {
                dict["context"] = context
            }
            
            if let range = upload.uploadedRange {
                dict["uploadedRange"] = [
                    "start": range.lowerBound,
                    "end": range.upperBound
                ]
            }
            
            if let mimeType = upload.mimeType {
                dict["mimeType"] = mimeType
            }
            
            if let headers = upload.customHeaders {
                dict["customHeaders"] = headers
            }
            
            return dict
        }
    }
    
    Events("uploadProgress")
  }
}
