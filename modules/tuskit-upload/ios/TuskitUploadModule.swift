import ExpoModulesCore
import TUSKit

let ON_FILE_QUEUEING_FAILED_EVENT_NAME = "onFileQueueingFailed"
let ON_FILE_QUEUEING_COMPLETED = "onFileQueueingCompleted"
let ON_PROGRESS_UPDATE_EVENT_NAME = "onProgressUpdate"
let ON_UPLOAD_COMPLETE_EVENT_NAME = "onUploadComplete"
let ON_UPLOAD_FAILED_EVENT_NAME = "onUploadFailed"

let serverURL = "https://video.bunnycdn.com/tusupload"
let sessionIdentifier = "com.balltime.tuskitupload"

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
      if tusClient != nil {
          return
      }

      let url = URL(string: serverURL)
      let sessionConfig = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)

      guard url != nil else {
          print("Failed to create URL from serverURL: \(serverURL)")
          return
      }

      do {
          tusClient = try TUSClient(
              server: url!,
              sessionIdentifier: sessionIdentifier,
              sessionConfiguration: sessionConfig,
              storageDirectory: URL(string: "/BTTUS")!,
              chunkSize: 0
          )

          guard tusClient != nil else {
              return
          }

          tusClient!.delegate = self
      } catch {
          // Silently handle any initialization errors
      }
  }

  private func getUploadIdByVideoId(_ videoId: String) throws -> String? {
      guard let client = tusClient else {
          throw ClientNotInitializedError()
      }
      
      let uploads = try client.getStoredUploads()
      
      // Find the upload that has the matching videoId in its context
      guard let matchingUpload = uploads.first(where: { upload in
          guard let context = upload.context,
                let contextFileId = context["fileId"] else {
              return false
          }
          return contextFileId == videoId
      }) else {
          return nil
      }
      
      return matchingUpload.id.uuidString
  }

  // Each module class must implement the definition function. The definition consists of components
  // that describes the module's functionality and behavior.
  // See https://docs.expo.dev/modules/module-api for more details about available components.
  public func definition() -> ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
    // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
    // The module will be accessible from `requireNativeModule('TuskitUpload')` in JavaScript.
    Name("TuskitUpload")

    Events(
      ON_PROGRESS_UPDATE_EVENT_NAME, ON_UPLOAD_COMPLETE_EVENT_NAME, ON_UPLOAD_FAILED_EVENT_NAME,
      ON_FILE_QUEUEING_COMPLETED, ON_FILE_QUEUEING_FAILED_EVENT_NAME)

    Function("upload") { (fileUri: URL, fileId: String, metadata: [String: String], options: [String: Any]) -> [String: Any] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
      
        let uploadURL = (options["uploadURL"] as? String).flatMap { URL(string: $0) }
        let customHeaders = options["customHeaders"] as? [String: String] ?? [:]
        
        var metadata = metadata
        metadata["fileId"] = fileId
        
        let id = try client.uploadFileAt(
            filePath: fileUri,
            uploadURL: uploadURL,
            customHeaders: customHeaders,
            context: metadata
        )

        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "TUSClient started upload, id is \(id)"
        ])
        return ["id": id.uuidString]
    }

    Function("cancelUpload") { (fileId: String) in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        guard let uploadId = try self.getUploadIdByVideoId(fileId) else {
            return
        }
        
        guard let uuid = UUID(uuidString: uploadId) else {
            throw InvalidUUIDError()
        }
        
        try client.cancel(id: uuid)
    }

    Function("getUploadTasks") { () -> [[String: Any]] in
        guard let client = tusClient else {
            throw ClientNotInitializedError()
        }
        
        let uploads = try client.getStoredUploads()
        return uploads.map { upload in
            var taskInfo: [String: Any] = [
                "status": "Running",
            ]

            if let context = upload.context {
                taskInfo["id"] = context["fileId"]
            }

            if let range = upload.uploadedRange {
                taskInfo["progress"] = Double(range.upperBound) / Double(upload.size)
            }          
            
            return taskInfo
        }
    }

    Function("reattachEventHandlers") { () -> Void in
    }

    Function("getFreeStorageSpace") { () -> Int64 in
      do {
        let documentDirectoryURL = try FileManager.default.url(
          for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let values = try documentDirectoryURL.resourceValues(forKeys: [
          .volumeAvailableCapacityForImportantUsageKey
        ])
        if let freeSpace = values.volumeAvailableCapacityForImportantUsage {
          return freeSpace
        } else {
          print("Failed to retrieve free space.")
          return -1
        }
      } catch {
        print("Error: \(error)")
        return -1
      }
    }
  }
}

extension TuskitUploadModule: TUSClientDelegate {
    public func didStartUpload(id: UUID, context: [String: String]?, client: TUSClient) {
        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "TUSClient started upload, id is \(id)"
        ])
        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "TUSClient remaining is \(client.remainingUploads)"
        ])
    }
    
    public func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient) {
        NSLog("TUSClient finished upload, id is \(id) url is \(url)")
        NSLog("TUSClient remaining is \(client.remainingUploads)")
        if client.remainingUploads == 0 {
            NSLog("Finished uploading")
        }
    }
    
    public func uploadFailed(id: UUID, error: Error, context: [String: String]?, client: TUSClient) {
        NSLog("TUSClient upload failed for \(id) error \(error)")
    }
    
    public func fileError(error: TUSClientError, client: TUSClient) {
        NSLog("TUSClient File error \(error)")
    }
    
    public func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
    }
    
    public func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "TUSClient started upload, id is \(id), context is \(String(describing: context))"
        ])
        self.sendEvent(ON_PROGRESS_UPDATE_EVENT_NAME, [
          "message": "TUSClient progress for \(id): \(bytesUploaded)/\(totalBytes) bytes uploaded"
        ])
    }
}